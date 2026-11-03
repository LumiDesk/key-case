import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/keycase_controller.dart';
import 'package:keycase/app/keycase_state.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/app/platform/biometric_auth.dart';
import 'package:keycase/app/vault/vault_container.dart';

import 'support/controller_factory.dart';
import 'support/fakes.dart';
import 'support/hosts.dart';

void main() {
  group('启动与解锁', () {
    test('没有库时进入创建状态', () async {
      final test = makeController(exists: false);

      await test.controller.bootstrap();

      expect(test.controller.state.status, VaultStatus.missing);
      expect(test.controller.state.data, isNull);
    });

    test('有库时进入锁定状态并读取生物识别登记', () async {
      final test = makeController(
        preferences: const AppPreferences(
          biometricEnabled: true,
          secureScreen: true,
        ),
      );

      await test.controller.bootstrap();

      expect(test.controller.state.status, VaultStatus.locked);
      expect(test.controller.state.biometricEnrolled, isTrue);
      expect(test.native.secureScreen, isTrue);
    });

    test('创建库校验密码长度与一致性', () async {
      final test = makeController(exists: false);
      await test.controller.bootstrap();

      expect(
        await test.controller.createVault(password: 'short', confirm: 'short'),
        isFalse,
      );
      expect(test.controller.state.error, KeyCaseError.passwordTooShort);

      expect(
        await test.controller.createVault(
          password: 'long-enough-password',
          confirm: 'different-password',
        ),
        isFalse,
      );
      expect(test.controller.state.error, KeyCaseError.passwordMismatch);
    });

    test('创建成功后进入已解锁状态', () async {
      final test = makeController(exists: false);
      await test.controller.bootstrap();

      final ok = await test.controller.createVault(
        password: 'master-password',
        confirm: 'master-password',
      );

      expect(ok, isTrue);
      expect(test.controller.state.status, VaultStatus.unlocked);
      expect(test.controller.state.notice, KeyCaseNotice.vaultCreated);
    });

    test('解锁成功、错误口令与空口令分别处理', () async {
      final test = makeController();
      await test.controller.bootstrap();
      test.vault.password = 'master-password';

      expect(await test.controller.unlock(''), isFalse);
      expect(test.controller.state.error, KeyCaseError.passwordIncorrect);

      expect(await test.controller.unlock('wrong'), isFalse);
      expect(test.controller.state.error, KeyCaseError.passwordIncorrect);

      expect(await test.controller.unlock('master-password'), isTrue);
      expect(test.controller.state.isUnlocked, isTrue);
    });

    test('锁定时清空内存数据', () async {
      final test = makeController(items: <VaultItem>[testLogin()]);
      await test.controller.bootstrap();
      await test.controller.unlock('pw');

      test.controller.lock();

      expect(test.controller.state.status, VaultStatus.locked);
      expect(test.controller.state.data, isNull);
      expect(test.vault.session, isNull);
    });

    test('偏好读取失败时进入可恢复的锁定状态', () async {
      final controller = KeyCaseController(
        vault: FakeVaultRepository(),
        preferencesStore: _FailingPreferencesStore(),
        nativeBridge: FakeNativeBridge(),
        biometrics: FakeBiometricAuth(),
        backups: FakeBackupService(),
      );

      await controller.bootstrap();

      expect(controller.state.status, VaultStatus.locked);
      expect(controller.state.error, KeyCaseError.vaultNotReadable);
      controller.dispose();
    });
  });

  group('自动锁定', () {
    test('立即锁定策略在进入后台时锁定', () async {
      final test = makeController();
      await test.controller.bootstrap();
      await test.controller.unlock('pw');

      test.controller.handleAppPaused();

      expect(test.controller.state.status, VaultStatus.locked);
    });

    test('从不锁定策略保持解锁', () async {
      final test = makeController(
        preferences: const AppPreferences(autoLockSeconds: -1),
      );
      await test.controller.bootstrap();
      await test.controller.unlock('pw');

      test.controller.handleAppPaused();
      test.controller.handleAppResumed();

      expect(test.controller.state.isUnlocked, isTrue);
    });

    test('打开系统外部界面期间不触发自动锁定', () async {
      final test = makeController();
      await test.controller.bootstrap();
      await test.controller.unlock('pw');
      test.controller.beginExternalActivity();

      test.controller.handleAppPaused();
      test.controller.handleAppResumed();

      expect(test.controller.state.isUnlocked, isTrue);
    });
  });

  group('条目操作', () {
    test('新增、更新、收藏、删除、恢复、永久删除与清空回收站', () async {
      final test = makeController();
      await test.controller.bootstrap();
      await test.controller.unlock('pw');

      await test.controller.saveItem(testLogin());
      expect(test.controller.state.activeItems, hasLength(1));
      expect(test.controller.state.notice, KeyCaseNotice.itemSaved);

      await test.controller.saveItem(testLogin(title: 'GitHub Updated'));
      expect(test.controller.state.activeItems.single.title, 'GitHub Updated');

      await test.controller.toggleFavorite('login-1');
      expect(test.controller.state.activeItems.single.favorite, isTrue);

      await test.controller.deleteItem('login-1');
      expect(test.controller.state.activeItems, isEmpty);
      expect(test.controller.state.trashedItems, hasLength(1));

      await test.controller.restoreItem('login-1');
      expect(test.controller.state.activeItems, hasLength(1));

      await test.controller.deleteItem('login-1');
      await test.controller.purgeItem('login-1');
      expect(test.controller.state.activeItems, isEmpty);
      expect(test.controller.state.trashedItems, isEmpty);

      await test.controller.saveItem(testLogin());
      await test.controller.deleteItem('login-1');
      await test.controller.emptyTrash();
      expect(test.controller.state.activeItems, isEmpty);
      expect(test.controller.state.trashedItems, isEmpty);
    });

    test('HOTP 计数器递增并落库', () async {
      final test = makeController();
      await test.controller.bootstrap();
      await test.controller.unlock('pw');
      await test.controller.saveItem(testToken(type: OtpType.hotp, counter: 3));

      await test.controller.advanceHotp('token-1');

      expect(test.controller.state.activeItems.single.totp?.counter, 4);
      expect(test.vault.saveCount, 2);
    });
  });

  group('主密码与偏好', () {
    test('修改主密码校验长度、一致性并成功', () async {
      final test = makeController();
      await test.controller.bootstrap();
      await test.controller.unlock('pw');

      expect(
        await test.controller.changeMasterPassword(
          currentPassword: 'pw',
          newPassword: 'short',
          confirmPassword: 'short',
        ),
        isFalse,
      );
      expect(test.controller.state.error, KeyCaseError.passwordTooShort);

      expect(
        await test.controller.changeMasterPassword(
          currentPassword: 'pw',
          newPassword: 'new-password',
          confirmPassword: 'different',
        ),
        isFalse,
      );
      expect(test.controller.state.error, KeyCaseError.passwordMismatch);

      expect(
        await test.controller.changeMasterPassword(
          currentPassword: 'pw',
          newPassword: 'new-password',
          confirmPassword: 'new-password',
        ),
        isTrue,
      );
      expect(test.controller.state.notice, KeyCaseNotice.passwordChanged);
      expect(test.vault.password, 'new-password');
    });

    test('偏好保存并同步截屏保护设置', () async {
      final test = makeController();
      await test.controller.bootstrap();
      await test.controller.unlock('pw');

      await test.controller.updatePreferences(
        const AppPreferences(secureScreen: true, autoLockSeconds: 60),
      );

      expect(test.preferences.value.secureScreen, isTrue);
      expect(test.preferences.value.autoLockSeconds, 60);
      expect(test.native.secureScreen, isTrue);
    });
  });

  group('生物识别', () {
    test('启用后把 vault key 交给原生并写入偏好', () async {
      final test = makeController();
      await test.controller.bootstrap();
      await test.controller.unlock('pw');
      test.biometrics.result = BiometricResult.success;

      final ok = await test.controller.enableBiometrics(
        reason: 'enable',
        cancelLabel: 'Cancel',
      );

      expect(ok, isTrue);
      expect(test.controller.state.biometricEnrolled, isTrue);
      expect(test.native.vaultKey, isNotNull);
      expect(test.preferences.value.biometricEnabled, isTrue);
      expect(test.biometrics.lastCancelLabel, 'Cancel');
    });

    test('设备不支持时拒绝启用且不写偏好', () async {
      final test = makeController();
      await test.controller.bootstrap();
      await test.controller.unlock('pw');
      test.biometrics.available = false;

      final ok = await test.controller.enableBiometrics(reason: 'enable');

      expect(ok, isFalse);
      expect(test.controller.state.error, KeyCaseError.biometricUnavailable);
      expect(test.controller.state.biometricEnrolled, isFalse);
      expect(test.preferences.value.biometricEnabled, isFalse);
      expect(test.native.vaultKey, isNull);
    });

    test('用户取消时静默回退且不显示错误', () async {
      final test = makeController(
        preferences: const AppPreferences(biometricEnabled: true),
      );
      await test.controller.bootstrap();
      test.biometrics.result = BiometricResult.canceled;

      final ok = await test.controller.unlockWithBiometrics(reason: 'unlock');

      expect(ok, isFalse);
      expect(test.controller.state.error, isNull);
      expect(test.controller.state.busy, isFalse);
      expect(test.biometrics.authenticateCalls, 1);
    });

    test('Keystore 密钥丢失时解除登记并报错', () async {
      final test = makeController(
        preferences: const AppPreferences(biometricEnabled: true),
      );
      await test.controller.bootstrap();
      test.native.vaultKey = null;

      final ok = await test.controller.unlockWithBiometrics(reason: 'unlock');

      expect(ok, isFalse);
      expect(
        test.controller.state.error,
        KeyCaseError.biometricEnrolledMissing,
      );
      expect(test.controller.state.biometricEnrolled, isFalse);
      expect(test.preferences.value.biometricEnabled, isFalse);
    });

    test('关闭生物识别会清除原生包裹密钥', () async {
      final test = makeController(
        preferences: const AppPreferences(biometricEnabled: true),
      );
      await test.controller.bootstrap();
      test.native.vaultKey = Uint8List(32);

      await test.controller.disableBiometrics();

      expect(test.native.vaultKey, isNull);
      expect(test.controller.state.biometricEnrolled, isFalse);
      expect(test.preferences.value.biometricEnabled, isFalse);
    });
  });

  group('备份与导入', () {
    test('导出、导入错误口令与成功替换', () async {
      final test = makeController();
      await test.controller.bootstrap();
      await test.controller.unlock('pw');
      test.backups.importPath = '/tmp/keycase.kcbak';

      expect(await test.controller.exportBackup(), isTrue);
      expect(test.controller.state.notice, KeyCaseNotice.backupExported);

      test.vault.replaceError = const VaultFormatException(
        'wrong',
        code: VaultErrorCode.wrongPassword,
      );
      expect(
        await test.controller.importBackup(
          bytes: Uint8List(1),
          password: 'wrong',
        ),
        isFalse,
      );
      expect(test.controller.state.error, KeyCaseError.backupWrongPassword);

      test.vault.replaceError = null;
      expect(
        await test.controller.importBackup(bytes: Uint8List(1), password: 'pw'),
        isTrue,
      );
      expect(test.controller.state.notice, KeyCaseNotice.backupImported);
      expect(test.native.clearVaultKeyCount, 1);
      expect(test.preferences.value.biometricEnabled, isFalse);
    });

    test('选择备份目录会打开自动快照', () async {
      final test = makeController();
      await test.controller.bootstrap();
      await test.controller.unlock('pw');
      test.backups.folder = (uri: 'content://backup', name: 'Backups');

      expect(await test.controller.pickBackupFolder(), isTrue);
      expect(test.preferences.value.autoSnapshot, isTrue);
      expect(test.preferences.value.backupTreeUri, 'content://backup');
    });

    test('立即备份与删除保险库', () async {
      final test = makeController();
      await test.controller.bootstrap();
      await test.controller.unlock('pw');
      await test.controller.updatePreferences(
        const AppPreferences(backupTreeUri: 'content://backup'),
      );

      expect(await test.controller.backupNow(), isTrue);
      expect(test.controller.state.notice, KeyCaseNotice.snapshotSaved);

      await test.controller.deleteVault();
      expect(test.vault.deleted, isTrue);
      expect(test.controller.state.status, VaultStatus.missing);
    });

    test('导入 Aegis 明文导出并合并', () async {
      final test = makeController();
      await test.controller.bootstrap();
      await test.controller.unlock('pw');
      test.backups.importBytes = Uint8List.fromList(
        utf8.encode(
          jsonEncode(<String, Object?>{
            'version': 1,
            'header': <String, Object?>{'slots': null, 'params': null},
            'db': <String, Object?>{'entries': <Object?>[]},
          }),
        ),
      );

      final ok = await test.controller.importAegisBytes(
        bytes: test.backups.importBytes!,
      );

      expect(ok, isTrue);
      expect(test.controller.state.notice, KeyCaseNotice.imported);
    });

    test('收藏不触发自动快照，内容修改才触发', () async {
      final test = makeController(
        preferences: const AppPreferences(
          autoSnapshot: true,
          backupTreeUri: 'content://backup',
        ),
      );
      await test.controller.bootstrap();
      await test.controller.unlock('pw');

      await test.controller.saveItem(testLogin(id: 'new', title: 'New'));
      expect(test.backups.snapshotCount, 1);

      await test.controller.toggleFavorite('login-1');
      expect(test.backups.snapshotCount, 1);
    });
  });

  group('并发与锁定', () {
    test('连续两次收藏最终回到未收藏', () async {
      final harness = _gatedHarness();
      await harness.controller.bootstrap();
      await harness.controller.unlock('pw');
      harness.vault.block = true;

      final first = harness.controller.toggleFavorite('login-1');
      final second = harness.controller.toggleFavorite('login-1');
      harness.vault.gate.complete();
      await Future.wait(<Future<void>>[first, second]);

      final item = harness.controller.state.data!.itemById('login-1')!;
      expect(item.favorite, isFalse);
      harness.controller.dispose();
    });

    test('连续两次 HOTP 计数器加二', () async {
      final harness = _gatedHarness(
        items: <VaultItem>[testToken(type: OtpType.hotp, counter: 0)],
      );
      await harness.controller.bootstrap();
      await harness.controller.unlock('pw');
      harness.vault.block = true;

      final first = harness.controller.advanceHotp('token-1');
      final second = harness.controller.advanceHotp('token-1');
      harness.vault.gate.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(
        harness.controller.state.data!.itemById('token-1')!.totp!.counter,
        2,
      );
      harness.controller.dispose();
    });

    test('保存中锁定后不把明文写回状态', () async {
      final harness = _gatedHarness();
      await harness.controller.bootstrap();
      await harness.controller.unlock('pw');
      harness.vault.block = true;

      final saving = harness.controller.saveItem(
        testLogin(id: 'new', title: 'Saving'),
      );
      await Future<void>.delayed(Duration.zero);
      harness.controller.lock();
      harness.vault.gate.complete();
      await saving;

      expect(harness.controller.state.status, VaultStatus.locked);
      expect(harness.controller.state.data, isNull);
      harness.controller.dispose();
    });
  });
}

({KeyCaseController controller, _GatedVault vault}) _gatedHarness({
  List<VaultItem>? items,
}) {
  final vault = _GatedVault(
    data: testVault(items: items ?? <VaultItem>[testLogin()]),
  );
  final controller = KeyCaseController(
    vault: vault,
    preferencesStore: FakePreferencesStore(),
    nativeBridge: FakeNativeBridge(),
    biometrics: FakeBiometricAuth(),
    backups: FakeBackupService(),
  );
  return (controller: controller, vault: vault);
}

class _GatedVault extends FakeVaultRepository {
  _GatedVault({required super.data});

  final Completer<void> gate = Completer<void>();
  bool block = false;

  @override
  Future<Uint8List> save(VaultData data) async {
    if (block) await gate.future;
    return super.save(data);
  }
}

class _FailingPreferencesStore extends FakePreferencesStore {
  @override
  Future<AppPreferences> load() async {
    throw StateError('preferences unavailable');
  }
}
