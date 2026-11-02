import '../l10n/app_localizations.dart';
import 'keycase_state.dart';

/// 把状态码翻译成用户可见文案。
///
/// 错误码与提示码不带上限、不拼接内部信息：Core 抛出的技术细节只进日志。
String errorText(AppLocalizations l10n, KeyCaseError error) {
  return switch (error) {
    KeyCaseError.passwordTooShort => l10n.errorPasswordTooShort,
    KeyCaseError.passwordMismatch => l10n.errorPasswordMismatch,
    KeyCaseError.passwordIncorrect => l10n.errorPasswordIncorrect,
    KeyCaseError.vaultCorrupted => l10n.errorVaultCorrupted,
    KeyCaseError.vaultLocked => l10n.errorVaultLocked,
    KeyCaseError.vaultNotReadable => l10n.errorVaultNotReadable,
    KeyCaseError.saveFailed => l10n.errorSaveFailed,
    KeyCaseError.backupFailed => l10n.errorBackupFailed,
    KeyCaseError.backupUnreadable => l10n.errorBackupUnreadable,
    KeyCaseError.backupWrongPassword => l10n.errorBackupWrongPassword,
    KeyCaseError.biometricUnavailable => l10n.errorBiometricUnavailable,
    KeyCaseError.biometricFailed => l10n.errorBiometricFailed,
    KeyCaseError.biometricEnrolledMissing => l10n.errorBiometricEnrolledMissing,
    KeyCaseError.importFailed => l10n.errorImportFailed,
    KeyCaseError.deleteFailed => l10n.errorDeleteFailed,
    KeyCaseError.aegisPasswordRequired => l10n.errorAegisPasswordRequired,
    KeyCaseError.aegisWrongPassword => l10n.errorAegisWrongPassword,
    KeyCaseError.aegisInvalid => l10n.errorAegisInvalid,
    KeyCaseError.migrationInvalid => l10n.errorMigrationInvalid,
  };
}

String noticeText(AppLocalizations l10n, KeyCaseNotice notice) {
  return switch (notice) {
    KeyCaseNotice.vaultCreated => l10n.noticeVaultCreated,
    KeyCaseNotice.itemSaved => l10n.noticeItemSaved,
    KeyCaseNotice.itemDeleted => l10n.noticeItemDeleted,
    KeyCaseNotice.itemRestored => l10n.noticeItemRestored,
    KeyCaseNotice.itemPurged => l10n.noticeItemPurged,
    KeyCaseNotice.trashEmptied => l10n.noticeTrashEmptied,
    KeyCaseNotice.passwordChanged => l10n.noticePasswordChanged,
    KeyCaseNotice.backupExported => l10n.noticeBackupExported,
    KeyCaseNotice.backupImported => l10n.noticeBackupImported,
    KeyCaseNotice.snapshotSaved => l10n.noticeSnapshotSaved,
    KeyCaseNotice.favoriteUpdated => l10n.noticeFavoriteUpdated,
    KeyCaseNotice.biometricEnabled => l10n.noticeBiometricEnabled,
    KeyCaseNotice.biometricDisabled => l10n.noticeBiometricDisabled,
    KeyCaseNotice.imported => l10n.noticeImported(0),
    KeyCaseNotice.migrationImported => l10n.noticeMigrationImported(0),
  };
}

/// 带数量的导入提示。main 里的全局提示统一走这里，避免 0 条这种占位文案。
String importNoticeText(
  AppLocalizations l10n,
  KeyCaseNotice notice,
  int count,
) {
  return switch (notice) {
    KeyCaseNotice.imported => l10n.noticeImported(count),
    KeyCaseNotice.migrationImported => l10n.noticeMigrationImported(count),
    _ => noticeText(l10n, notice),
  };
}
