import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_version.dart';
import 'data/preferences_store.dart';
import 'import/aegis_importer.dart';
import 'import/google_migration.dart';
import 'import/import_merge.dart';
import 'keycase_state.dart';
import 'logging/app_logger.dart';
import 'models/models.dart';
import 'otp/otp_clock.dart';
import 'platform/biometric_auth.dart';
import 'update/update_checker.dart';
import 'platform/native_bridge.dart';
import 'vault/backup_service.dart';
import 'vault/vault_container.dart';
import 'vault/vault_repository.dart';

part 'keycase_backup_ops.dart';
part 'keycase_controller_ops.dart';

/// 应用唯一的状态源。
///
/// 规则：
/// - UI 只调用这里的公共方法，不直接访问 repository、文件或 Keystore；
/// - 所有落盘操作都经 [_persist]/[_vault]，失败必须让用户知道；
/// - 偏好与保险库内容分开：偏好走 [PreferencesStore]，内容进加密容器。
class KeyCaseController extends ChangeNotifier {
  KeyCaseController({
    VaultRepository? vault,
    PreferencesStore? preferencesStore,
    BackupService? backups,
    NativeBridge? nativeBridge,
    BiometricAuth? biometrics,
  }) : _vault = vault ?? VaultRepository(),
       _preferencesStore = preferencesStore ?? PreferencesStore(),
       _backups = backups ?? BackupService(),
       _native = nativeBridge ?? NativeBridge(),
       _biometrics = biometrics ?? BiometricAuth();

  static const int minMasterPasswordLength = 8;

  final VaultRepository _vault;
  final PreferencesStore _preferencesStore;
  final BackupService _backups;
  final NativeBridge _native;
  final BiometricAuth _biometrics;

  /// 全应用唯一的秒级时钟，令牌列表与详情共用。
  ///
  /// 延迟到第一次访问时才创建：锁定页与只在登录项之间切换的页面不必常驻
  /// 一个每秒触发的 Timer。
  OtpClock? _clock;
  OtpClock get clock => _clock ??= OtpClock();

  /// 检查更新是唯一会联网的动作；设置页用它显示行内加载态。
  final ValueNotifier<bool> updateCheckInProgress = ValueNotifier<bool>(false);

  KeyCaseState _state = const KeyCaseState();
  AppPreferences _preferences = const AppPreferences();

  DateTime? _pausedAt;
  bool _externalActivityOpen = false;
  bool _disposed = false;

  /// 供异步扩展在回调落地前判断生命周期。
  bool get isDisposed => _disposed;
  DateTime? _lastAutoSnapshotAt;

  /// 串行化所有会修改保险库的操作。每个操作在队列里读取“执行时”的状态，
  /// 避免快速连点/并发导入时用旧快照覆盖新结果。
  Future<void> _opTail = Future<void>.value();

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _opTail.then((_) => action());
    _opTail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  KeyCaseState get state => _state;

  AppPreferences get preferences => _preferences;

  /// 启动：读偏好、判断本机有没有库。
  Future<void> bootstrap() async {
    try {
      _preferences = await _preferencesStore.load();
      await _native.setSecureScreen(_preferences.secureScreen);
      final exists = await _vault.exists();
      _emit(
        _state.copyWith(
          status: exists ? VaultStatus.locked : VaultStatus.missing,
          biometricEnrolled: _preferences.biometricEnabled,
          clearError: true,
        ),
      );
    } catch (error) {
      AppLogger.error('bootstrap failed', error);
      _emit(
        const KeyCaseState(
          status: VaultStatus.locked,
          error: KeyCaseError.vaultNotReadable,
        ),
      );
    }
  }

  Future<bool> createVault({
    required String password,
    required String confirm,
  }) async {
    if (password.length < minMasterPasswordLength) {
      _fail(KeyCaseError.passwordTooShort);
      return false;
    }
    if (password != confirm) {
      _fail(KeyCaseError.passwordMismatch);
      return false;
    }
    if (_state.busy) return false;

    _emit(_state.copyWith(busy: true, clearError: true, clearNotice: true));
    try {
      final session = await _vault.create(
        password: password,
        data: VaultData(vaultId: '', createdAt: DateTime.now().toUtc()),
      );
      _emit(
        _state.copyWith(
          status: VaultStatus.unlocked,
          data: session.data,
          busy: false,
          notice: KeyCaseNotice.vaultCreated,
        ),
      );
      await _snapshotQuietly();
      return true;
    } on VaultFormatException catch (error) {
      _fail(_mapVaultError(error));
    } catch (error) {
      AppLogger.error('create vault failed', error);
      _fail(KeyCaseError.saveFailed);
    }
    return false;
  }

  Future<bool> unlock(String password) async {
    if (_state.busy) return false;
    if (password.isEmpty) {
      _fail(KeyCaseError.passwordIncorrect);
      return false;
    }
    _emit(_state.copyWith(busy: true, clearError: true, clearNotice: true));
    try {
      final session = await _vault.unlock(password);
      _clock?.resume();
      _emit(
        _state.copyWith(
          status: VaultStatus.unlocked,
          data: session.data,
          busy: false,
        ),
      );
      return true;
    } on VaultFormatException catch (error) {
      _fail(_mapVaultError(error));
    } catch (error) {
      AppLogger.error('unlock failed', error);
      _fail(KeyCaseError.vaultNotReadable);
    }
    return false;
  }

  /// 生物识别解锁：先验证指纹，再用 Keystore 里的密钥直接解正文。
  Future<bool> unlockWithBiometrics({
    required String reason,
    String cancelLabel = '取消',
  }) async {
    if (_state.busy) return false;
    if (!_state.biometricEnrolled) {
      _fail(KeyCaseError.biometricEnrolledMissing);
      return false;
    }
    _emit(_state.copyWith(busy: true, clearError: true, clearNotice: true));
    try {
      final header = await _vault.inspect();
      if (header == null) {
        _fail(KeyCaseError.vaultNotReadable);
        return false;
      }
      final result = await _biometrics.authenticate(
        reason: reason,
        cancelLabel: cancelLabel,
      );
      switch (result) {
        case BiometricResult.success:
          break;
        case BiometricResult.canceled:
          _emit(_state.copyWith(busy: false, clearError: true));
          return false;
        case BiometricResult.unavailable:
          _fail(KeyCaseError.biometricUnavailable);
          return false;
        case BiometricResult.failed:
          _fail(KeyCaseError.biometricFailed);
          return false;
      }
      final vaultKey = await _native.readVaultKey(header.vaultId);
      if (vaultKey == null) {
        // 密钥被系统清理（换指纹、恢复出厂、重装）：退回主密码并解除登记。
        await disableBiometrics();
        _fail(KeyCaseError.biometricEnrolledMissing);
        return false;
      }
      final session = await _vault.unlockWithVaultKey(vaultKey);
      _clock?.resume();
      _emit(
        _state.copyWith(
          status: VaultStatus.unlocked,
          data: session.data,
          busy: false,
        ),
      );
      return true;
    } on VaultFormatException catch (error) {
      _fail(_mapVaultError(error));
    } catch (error) {
      AppLogger.error('biometric unlock failed', error);
      _fail(KeyCaseError.biometricFailed);
    }
    return false;
  }

  /// 设置页用来决定指纹开关是否可操作；真正的启用路径仍会再校验一次。
  Future<bool> canUseBiometrics() => _biometrics.isAvailable();

  Future<bool> enableBiometrics({
    required String reason,
    String cancelLabel = '取消',
  }) async {
    final session = _vault.session;
    if (session == null) {
      _fail(KeyCaseError.vaultLocked);
      return false;
    }
    if (!await _biometrics.isAvailable()) {
      _fail(KeyCaseError.biometricUnavailable);
      return false;
    }
    final result = await _biometrics.authenticate(
      reason: reason,
      cancelLabel: cancelLabel,
    );
    switch (result) {
      case BiometricResult.success:
        break;
      case BiometricResult.canceled:
        return false;
      case BiometricResult.unavailable:
        _fail(KeyCaseError.biometricUnavailable);
        return false;
      case BiometricResult.failed:
        _fail(KeyCaseError.biometricFailed);
        return false;
    }
    // vault key 由 Keystore 加密后落在原生侧，Dart 内存里不留持久副本。
    final stored = await _native.storeVaultKey(
      key: session.vaultKey,
      vaultId: session.header.vaultId,
    );
    if (!stored) {
      _fail(KeyCaseError.biometricUnavailable);
      return false;
    }
    await updatePreferences(_preferences.copyWith(biometricEnabled: true));
    _emit(
      _state.copyWith(
        biometricEnrolled: true,
        notice: KeyCaseNotice.biometricEnabled,
      ),
    );
    return true;
  }

  Future<void> disableBiometrics() async {
    await _native.clearVaultKey();
    await updatePreferences(_preferences.copyWith(biometricEnabled: false));
    _emit(
      _state.copyWith(
        biometricEnrolled: false,
        notice: KeyCaseNotice.biometricDisabled,
      ),
    );
  }

  void lock() {
    if (!_state.isUnlocked) return;
    _clock?.pause();
    _vault.lock();
    _emit(
      _state.copyWith(
        status: VaultStatus.locked,
        busy: false,
        clearError: true,
        clearNotice: true,
        clearData: true,
      ),
    );
  }

  /// 打开系统文档选择器/扫码页前调用：这些外部界面会让进程进入后台，
  /// 不应触发自动锁定，否则用户回来时流程被打断。
  void beginExternalActivity() {
    _externalActivityOpen = true;
  }

  void handleAppPaused() {
    _clock?.pause();
    _pausedAt = DateTime.now();
    if (_externalActivityOpen) return;
    if (_preferences.autoLockSeconds == 0) {
      lock();
    }
  }

  void handleAppResumed() {
    _clock?.resume();
    final pausedAt = _pausedAt;
    _pausedAt = null;
    final wasExternal = _externalActivityOpen;
    _externalActivityOpen = false;
    if (pausedAt == null || wasExternal || !_state.isUnlocked) return;
    final timeout = _preferences.autoLockSeconds;
    if (timeout < 0) return;
    if (DateTime.now().difference(pausedAt).inSeconds >= timeout) {
      lock();
    }
  }

  Future<void> updatePreferences(AppPreferences next) async {
    final previous = _preferences;
    _preferences = next;
    await _preferencesStore.save(next);
    if (previous.secureScreen != next.secureScreen) {
      await _native.setSecureScreen(next.secureScreen);
    }
    if (!next.biometricEnabled && previous.biometricEnabled) {
      await _native.clearVaultKey();
    }
    _emit(_state.copyWith(biometricEnrolled: next.biometricEnabled));
  }

  void clearError() => _emit(_state.copyWith(clearError: true));

  void clearNotice() => _emit(_state.copyWith(clearNotice: true));

  KeyCaseError _mapVaultError(VaultFormatException error) {
    return switch (error.code) {
      VaultErrorCode.wrongPassword => KeyCaseError.passwordIncorrect,
      VaultErrorCode.corrupted ||
      VaultErrorCode.unsupportedVersion ||
      VaultErrorCode.notAVault ||
      VaultErrorCode.tooLarge ||
      VaultErrorCode.migration => KeyCaseError.vaultCorrupted,
      VaultErrorCode.locked => KeyCaseError.vaultLocked,
      VaultErrorCode.unknown => KeyCaseError.vaultNotReadable,
    };
  }

  void _fail(KeyCaseError error) {
    _emit(_state.copyWith(busy: false, error: error));
  }

  /// 自动快照：只在用户选过备份目录且开关打开时写入，失败只记日志，
  /// 绝不影响保存结果。
  Future<void> _snapshotQuietly() async {
    try {
      await _snapshotBytesQuietly(await _vault.readBytes());
    } catch (error) {
      AppLogger.warn('auto snapshot failed: $error');
    }
  }

  Future<void> _snapshotBytesQuietly(Uint8List bytes) async {
    if (!_preferences.autoSnapshot) return;
    final dirUri = _preferences.backupTreeUri;
    if (dirUri.isEmpty) return;
    final now = DateTime.now();
    final last = _lastAutoSnapshotAt;
    if (last != null && now.difference(last) < const Duration(minutes: 1)) {
      return;
    }
    try {
      await _backups.writeSnapshot(dirUri: dirUri, bytes: bytes);
      _lastAutoSnapshotAt = now;
      await updatePreferences(
        _preferences.copyWith(
          lastBackupAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } catch (error) {
      AppLogger.warn('auto snapshot failed: $error');
    }
  }

  void _emit(KeyCaseState next) {
    _state = next;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _clock?.dispose();
    updateCheckInProgress.dispose();
    _vault.lock();
    super.dispose();
  }
}
