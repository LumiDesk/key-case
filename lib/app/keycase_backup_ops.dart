part of 'keycase_controller.dart';

/// 备份目录、立即备份与检查更新。
extension KeyCaseBackupOps on KeyCaseController {
  /// 让用户选备份目录（SAF）。选好即开启自动快照。
  Future<bool> pickBackupFolder() async {
    beginExternalActivity();
    final folder = await _backups.pickFolder();
    if (folder == null) return false;
    await updatePreferences(
      _preferences.copyWith(
        backupTreeUri: folder.uri,
        backupFolderName: folder.name,
        autoSnapshot: true,
      ),
    );
    _emit(_state.copyWith(notice: KeyCaseNotice.backupFolderSelected));
    return true;
  }

  /// 立即写一份快照到备份目录。
  Future<bool> backupNow() {
    final dirUri = _preferences.backupTreeUri;
    if (dirUri.isEmpty) {
      _fail(KeyCaseError.backupFolderMissing);
      return Future<bool>.value(false);
    }
    return _enqueue(() async {
      _emit(_state.copyWith(busy: true, clearError: true, clearNotice: true));
      try {
        final bytes = await _vault.readBytes();
        await _backups.writeSnapshot(dirUri: dirUri, bytes: bytes);
        await updatePreferences(
          _preferences.copyWith(
            lastBackupAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        _emit(
          _state.copyWith(busy: false, notice: KeyCaseNotice.snapshotSaved),
        );
        return true;
      } catch (error) {
        AppLogger.error('manual backup failed', error);
        _fail(KeyCaseError.backupFailed);
        return false;
      }
    });
  }

  /// 检查 GitHub Release。失败返回 `failed: true`，由 UI 给出提示；
  /// 已是最新返回 `info: null`。
  Future<({UpdateInfo? info, bool failed})> checkUpdates() async {
    if (isDisposed) return (info: null, failed: true);
    updateCheckInProgress.value = true;
    _emit(_state.copyWith(busy: true, clearError: true, clearNotice: true));
    try {
      final info = await checkForUpdate(kAppVersion);
      _emit(_state.copyWith(busy: false));
      return (info: info, failed: false);
    } catch (error) {
      AppLogger.warn('update check failed: $error');
      _emit(_state.copyWith(busy: false));
      return (info: null, failed: true);
    } finally {
      if (!isDisposed) updateCheckInProgress.value = false;
    }
  }
}
