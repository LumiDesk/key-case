part of 'keycase_controller.dart';

/// 条目、备份、改密等业务操作。
///
/// 用 extension 而不是把整个 Controller 拆成多个文件：Dart 的类体不能跨文件，
/// 但同一 library 的 extension 可以访问私有成员，体积与职责都保持清晰。
extension KeyCaseControllerOps on KeyCaseController {
  /// 新增或更新条目。标题/时间戳由这里统一维护，UI 不用关心。
  Future<void> saveItem(VaultItem item) => _enqueue(() async {
    final data = _state.data;
    if (data == null) return;
    final now = DateTime.now().toUtc();
    final isNew = !data.items.any((existing) => existing.id == item.id);
    final next = item.copyWith(
      createdAt: isNew ? now : item.createdAt,
      updatedAt: now,
    );
    final items = isNew
        ? <VaultItem>[...data.items, next]
        : data.items
              .map((existing) => existing.id == next.id ? next : existing)
              .toList();
    await _persist(
      data.copyWith(items: items),
      notice: KeyCaseNotice.itemSaved,
    );
  });

  /// 软删除：进回收站，可恢复。
  Future<void> deleteItem(String itemId) => _enqueue(() async {
    final data = _state.data;
    if (data == null) return;
    final now = DateTime.now().toUtc();
    final items = data.items
        .map(
          (item) => item.id == itemId
              ? item.copyWith(deletedAt: now, updatedAt: now)
              : item,
        )
        .toList();
    await _persist(
      data.copyWith(items: items),
      notice: KeyCaseNotice.itemDeleted,
    );
  });

  Future<void> restoreItem(String itemId) => _enqueue(() async {
    final data = _state.data;
    if (data == null) return;
    final now = DateTime.now().toUtc();
    final items = data.items
        .map(
          (item) => item.id == itemId
              ? item.copyWith(deletedAt: null, updatedAt: now)
              : item,
        )
        .toList();
    await _persist(
      data.copyWith(items: items),
      notice: KeyCaseNotice.itemRestored,
    );
  });

  /// 永久删除单条（不进回收站）。
  Future<void> purgeItem(String itemId) => _enqueue(() async {
    final data = _state.data;
    if (data == null) return;
    final items = data.items.where((item) => item.id != itemId).toList();
    await _persist(
      data.copyWith(items: items),
      notice: KeyCaseNotice.itemPurged,
    );
  });

  Future<void> emptyTrash() => _enqueue(() async {
    final data = _state.data;
    if (data == null) return;
    final items = data.items.where((item) => !item.isDeleted).toList();
    await _persist(
      data.copyWith(items: items),
      notice: KeyCaseNotice.trashEmptied,
    );
  });

  Future<void> toggleFavorite(String itemId) => _enqueue(() async {
    final data = _state.data;
    if (data == null) return;
    final item = data.itemById(itemId);
    if (item == null) return;
    final items = data.items
        .map(
          (existing) => existing.id == itemId
              ? existing.copyWith(favorite: !item.favorite)
              : existing,
        )
        .toList();
    await _persist(
      data.copyWith(items: items),
      notice: KeyCaseNotice.favoriteUpdated,
    );
  });

  /// HOTP 的「下一个」：计数器 +1 后落库，旧的码立即失效。
  Future<void> advanceHotp(String itemId) => _enqueue(() async {
    final data = _state.data;
    if (data == null) return;
    final item = data.itemById(itemId);
    final token = item?.token;
    if (item == null || token == null) return;
    final now = DateTime.now().toUtc();
    final updated = VaultItem.tokenItem(
      id: item.id,
      title: item.title,
      token: token.copyWith(
        secret: token.secret.copyWith(counter: token.secret.counter + 1),
      ),
      favorite: item.favorite,
      icon: item.icon,
      createdAt: item.createdAt,
      updatedAt: now,
      deletedAt: item.deletedAt,
    );
    final items = data.items
        .map((existing) => existing.id == itemId ? updated : existing)
        .toList();
    await _persist(data.copyWith(items: items));
  });

  Future<bool> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (newPassword.length < KeyCaseController.minMasterPasswordLength) {
      _fail(KeyCaseError.passwordTooShort);
      return false;
    }
    if (newPassword != confirmPassword) {
      _fail(KeyCaseError.passwordMismatch);
      return false;
    }
    return _enqueue(() async {
      _emit(_state.copyWith(busy: true, clearError: true, clearNotice: true));
      try {
        await _vault.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
        _emit(
          _state.copyWith(busy: false, notice: KeyCaseNotice.passwordChanged),
        );
        return true;
      } on VaultFormatException catch (error) {
        _fail(_mapVaultError(error));
      } catch (error) {
        AppLogger.error('change password failed', error);
        _fail(KeyCaseError.saveFailed);
      }
      return false;
    });
  }

  /// 导出当前库到用户选择的位置（系统文档选择器）。
  Future<bool> exportBackup() async {
    if (!_state.isUnlocked) return false;
    _emit(_state.copyWith(busy: true, clearError: true, clearNotice: true));
    beginExternalActivity();
    try {
      final bytes = await _vault.readBytes();
      final path = await _backups.exportToUser(bytes);
      _emit(
        _state.copyWith(
          busy: false,
          notice: path == null ? null : KeyCaseNotice.backupExported,
          clearNotice: path == null,
        ),
      );
      return path != null;
    } catch (error) {
      AppLogger.error('export backup failed', error);
      _fail(KeyCaseError.backupFailed);
      return false;
    }
  }

  /// 让用户挑一个备份文件；取消返回 null，读不出来时给出错误码。
  Future<Uint8List?> pickBackupFile() async {
    beginExternalActivity();
    try {
      return await _backups.pickImportFile();
    } catch (error) {
      AppLogger.error('pick backup failed', error);
      _fail(KeyCaseError.backupUnreadable);
      return null;
    }
  }

  /// 用备份替换当前库。成功后原库会保留为 `vault.kcv.pre-import`。
  ///
  /// 只接受当前 `KCV1` 容器；口令错误与格式错误分别映射到对应提示。
  Future<bool> importBackup({
    required Uint8List bytes,
    required String password,
  }) {
    return _enqueue(() async {
      _emit(_state.copyWith(busy: true, clearError: true, clearNotice: true));
      try {
        final session = await _vault.replaceWithBackup(
          bytes: bytes,
          password: password,
        );
        _emit(
          _state.copyWith(
            status: VaultStatus.unlocked,
            data: session.data,
            busy: false,
            notice: KeyCaseNotice.backupImported,
          ),
        );
        return true;
      } on VaultFormatException catch (error) {
        _fail(
          error.code == VaultErrorCode.wrongPassword
              ? KeyCaseError.backupWrongPassword
              : KeyCaseError.backupFailed,
        );
      } catch (error) {
        AppLogger.error('import backup failed', error);
        _fail(KeyCaseError.backupFailed);
      }
      return false;
    });
  }

  /// 删除本机保险库（不可恢复），同时清掉生物识别包裹密钥。
  Future<void> deleteVault() => _enqueue(() async {
    try {
      await _vault.deleteAll();
      await _native.clearVaultKey();
      await updatePreferences(_preferences.copyWith(biometricEnabled: false));
      _emit(const KeyCaseState(status: VaultStatus.missing));
    } catch (error) {
      AppLogger.error('delete vault failed', error);
      _fail(KeyCaseError.deleteFailed);
    }
  });

  Future<void> _persist(VaultData next, {KeyCaseNotice? notice}) async {
    _emit(_state.copyWith(busy: true, clearError: true, clearNotice: true));
    try {
      final bytes = await _vault.save(next);
      // 保存期间可能已经锁定；锁定后绝不把明文写回状态。
      if (!_state.isUnlocked || _state.data == null) return;
      _emit(
        _state.copyWith(
          data: next,
          busy: false,
          notice: notice,
          clearNotice: notice == null,
        ),
      );
      await _snapshotBytesQuietly(bytes);
    } on VaultFormatException catch (error) {
      _fail(_mapVaultError(error));
    } catch (error) {
      AppLogger.error('persist failed', error);
      _fail(KeyCaseError.saveFailed);
    }
  }
}

/// 第三方数据导入：Aegis 保险库与 Google Authenticator 迁移链接。
extension KeyCaseImportOps on KeyCaseController {
  /// 选一个 Aegis 导出文件（.json）；取消返回 null。
  Future<Uint8List?> pickAegisFile() async {
    beginExternalActivity();
    try {
      return await _backups.pickDocument(
        label: 'Aegis 导出文件',
        extensions: const <String>['json', 'txt'],
      );
    } catch (error) {
      AppLogger.error('pick aegis file failed', error);
      _fail(KeyCaseError.aegisInvalid);
      return null;
    }
  }

  /// 导入 Aegis 导出（合并进现有库，重复项跳过）。
  Future<bool> importAegisBytes({required Uint8List bytes, String? password}) {
    return _enqueue(() async {
      final data = _state.data;
      if (data == null) return false;
      _emit(_state.copyWith(busy: true, clearError: true, clearNotice: true));
      try {
        final result = await importAegisVault(bytes, password: password);
        final merged = mergeImportedItems(data, result.items);
        final sealed = await _vault.save(merged.data);
        if (!_state.isUnlocked) return false;
        _emit(
          _state.copyWith(
            data: merged.data,
            busy: false,
            notice: KeyCaseNotice.imported,
            lastImportCount: merged.imported,
          ),
        );
        await _snapshotBytesQuietly(sealed);
        return true;
      } on AegisImportException catch (error) {
        _fail(_mapAegisError(error));
      } catch (error) {
        AppLogger.error('import aegis failed', error);
        _fail(KeyCaseError.importFailed);
      }
      return false;
    });
  }

  /// 导入 Google Authenticator 迁移链接（`otpauth-migration://...`）。
  Future<bool> importGoogleMigrationLink(String link) {
    return _enqueue(() async {
      final data = _state.data;
      if (data == null) return false;
      _emit(_state.copyWith(busy: true, clearError: true, clearNotice: true));
      try {
        final entries = parseGoogleMigration(link);
        final now = DateTime.now().toUtc();
        final imported = <VaultItem>[
          for (var i = 0; i < entries.length; i++)
            entries[i].toItem(
              now,
              'migration-${now.microsecondsSinceEpoch}-$i',
            ),
        ];
        final merged = mergeImportedItems(data, imported);
        final sealed = await _vault.save(merged.data);
        if (!_state.isUnlocked) return false;
        _emit(
          _state.copyWith(
            data: merged.data,
            busy: false,
            notice: KeyCaseNotice.migrationImported,
            lastImportCount: merged.imported,
          ),
        );
        await _snapshotBytesQuietly(sealed);
        return true;
      } on GoogleMigrationException catch (error) {
        AppLogger.warn('google migration invalid: $error');
        _fail(KeyCaseError.migrationInvalid);
      } catch (error) {
        AppLogger.error('import google migration failed', error);
        _fail(KeyCaseError.importFailed);
      }
      return false;
    });
  }

  KeyCaseError _mapAegisError(AegisImportException error) {
    return switch (error.code) {
      AegisErrorCode.passwordRequired => KeyCaseError.aegisPasswordRequired,
      AegisErrorCode.wrongPassword => KeyCaseError.aegisWrongPassword,
      AegisErrorCode.notAegis ||
      AegisErrorCode.unsupported ||
      AegisErrorCode.tooLarge => KeyCaseError.aegisInvalid,
    };
  }
}
