import 'dart:io';
import 'dart:typed_data';

import 'package:keycase/app/crypto/kdf.dart';
import 'package:keycase/app/data/preferences_store.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/app/platform/biometric_auth.dart';
import 'package:keycase/app/platform/native_bridge.dart';
import 'package:keycase/app/vault/backup_service.dart';
import 'package:keycase/app/vault/vault_container.dart';
import 'package:keycase/app/vault/vault_repository.dart';

UnlockedVault testSession(VaultData data) {
  return UnlockedVault(
    header: VaultHeader(
      formatVersion: VaultContainer.formatVersion,
      vaultId: data.vaultId,
      createdAt: data.createdAt,
      kdf: const KdfParams(memoryKib: 64, iterations: 1, parallelism: 1),
      slots: const <KeySlot>[],
      payloadNonce: Uint8List(12),
    ),
    vaultKey: Uint8List(32),
    data: data,
  );
}

VaultData testVault({
  String vaultId = 'test-vault',
  List<VaultItem> items = const <VaultItem>[],
}) {
  return VaultData(
    vaultId: vaultId,
    createdAt: DateTime.utc(2026, 1, 1),
    items: items,
  );
}

class FakeVaultRepository extends VaultRepository {
  FakeVaultRepository({VaultData? data, this.existsValue = true})
    : data = data ?? testVault();

  VaultData data;
  final bool existsValue;
  UnlockedVault? _session;
  String? password;
  Object? unlockError;
  Object? replaceError;
  Uint8List lastSavedBytes = Uint8List.fromList(<int>[1, 2, 3]);
  int saveCount = 0;
  bool deleted = false;

  @override
  UnlockedVault? get session => _session;

  @override
  Future<bool> exists() async => existsValue;

  @override
  Future<UnlockedVault> create({
    required String password,
    required VaultData data,
  }) async {
    this.password = password;
    this.data = data.copyWith(vaultId: 'test-vault');
    final session = testSession(this.data);
    _session = session;
    return session;
  }

  @override
  Future<UnlockedVault> unlock(String password) async {
    final failure = unlockError;
    if (failure != null) throw failure;
    final expected = this.password;
    if (expected != null && expected != password) {
      throw const VaultFormatException(
        '主密码错误',
        code: VaultErrorCode.wrongPassword,
      );
    }
    final session = testSession(data);
    _session = session;
    return session;
  }

  @override
  Future<UnlockedVault> unlockWithVaultKey(Uint8List vaultKey) async {
    final session = testSession(data);
    _session = session;
    return session;
  }

  @override
  Future<Uint8List> save(VaultData data) async {
    saveCount++;
    this.data = data;
    _session = testSession(data);
    return lastSavedBytes;
  }

  @override
  Future<Uint8List> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    password = newPassword;
    return Uint8List.fromList(<int>[4, 5, 6]);
  }

  @override
  Future<UnlockedVault> replaceWithBackup({
    required Uint8List bytes,
    required String password,
  }) async {
    final failure = replaceError;
    if (failure != null) throw failure;
    this.password = password;
    final session = testSession(data);
    _session = session;
    return session;
  }

  @override
  Future<Uint8List> readBytes() async => lastSavedBytes;

  @override
  Future<VaultHeader?> inspect() async {
    if (!existsValue) return null;
    return testSession(data).header;
  }

  @override
  void lock() {
    _session = null;
  }

  @override
  Future<void> deleteAll() async {
    deleted = true;
    _session = null;
  }
}

class FakePreferencesStore extends PreferencesStore {
  FakePreferencesStore([this.value = const AppPreferences()]);

  AppPreferences value;
  int saveCount = 0;

  @override
  Future<AppPreferences> load() async => value;

  @override
  Future<void> save(AppPreferences preferences) async {
    value = preferences;
    saveCount++;
  }

  @override
  Future<void> clear() async {
    value = const AppPreferences();
  }
}

class FakeNativeBridge extends NativeBridge {
  bool secureScreen = false;
  Uint8List? vaultKey;
  bool storeResult = true;
  bool backupWriteResult = true;
  bool saveResult = true;
  Object? saveError;
  String? savedName;
  Uint8List? savedBytes;
  ({String uri, String name})? folder;
  List<String> backupFiles = <String>[];
  int clearVaultKeyCount = 0;
  final List<String> writtenNames = <String>[];
  final List<String> deletedNames = <String>[];

  @override
  Future<void> setSecureScreen(bool enabled) async {
    secureScreen = enabled;
  }

  @override
  Future<bool> storeVaultKey({
    required Uint8List key,
    required String vaultId,
  }) async {
    if (!storeResult) return false;
    vaultKey = Uint8List.fromList(key);
    return true;
  }

  @override
  Future<Uint8List?> readVaultKey(String vaultId) async => vaultKey;

  @override
  Future<void> clearVaultKey() async {
    clearVaultKeyCount++;
    vaultKey = null;
  }

  @override
  Future<({String uri, String name})?> pickBackupFolder() async => folder;

  @override
  Future<bool> writeBackupFile({
    required String dirUri,
    required String name,
    required Uint8List bytes,
  }) async {
    if (!backupWriteResult) return false;
    writtenNames.add(name);
    backupFiles = <String>[...backupFiles, name]
      ..sort((a, b) => b.compareTo(a));
    return true;
  }

  @override
  Future<bool> saveBackupFile({
    required String name,
    required Uint8List bytes,
  }) async {
    final failure = saveError;
    if (failure != null) throw failure;
    if (!saveResult) return false;
    savedName = name;
    savedBytes = Uint8List.fromList(bytes);
    return true;
  }

  @override
  Future<List<String>> listBackupFiles(String dirUri) async =>
      List<String>.from(backupFiles);

  @override
  Future<bool> deleteBackupFiles({
    required String dirUri,
    required List<String> names,
  }) async {
    deletedNames.addAll(names);
    backupFiles = backupFiles.where((name) => !names.contains(name)).toList();
    return true;
  }
}

class FakeBiometricAuth extends BiometricAuth {
  FakeBiometricAuth({
    this.available = true,
    this.result = BiometricResult.success,
  });

  bool available;
  BiometricResult result;
  int authenticateCalls = 0;
  String? lastReason;
  String? lastCancelLabel;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<BiometricResult> authenticate({
    required String reason,
    String cancelLabel = '取消',
    String title = 'KeyCase',
  }) async {
    authenticateCalls++;
    lastReason = reason;
    lastCancelLabel = cancelLabel;
    return result;
  }
}

class FakeBackupService extends BackupService {
  ({String uri, String name})? folder;
  String? importPath;
  Uint8List? importBytes;
  bool snapshotFails = false;
  String lastSnapshotDir = '';
  int snapshotCount = 0;

  @override
  Future<({String uri, String name})?> pickFolder() async => folder;

  @override
  Future<String> writeSnapshot({
    required String dirUri,
    required Uint8List bytes,
  }) async {
    lastSnapshotDir = dirUri;
    snapshotCount++;
    if (snapshotFails) throw const FileSystemException('无法写入备份目录');
    return 'keycase-test.kcbak';
  }

  @override
  Future<List<String>> listSnapshots(String dirUri) async => const <String>[];

  @override
  Future<String?> exportToUser(Uint8List bytes) async => importPath;

  @override
  Future<Uint8List?> pickImportFile({required String label}) async =>
      importBytes;

  @override
  Future<Uint8List?> pickDocument({
    required String label,
    required List<String> extensions,
  }) async => importBytes;
}
