import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  VaultRepository({Directory? directory}) : _directoryOverride = directory;

  static const String fileName = 'vault.kcv';
  static const String preImportFileName = 'vault.kcv.pre-import';

  final Directory? _directoryOverride;
  Directory? _cachedDirectory;
  UnlockedVault? _session;

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
    final created = await Isolate.run(
      () => VaultContainer.create(password: password, data: data),
    );
    await _writeAtomic(created.bytes);
    _session?.close();
    _session = created.session;
    return created.session;
  }

  Future<UnlockedVault> unlock(String password) async {
    final bytes = await (await _vaultFile()).readAsBytes();
    final unlocked = await Isolate.run(
      () => VaultContainer.unlock(password: password, bytes: bytes),
    );
    _session?.close();
    _session = unlocked;
    return unlocked;
  }

  /// 生物识别路径：vault key 由 Android Keystore 解出后直接解密正文。
  Future<UnlockedVault> unlockWithVaultKey(Uint8List vaultKey) async {
    final bytes = await (await _vaultFile()).readAsBytes();
    final unlocked = await Isolate.run(
      () => VaultContainer.unlockWithVaultKey(bytes: bytes, vaultKey: vaultKey),
    );
    _session?.close();
    _session = unlocked;
    return unlocked;
  }

  /// 写入新的库内容并换新 nonce；返回落盘后的字节（供备份复用）。
  ///
  /// 这里不开 isolate：正文只有几十 KB，AES-GCM 几毫秒就完成；反而
  /// `Isolate.run` 的闭包会一起捕获所在写队列闭包的上下文（含 Future），
  /// 发送时报 unsendable。慢的只有 Argon2id，见 create/unlock。
  Future<Uint8List> save(VaultData data) {
    return _serialize(() async {
      final current = _session;
      if (current == null) {
        throw const VaultFormatException('保险库未解锁', code: VaultErrorCode.locked);
      }
      final next = current.withData(data);
      final bytes = await VaultContainer.seal(next);
      await _writeAtomic(bytes);
      _session = next;
      return bytes;
    });
  }

  /// 改主密码：旧口令立即失效，vault key 不变。
  Future<Uint8List> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final current = _session;
    if (current == null) {
      throw const VaultFormatException('保险库未解锁', code: VaultErrorCode.locked);
    }
    // 两次派生都放在方法体里（而不是写队列闭包里），闭包只捕获参数。
    final onDisk = await (await _vaultFile()).readAsBytes();
    final verified = await Isolate.run(
      () => VaultContainer.unlock(password: currentPassword, bytes: onDisk),
    );
    verified.close();

    final rotated = await Isolate.run(
      () => VaultContainer.changePassword(
        session: current,
        newPassword: newPassword,
      ),
    );
    await _serialize(() async {
      await _writeAtomic(rotated.bytes);
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
    final unlocked = await Isolate.run(
      () => VaultContainer.unlock(password: password, bytes: bytes),
    );
    final file = await _vaultFile();
    if (await file.exists()) {
      await file.copy(p.join((await _directory()).path, preImportFileName));
    }
    await _serialize(() async {
      await _writeAtomic(bytes);
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
    _session?.close();
    _session = null;
  }

  /// 删除库文件与安全副本（危险操作，由 UI 二次确认后调用）。
  Future<void> deleteAll() async {
    lock();
    final directory = await _directory();
    final vault = File(p.join(directory.path, fileName));
    if (await vault.exists()) await vault.delete();
    final preImport = File(p.join(directory.path, preImportFileName));
    if (await preImport.exists()) await preImport.delete();
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
