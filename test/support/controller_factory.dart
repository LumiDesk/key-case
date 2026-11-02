import 'package:keycase/app/keycase_controller.dart';
import 'package:keycase/app/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

({
  KeyCaseController controller,
  FakeVaultRepository vault,
  FakePreferencesStore preferences,
  FakeNativeBridge native,
  FakeBiometricAuth biometrics,
  FakeBackupService backups,
})
makeController({
  AppPreferences preferences = const AppPreferences(),
  List<VaultItem> items = const <VaultItem>[],
  bool exists = true,
}) {
  final vault = FakeVaultRepository(
    data: testVault(items: items),
    existsValue: exists,
  );
  final store = FakePreferencesStore(preferences);
  final native = FakeNativeBridge();
  final biometrics = FakeBiometricAuth();
  final backups = FakeBackupService();
  final controller = KeyCaseController(
    vault: vault,
    preferencesStore: store,
    nativeBridge: native,
    biometrics: biometrics,
    backups: backups,
  );
  addTearDown(controller.dispose);
  return (
    controller: controller,
    vault: vault,
    preferences: store,
    native: native,
    biometrics: biometrics,
    backups: backups,
  );
}
