// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navLogins => 'Logins';

  @override
  String get navTokens => 'Tokens';

  @override
  String get navSettings => 'Settings';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionMore => 'More';

  @override
  String get actionClose => 'Close';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionBack => 'Back';

  @override
  String get actionNext => 'Next';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionSort => 'Sort';

  @override
  String get actionRestore => 'Restore';

  @override
  String get pressBackAgainToExit => 'Press back again to exit';

  @override
  String get copied => 'Copied';

  @override
  String get loading => 'Working…';

  @override
  String get createTitle => 'Create your vault';

  @override
  String get createSubtitle =>
      'The master password stays in your head. Nobody can recover it for you.';

  @override
  String get masterPassword => 'Master password';

  @override
  String get confirmPassword => 'Confirm master password';

  @override
  String get passwordHint => 'At least 8 characters';

  @override
  String get createVault => 'Create vault';

  @override
  String get unlockTitle => 'Unlock KeyCase';

  @override
  String get unlockSubtitle => 'Enter your master password to continue';

  @override
  String get unlock => 'Unlock';

  @override
  String get useBiometric => 'Unlock with fingerprint';

  @override
  String get strengthWeak => 'Weak';

  @override
  String get strengthFair => 'Fair';

  @override
  String get strengthGood => 'Good';

  @override
  String get strengthStrong => 'Strong';

  @override
  String get homeTitle => 'Home';

  @override
  String get homeSubtitle => 'Local vault · this device only';

  @override
  String get homeOverview => 'Vault overview';

  @override
  String get statLogins => 'Logins';

  @override
  String get statTokens => 'Tokens';

  @override
  String get statSecurity => 'Issues';

  @override
  String get homeFavorites => 'Favorites';

  @override
  String get homeRecent => 'Recently updated';

  @override
  String homeSecurityAlert(int count) {
    return '$count items need attention';
  }

  @override
  String get homeAllGood => 'All security checks passed';

  @override
  String get homeEmptyTitle => 'No items yet';

  @override
  String get homeEmptyDesc =>
      'Add your first login or scan a QR code for a token.';

  @override
  String get loginsTitle => 'Logins';

  @override
  String get loginsEmpty => 'No logins yet';

  @override
  String get loginsEmptyDesc => 'Tap the plus button to add an account.';

  @override
  String get tokensTitle => 'Tokens';

  @override
  String get tokensEmpty => 'No tokens yet';

  @override
  String get tokensEmptyDesc => 'Scan a QR code or enter a secret manually.';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHint => 'Search names, accounts, URLs';

  @override
  String get searchNoResults => 'No matches';

  @override
  String get searchNoResultsDesc => 'Try a different keyword.';

  @override
  String get sortByName => 'By name';

  @override
  String get sortByRecent => 'By recent';

  @override
  String get sortByFavorites => 'Favorites first';

  @override
  String get detailUsername => 'Account';

  @override
  String get detailPassword => 'Password';

  @override
  String get detailUrl => 'URL';

  @override
  String get detailNotes => 'Notes';

  @override
  String get detailCreated => 'Created';

  @override
  String get detailUpdated => 'Updated';

  @override
  String get detailTokenType => 'Type';

  @override
  String get detailTokenAlgorithm => 'Algorithm';

  @override
  String get detailTokenDigits => 'Digits';

  @override
  String get detailTokenPeriod => 'Period';

  @override
  String get detailTokenCounter => 'Counter';

  @override
  String get detailShowCode => 'Show code';

  @override
  String get detailHideCode => 'Hide code';

  @override
  String get detailDelete => 'Move to trash';

  @override
  String get detailDeleteMessage =>
      'The item goes to trash and can be restored.';

  @override
  String get detailFavorite => 'Favorite';

  @override
  String get detailUnfavorite => 'Remove favorite';

  @override
  String get editorNewLogin => 'New login';

  @override
  String get editorNewToken => 'New token';

  @override
  String get editorEditLogin => 'Edit login';

  @override
  String get editorEditToken => 'Edit token';

  @override
  String get editorTitle => 'Name';

  @override
  String get editorTitleHint => 'e.g. GitHub';

  @override
  String get editorUsername => 'Account';

  @override
  String get editorPassword => 'Password';

  @override
  String get editorUrl => 'URL';

  @override
  String get editorUrls => 'URLs (one per line)';

  @override
  String get editorNotes => 'Notes';

  @override
  String get editorGenerate => 'Generate random password';

  @override
  String get editorTokenIssuer => 'Service';

  @override
  String get editorTokenAccount => 'Account';

  @override
  String get editorTokenSecret => 'Secret (Base32)';

  @override
  String get editorTokenType => 'Token type';

  @override
  String get editorAdvanced => 'Advanced';

  @override
  String get editorAlgorithm => 'Algorithm';

  @override
  String get editorDigits => 'Digits';

  @override
  String get editorPeriod => 'Period (s)';

  @override
  String get editorCounter => 'Counter';

  @override
  String get editorScanQr => 'Scan QR code';

  @override
  String get scanCameraUnavailable =>
      'Camera unavailable. Check permissions and try again.';

  @override
  String get editorDiscardTitle => 'Discard changes?';

  @override
  String get editorDiscardMessage => 'Your edits have not been saved.';

  @override
  String get editorDiscard => 'Discard';

  @override
  String get editorUrlInvalid => 'Invalid URL';

  @override
  String get editorSecretInvalid => 'Not a valid Base32 secret';

  @override
  String get editorTitleRequired => 'Name is required';

  @override
  String get tokenTypeTotp => 'TOTP';

  @override
  String get tokenTypeHotp => 'HOTP';

  @override
  String get tokenTypeSteam => 'Steam';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Display mode';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageChinese => 'Chinese';

  @override
  String get languageEnglish => 'English';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsAccent => 'Accent color';

  @override
  String get accentSystem => 'System';

  @override
  String get accentCustom => 'Custom';

  @override
  String get accentBlue => 'Blue';

  @override
  String get accentTeal => 'Teal';

  @override
  String get accentGreen => 'Green';

  @override
  String get accentAmber => 'Amber';

  @override
  String get accentRose => 'Rose';

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsSecureScreen => 'Block screenshots';

  @override
  String get settingsSecureScreenDesc =>
      'Disable system screenshots and recording';

  @override
  String get settingsClipboardClear => 'Clear clipboard after copy';

  @override
  String get settingsClipboardClearDesc =>
      'Clears passwords and codes after 60 seconds';

  @override
  String get settingsAutoLock => 'Auto-lock';

  @override
  String get autoLockImmediate => 'Immediately';

  @override
  String get autoLock30 => '30 seconds';

  @override
  String get autoLock60 => '1 minute';

  @override
  String get autoLock300 => '5 minutes';

  @override
  String get autoLockNever => 'Never';

  @override
  String get settingsBiometric => 'Fingerprint unlock';

  @override
  String get settingsBiometricOn => 'Enabled';

  @override
  String get settingsBiometricOff => 'Disabled';

  @override
  String get settingsChangePassword => 'Change master password';

  @override
  String get settingsLockNow => 'Lock now';

  @override
  String get settingsTokens => 'Tokens';

  @override
  String get settingsShowCodes => 'Show codes';

  @override
  String get settingsShowCodesDesc => 'When off, digits are dots until you tap';

  @override
  String get settingsShowNext => 'Show next code';

  @override
  String get settingsShowNextDesc =>
      'Show the upcoming code below the current one';

  @override
  String get settingsGrouping => 'Code grouping';

  @override
  String get groupingAuto => 'Auto';

  @override
  String get groupingThree => '3';

  @override
  String get groupingFour => '4';

  @override
  String get groupingNone => 'None';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsExport => 'Export encrypted backup';

  @override
  String get settingsExportDesc =>
      'A .kcbak file encrypted with your master password';

  @override
  String get settingsImport => 'Import encrypted backup';

  @override
  String get settingsImportDesc => 'Replaces the current vault';

  @override
  String get settingsAutoSnapshot => 'Automatic snapshots';

  @override
  String get settingsAutoSnapshotDesc =>
      'Keep the 10 most recent encrypted snapshots after each save';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsLicenses => 'Open source licenses';

  @override
  String get settingsLicensesDesc => 'Flutter and bundled components';

  @override
  String get settingsPrivacyBody =>
      'KeyCase uploads nothing: no account, no sync, no analytics. Everything lives in the encrypted container on this device.';

  @override
  String get settingsGithub => 'GitHub';

  @override
  String get settingsGithubDesc => 'github.com/LumiDesk/key-case';

  @override
  String get settingsDanger => 'Danger zone';

  @override
  String get settingsDeleteVault => 'Delete vault';

  @override
  String get settingsDeleteVaultDesc =>
      'Permanently delete every password and token on this device';

  @override
  String get settingsDeleteVaultMessage =>
      'This cannot be undone and there is no cloud copy. Export a backup first.';

  @override
  String get securityTitle => 'Security center';

  @override
  String get securityWeak => 'Weak passwords';

  @override
  String get securityReused => 'Reused passwords';

  @override
  String get securityStale => 'Outdated passwords';

  @override
  String get securityWeakDesc => 'Too short or too simple, easy to guess.';

  @override
  String get securityReusedDesc =>
      'One password on several accounts: one leak exposes all of them.';

  @override
  String get securityStaleDesc => 'Not updated for more than a year.';

  @override
  String get securityAllGood => 'Nothing to fix';

  @override
  String get securityAllGoodDesc => 'Every login looks clean right now.';

  @override
  String get trashTitle => 'Trash';

  @override
  String get trashEmptyCount => 'None';

  @override
  String get trashEmpty => 'Trash is empty';

  @override
  String get trashEmptyDesc => 'Deleted items wait here first.';

  @override
  String get trashPurge => 'Delete permanently';

  @override
  String get trashPurgeMessage =>
      'Permanently deleted items cannot be recovered.';

  @override
  String get trashEmptyAll => 'Empty trash';

  @override
  String get trashEmptyAllMessage =>
      'Every item in the trash will be deleted permanently.';

  @override
  String get changePasswordTitle => 'Change master password';

  @override
  String get currentPassword => 'Current master password';

  @override
  String get newPassword => 'New master password';

  @override
  String get confirmNewPassword => 'Confirm new master password';

  @override
  String get importBackupTitle => 'Import encrypted backup';

  @override
  String get importBackupPassword => 'Backup master password';

  @override
  String get restoreFromBackup => 'Restore from encrypted backup';

  @override
  String get restoreBackupMessage =>
      'This replaces the current vault and disables fingerprint unlock. Continue?';

  @override
  String get settingsImportAegis => 'Import from Aegis';

  @override
  String get settingsImportAegisDesc => 'Merge tokens from an Aegis export';

  @override
  String get settingsImportGoogle => 'Import from Google Authenticator';

  @override
  String get settingsImportGoogleDesc =>
      'Paste a migration link or scan its QR code';

  @override
  String get aegisPasswordTitle => 'Aegis backup password';

  @override
  String get aegisPasswordHint => 'Leave empty for unencrypted exports';

  @override
  String get googleMigrationTitle => 'Google migration link';

  @override
  String get googleMigrationHint => 'otpauth-migration://…';

  @override
  String noticeImported(int count) {
    return 'Imported $count items';
  }

  @override
  String noticeMigrationImported(int count) {
    return 'Migrated $count tokens';
  }

  @override
  String get errorAegisPasswordRequired =>
      'This Aegis backup is encrypted, enter its password';

  @override
  String get errorAegisWrongPassword => 'Wrong Aegis backup password';

  @override
  String get errorAegisInvalid => 'Not a valid Aegis export';

  @override
  String get aegisUnnamed => 'Unnamed item';

  @override
  String get errorMigrationInvalid => 'Not a valid Google migration link';

  @override
  String get editorIcon => 'Icon';

  @override
  String get iconPickerTitle => 'Choose an icon';

  @override
  String get iconSearchHint => 'Search brands';

  @override
  String get iconCustom => 'Use a custom image';

  @override
  String get errorImagePickFailed => 'Could not read the image';

  @override
  String get iconRemove => 'Back to automatic';

  @override
  String get noticeVaultCreated => 'Vault created';

  @override
  String get noticeItemSaved => 'Saved';

  @override
  String get noticeItemDeleted => 'Moved to trash';

  @override
  String get noticeItemRestored => 'Restored';

  @override
  String get noticeItemPurged => 'Deleted permanently';

  @override
  String get noticeTrashEmptied => 'Trash emptied';

  @override
  String get noticePasswordChanged => 'Master password updated';

  @override
  String get noticeBackupExported => 'Backup exported';

  @override
  String get noticeBackupImported => 'Backup imported';

  @override
  String get noticeSnapshotSaved => 'Snapshot saved';

  @override
  String get noticeBiometricEnabled => 'Fingerprint unlock enabled';

  @override
  String get noticeBiometricDisabled => 'Fingerprint unlock disabled';

  @override
  String get errorPasswordTooShort =>
      'Master password must be at least 8 characters';

  @override
  String get errorPasswordMismatch => 'The passwords do not match';

  @override
  String get errorPasswordIncorrect => 'Wrong master password';

  @override
  String get errorVaultCorrupted =>
      'Vault is corrupted or from an unsupported version';

  @override
  String get errorVaultLocked => 'Vault is locked';

  @override
  String get errorVaultNotReadable => 'Cannot read the vault file';

  @override
  String get errorSaveFailed => 'Save failed, please retry';

  @override
  String get errorBackupFailed => 'Backup failed';

  @override
  String get errorBackupUnreadable => 'Cannot read the backup file';

  @override
  String get errorBackupWrongPassword => 'Wrong backup master password';

  @override
  String get errorBiometricUnavailable =>
      'No biometrics available on this device';

  @override
  String get errorBiometricFailed => 'Fingerprint verification failed';

  @override
  String get errorBiometricEnrolledMissing =>
      'Fingerprint unlock expired, use the master password';

  @override
  String get errorImportFailed => 'Import failed';

  @override
  String get errorDeleteFailed => 'Delete failed';

  @override
  String get errorOpenLinkFailed => 'Could not open link';

  @override
  String get biometricUnlockReason =>
      'Verify your fingerprint to unlock KeyCase';

  @override
  String get biometricEnableReason =>
      'Verify your fingerprint to enable quick unlock';

  @override
  String get deleteVaultAction => 'Delete vault';

  @override
  String get errorBackupFolderMissing => 'No backup folder selected yet';

  @override
  String get noticeBackupFolderSelected => 'Backup folder set';

  @override
  String get settingsBackupFolder => 'Backup folder';

  @override
  String get settingsBackupFolderNone => 'Not selected';

  @override
  String get settingsLastBackup => 'Last backup';

  @override
  String get settingsBackupNever => 'Never';

  @override
  String get settingsBackupNow => 'Back up now';

  @override
  String get settingsBackupNowDesc =>
      'Writes one encrypted snapshot and keeps the latest 10';

  @override
  String get settingsCheckUpdate => 'Check for updates';

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String get updateCurrentVersion => 'Current version';

  @override
  String get updateLatestVersion => 'Latest version';

  @override
  String get updateOpenRelease => 'Open release';

  @override
  String get updateUpToDate => 'You are up to date';

  @override
  String get updateCheckFailed => 'Update check failed';

  @override
  String get themeColorTitle => 'Custom accent color';

  @override
  String get themeColorHue => 'Hue';

  @override
  String get themeColorSaturation => 'Saturation';

  @override
  String get themeColorBrightness => 'Brightness';

  @override
  String get themeColorPreview => 'Preview';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get tokenAddScan => 'Scan to add';

  @override
  String get tokenAddManual => 'Add manually';

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count h ago';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count days ago';
  }

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }
}
