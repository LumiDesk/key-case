import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../crypto/kdf.dart';
import '../logging/app_logger.dart';
import '../models/models.dart';
import 'vault_container.dart';

/// 保险库文件读写与会话持有者。
///
/// 职责边界：
/// - 只认一个文件（[fileName]），写入走「临时文件 + 原子 rename」；
/// - Argon2id 与 AES-GCM 的计算放到后台 isolate，主线程只等结果；
/// - UI 永远不直接碰这个类，只通过 Controller。
class VaultRepository {
  VaultRepository({Directory? directory, KdfParams? kdfParams})
    : _directoryOverride = directory,
      _kdfParams = kdfParams ?? const KdfParams();

  static const String fileName = 'vault.kcv';
  static const String preImportFileName = 'vault.kcv.pre-import';

  static const VaultFormatException _lockedError = VaultFormatException(
    '保险库未解锁',
    code: VaultErrorCode.locked,
  );

  final Directory? _directoryOverride;

  /// 运行时使用默认 Argon2id 参数；测试可注入低成本参数避免拖慢用例。
  final KdfParams _kdfParams;
  Directory? _cachedDirectory;
  UnlockedVault? _session;

  /// 会话代数：锁定/换库后递增。在途写操作发现代数变化就丢弃结果，
  /// 绝不在锁定后复活 session，也不把旧密钥写进新库。
  int _epoch = 0;

  /// 串行化所有写操作，避免两次保存交错。
  Future<void> _writeTail = Future<void>.value();

  UnlockedVault? get session => _session;

  VaultData? get currentData => _session?.data;

  bool get isUnlocked => _session != null;

  Future<Directory> _directory() async {
    if (_directoryOverride != null) return _directoryOverride;
    return _cachedDirectory ??= await getApplicationSupportDirectory();
  }

  Future<File> _vaultFile() async =>
      File(p.join((await _directory()).path, fileName));

  Future<bool> exists() async => (await _vaultFile()).exists();

  /// 创建保险库。口令派生在 isolate 里跑，避免首帧卡顿。
  Future<UnlockedVault> create({
    required String password,
    required VaultData data,
  }) async {
    final kdfParams = _kdfParams;
    final created = await Isolate.run(
      () => VaultContainer.create(
        password: password,
        data: data,
        kdfParams: kdfParams,
      ),
    );
    await _writeAtomic(created.bytes);
    _epoch++;
    _session?.close();
    _session = created.session;
    return created.session;
  }

  Future<UnlockedVault> unlock(String password) async {
    final epoch = _epoch;
    final bytes = await (await _vaultFile()).readAsBytes();
    final unlocked = await Isolate.run(
      () => VaultContainer.unlock(password: password, bytes: bytes),
    );
    if (epoch != _epoch) {
      unlocked.close();
      throw _lockedError;
    }
    await _persistMigratedIfNeeded(unlocked, epoch);
    if (epoch != _epoch) {
      unlocked.close();
      throw _lockedError;
    }
    _session?.close();
    _session = unlocked;
    return unlocked;
  }

  /// 生物识别路径：vault key 由 Android Keystore 解出后直接解密正文。
  Future<UnlockedVault> unlockWithVaultKey(Uint8List vaultKey) async {
    final epoch = _epoch;
    final bytes = await (await _vaultFile()).readAsBytes();
    final unlocked = await Isolate.run(
      () => VaultContainer.unlockWithVaultKey(bytes: bytes, vaultKey: vaultKey),
    );
    if (epoch != _epoch) {
      unlocked.close();
      throw _lockedError;
    }
    await _persistMigratedIfNeeded(unlocked, epoch);
    if (epoch != _epoch) {
      unlocked.close();
      throw _lockedError;
    }
    _session?.close();
    _session = unlocked;
    return unlocked;
  }

  /// bridge 构建：v1 解锁后立即原子写回 v2；失败则不返回会话，旧文件保持原样。
  Future<void> _persistMigratedIfNeeded(
    UnlockedVault unlocked,
    int epoch,
  ) async {
    if (unlocked.migration == null) return;
    try {
      await _serialize(() async {
        if (epoch != _epoch) throw _lockedError;
        final bytes = await VaultContainer.seal(unlocked);
        if (epoch != _epoch) throw _lockedError;
        await _writeAtomic(bytes);
        if (epoch != _epoch) throw _lockedError;
      });
    } catch (_) {
      unlocked.close();
      rethrow;
    }
  }

  /// 写入新的库内容并换新 nonce；返回落盘后的字节（供备份复用）。
  ///
  /// 这里不开 isolate：正文只有几十 KB，AES-GCM 几毫秒就完成；反而
  /// `Isolate.run` 的闭包会一起捕获所在写队列闭包的上下文（含 Future），
  /// 发送时报 unsendable。慢的只有 Argon2id，见 create/unlock。
  Future<Uint8List> save(VaultData data) {
    final epoch = _epoch;
    return _serialize(() async {
      if (epoch != _epoch) throw _lockedError;
      final current = _session;
      if (current == null) throw _lockedError;
      final next = current.withData(data);
      final sealing = UnlockedVault(
        header: current.header,
        vaultKey: Uint8List.fromList(current.vaultKey),
        data: data,
      );
      final bytes = await sealSession(sealing);
      if (epoch != _epoch) throw _lockedError;
      await _writeAtomic(bytes);
      if (epoch != _epoch) throw _lockedError;
      _session = next;
      return bytes;
    });
  }

  /// 加密一个会话。测试可覆写以观察锁定与写盘之间的竞态。
  Future<Uint8List> sealSession(UnlockedVault session) {
    return VaultContainer.seal(session);
  }

  /// 改主密码：旧口令立即失效，vault key 不变。
  Future<Uint8List> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final epoch = _epoch;
    final current = _session;
    if (current == null) throw _lockedError;
    // 两次派生都放在顶层 helper 里，避免闭包连带捕获 Repository 的写队列。
    final onDisk = await (await _vaultFile()).readAsBytes();
    final verified = await _unlockBytesInBackground(onDisk, currentPassword);
    verified.close();

    final rotated = await _rotatePasswordInBackground(
      current,
      newPassword,
      _kdfParams,
    );
    if (epoch != _epoch) {
      rotated.session.close();
      throw _lockedError;
    }
    await _serialize(() async {
      if (epoch != _epoch) throw _lockedError;
      await _writeAtomic(rotated.bytes);
      if (epoch != _epoch) throw _lockedError;
      current.close();
      _session = rotated.session;
    });
    return rotated.bytes;
  }

  /// 用外部备份替换当前库，并保留一份替换前的密文副本。
  Future<UnlockedVault> replaceWithBackup({
    required Uint8List bytes,
    required String password,
  }) async {
    final epoch = _epoch;
    final unlocked = await _unlockBytesInBackground(bytes, password);
    if (epoch != _epoch) {
      unlocked.close();
      throw _lockedError;
    }
    final Uint8List target;
    try {
      target = unlocked.migration == null
          ? bytes
          : await VaultContainer.seal(unlocked);
    } catch (_) {
      unlocked.close();
      rethrow;
    }
    final file = await _vaultFile();
    if (await file.exists()) {
      await file.copy(p.join((await _directory()).path, preImportFileName));
    }
    await _serialize(() async {
      if (epoch != _epoch) throw _lockedError;
      await _writeAtomic(target);
      if (epoch != _epoch) throw _lockedError;
      _session?.close();
      _session = unlocked;
    });
    return unlocked;
  }

  Future<Uint8List> readBytes() async => (await _vaultFile()).readAsBytes();

  /// 只读容器头（不做口令派生），生物识别解锁用它拿 vaultId 定位包裹密钥。
  Future<VaultHeader?> inspect() async {
    final file = await _vaultFile();
    if (!await file.exists()) return null;
    try {
      return VaultContainer.inspect(await file.readAsBytes());
    } on VaultFormatException catch (error) {
      AppLogger.warn('inspect vault failed: ${error.message}');
      return null;
    }
  }

  void lock() {
    _epoch++;
    _session?.close();
    _session = null;
  }

  /// 删除库文件与安全副本（危险操作，由 UI 二次确认后调用）。
  Future<void> deleteAll() async {
    _epoch++;
    _session?.close();
    _session = null;
    await _serialize(() async {
      final directory = await _directory();
      final vault = File(p.join(directory.path, fileName));
      if (await vault.exists()) await vault.delete();
      final preImport = File(p.join(directory.path, preImportFileName));
      if (await preImport.exists()) await preImport.delete();
    });
  }

  Future<void> _writeAtomic(Uint8List bytes) async {
    final file = await _vaultFile();
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(file.path);
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _writeTail.then((_) => action());
    _writeTail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}

/// 顶层函数让 isolate 闭包只捕获参数，不把 Repository 的写队列一起带走。
Future<UnlockedVault> _unlockBytesInBackground(
  Uint8List bytes,
  String password,
) {
  return Isolate.run(
    () => VaultContainer.unlock(password: password, bytes: bytes),
  );
}

Future<CreatedVault> _rotatePasswordInBackground(
  UnlockedVault session,
  String newPassword,
  KdfParams kdfParams,
) {
  return Isolate.run(
    () => VaultContainer.changePassword(
      session: session,
      newPassword: newPassword,
      kdfParams: kdfParams,
    ),
  );
}
