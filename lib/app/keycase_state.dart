import 'models/models.dart';

enum VaultStatus {
  /// 启动中：还没判断出有没有库。
  loading,

  /// 本机没有保险库，显示创建页。
  missing,

  /// 有库但未解锁。
  locked,

  /// 已解锁。
  unlocked,
}

/// 用户可见的错误。UI 负责翻译成文案，Controller 只给原因码。
enum KeyCaseError {
  passwordTooShort,
  passwordMismatch,
  passwordIncorrect,
  vaultCorrupted,
  vaultLocked,
  vaultNotReadable,
  saveFailed,
  backupFailed,
  backupUnreadable,
  backupWrongPassword,
  biometricUnavailable,
  biometricFailed,
  biometricEnrolledMissing,
  importFailed,
  deleteFailed,
}

/// 一次性成功提示，同样交给 UI 翻译。
enum KeyCaseNotice {
  vaultCreated,
  itemSaved,
  itemDeleted,
  itemRestored,
  itemPurged,
  trashEmptied,
  passwordChanged,
  backupExported,
  backupImported,
  snapshotSaved,
  favoriteUpdated,
  biometricEnabled,
  biometricDisabled,
}

class KeyCaseState {
  const KeyCaseState({
    this.status = VaultStatus.loading,
    this.data,
    this.busy = false,
    this.error,
    this.notice,
    this.biometricEnrolled = false,
  });

  final VaultStatus status;
  final VaultData? data;

  /// 有耗时操作在进行（解锁、保存、导入）。
  final bool busy;
  final KeyCaseError? error;
  final KeyCaseNotice? notice;

  /// 本机是否已保存可用于生物识别解锁的包裹密钥。
  final bool biometricEnrolled;

  bool get isUnlocked => status == VaultStatus.unlocked && data != null;

  List<VaultItem> get activeItems => data?.activeItems ?? const <VaultItem>[];

  List<VaultItem> get loginItems =>
      activeItems.where((item) => item.kind == ItemKind.login).toList();

  List<VaultItem> get tokenItems =>
      activeItems.where((item) => item.kind == ItemKind.totp).toList();

  List<VaultItem> get trashedItems => data?.trashedItems ?? const <VaultItem>[];

  KeyCaseState copyWith({
    VaultStatus? status,
    VaultData? data,
    bool? busy,
    KeyCaseError? error,
    KeyCaseNotice? notice,
    bool? biometricEnrolled,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return KeyCaseState(
      status: status ?? this.status,
      data: data ?? this.data,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      notice: clearNotice ? null : (notice ?? this.notice),
      biometricEnrolled: biometricEnrolled ?? this.biometricEnrolled,
    );
  }
}
