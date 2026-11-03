import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/data/preferences_store.dart';
import 'package:keycase/app/icons/aegis_icon_pack.dart';
import 'package:keycase/app/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppPreferences', () {
    test('默认开启防截屏与剪贴板清除', () {
      const prefs = AppPreferences();
      expect(prefs.secureScreen, isTrue);
      expect(prefs.clipboardAutoClear, isTrue);

      final restored = AppPreferences.fromJson(<String, Object?>{});
      expect(restored.secureScreen, isTrue);
      expect(restored.clipboardAutoClear, isTrue);
    });

    test('全部字段 JSON 往返', () {
      const original = AppPreferences(
        themeMode: ThemeModePreference.dark,
        colorMode: ThemeColorMode.custom,
        presetIndex: 3,
        customColorValue: 0xFF123456,
        showTokenCodes: false,
        showNextToken: true,
        secureScreen: true,
        clipboardAutoClear: false,
        autoLockSeconds: 60,
        codeGrouping: CodeGrouping.four,
        languageCode: 'en',
        biometricEnabled: true,
        autoSnapshot: true,
        backupTreeUri: 'content://tree',
        backupFolderName: 'Backups',
        lastBackupAt: 123456789,
      );

      final restored = AppPreferences.fromJson(original.toJson());

      expect(restored.themeMode, ThemeModePreference.dark);
      expect(restored.colorMode, ThemeColorMode.custom);
      expect(restored.presetIndex, 3);
      expect(restored.customColorValue, 0xFF123456);
      expect(restored.showTokenCodes, isFalse);
      expect(restored.showNextToken, isTrue);
      expect(restored.secureScreen, isTrue);
      expect(restored.clipboardAutoClear, isFalse);
      expect(restored.autoLockSeconds, 60);
      expect(restored.codeGrouping, CodeGrouping.four);
      expect(restored.languageCode, 'en');
      expect(restored.biometricEnabled, isTrue);
      expect(restored.autoSnapshot, isTrue);
      expect(restored.backupTreeUri, 'content://tree');
      expect(restored.backupFolderName, 'Backups');
      expect(restored.lastBackupAt, 123456789);
    });

    test('未知枚举值回落到默认值', () {
      final restored = AppPreferences.fromJson(<String, Object?>{
        'themeMode': 'unknown',
        'colorMode': 'unknown',
        'codeGrouping': 'unknown',
        'presetIndex': null,
      });

      expect(restored.themeMode, ThemeModePreference.system);
      expect(restored.colorMode, ThemeColorMode.preset);
      expect(restored.codeGrouping, CodeGrouping.auto);
      expect(restored.presetIndex, 0);
    });
  });

  group('PreferencesStore', () {
    test('保存后可重新读取，键固定', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = PreferencesStore();
      await store.save(const AppPreferences(languageCode: 'en'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PreferencesStore.storageKey), isNotNull);

      final loaded = await store.load();
      expect(loaded.languageCode, 'en');
    });

    test('损坏 JSON 回落到默认偏好', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesStore.storageKey: '{broken',
      });

      final loaded = await PreferencesStore().load();

      expect(loaded.languageCode, '');
      expect(loaded.showTokenCodes, isTrue);
    });

    test('clear 删除存储键', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesStore.storageKey: jsonEncode(
          const AppPreferences().toJson(),
        ),
      });
      final store = PreferencesStore();

      await store.clear();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(PreferencesStore.storageKey), isFalse);
    });
  });

  group('IconRef', () {
    test('自定义图片 base64 可解码并缓存', () {
      final bytes = base64Encode(<int>[1, 2, 3, 4]);
      final ref = IconRef(
        kind: IconRef.kindCustom,
        name: 'custom',
        data: bytes,
      );

      expect(ref.isCustom, isTrue);
      expect(ref.imageBytes, <int>[1, 2, 3, 4]);
      expect(ref.imageBytes, same(ref.imageBytes));
    });

    test('非法 base64 返回空字节，内置图标的 isBuiltin 为真', () {
      final broken = IconRef(
        kind: IconRef.kindCustom,
        name: 'custom',
        data: 'not-base64!',
      );
      final builtin = IconRef(name: 'github');

      expect(broken.imageBytes, isEmpty);
      expect(builtin.isBuiltin, isTrue);
      expect(builtin.isCustom, isFalse);
      expect(IconRef.fromJson(builtin.toJson()), builtin);
    });

    test('图标匹配规范化去掉大小写与非字母数字', () {
      expect(normalizeIconKey('GitHub Enterprise'), 'githubenterprise');
      expect(normalizeIconKey('  AWS_Console  '), 'awsconsole');
    });
  });

  group('VaultData', () {
    test('activeItems 与 trashedItems 分离', () {
      final now = DateTime.utc(2026, 1, 1);
      final data = VaultData(
        vaultId: 'v',
        createdAt: now,
        items: <VaultItem>[
          VaultItem.loginItem(
            id: 'a',
            title: 'A',
            createdAt: now,
            updatedAt: now,
          ),
          VaultItem.loginItem(
            id: 'b',
            title: 'B',
            createdAt: now,
            updatedAt: now,
            deletedAt: now,
          ),
        ],
      );

      expect(data.activeItems.single.id, 'a');
      expect(data.trashedItems.single.id, 'b');
      expect(data.itemById('b')?.isDeleted, isTrue);
      expect(data.itemById('missing'), isNull);
    });
  });

  group('TotpSecret JSON', () {
    test('未知类型与算法回落到默认值，密钥统一大写', () {
      final secret = TotpSecret.fromJson(<String, Object?>{
        'type': 'unknown',
        'algorithm': 'sha999',
        'secret': 'jbswy3dp ehpk3pxp',
        'digits': 8,
        'period': 60,
      });

      expect(secret.type, OtpType.totp);
      expect(secret.algorithm, OtpHashAlgorithm.sha1);
      expect(secret.secret, 'JBSWY3DPEHPK3PXP');
      expect(secret.digits, 8);
      expect(secret.period, 60);
    });
  });

  group('v2 VaultItem', () {
    final now = DateTime.utc(2026, 1, 1);

    test('登录项往返保留多 URL、备注与图标', () {
      final original = VaultItem.loginItem(
        id: 'login',
        title: 'GitHub',
        login: const LoginData(
          username: 'alice',
          password: 'secret',
          urls: <String>['https://github.com', 'https://gist.github.com'],
          notes: 'note',
        ),
        favorite: true,
        icon: const IconRef(name: 'GitHub'),
        createdAt: now,
        updatedAt: now,
      );

      final restored = VaultItem.fromJson(original.toJson());
      expect(restored.kind, ItemKind.login);
      expect(restored.login?.username, 'alice');
      expect(restored.urls, <String>[
        'https://github.com',
        'https://gist.github.com',
      ]);
      expect(restored.token, isNull);
      expect(restored.icon?.name, 'GitHub');
      expect(restored.favorite, isTrue);
    });

    test('令牌往返保留 account/notes，Steam 参数归一化', () {
      final original = VaultItem.tokenItem(
        id: 'token',
        title: 'Steam',
        token: const TokenData(
          secret: TotpSecret(
            type: OtpType.steam,
            secret: 'MZXW6YTBOI',
            digits: 8,
            period: 60,
          ),
          account: 'alice',
          notes: 'steam note',
        ),
        createdAt: now,
        updatedAt: now,
      );

      final restored = VaultItem.fromJson(original.toJson());
      expect(restored.kind, ItemKind.totp);
      expect(restored.login, isNull);
      expect(restored.totp?.type, OtpType.steam);
      expect(restored.totp?.digits, 5);
      expect(restored.totp?.period, 30);
      expect(restored.totp?.algorithm, OtpHashAlgorithm.sha1);
      expect(restored.username, 'alice');
      expect(restored.notes, 'steam note');
    });

    test('登录项带 totp 或令牌带 login 都拒绝', () {
      final login = VaultItem.loginItem(
        id: 'login',
        title: 'L',
        createdAt: now,
        updatedAt: now,
      ).toJson()..['totp'] = <String, Object?>{};
      expect(() => VaultItem.fromJson(login), throwsFormatException);

      final token = VaultItem.tokenItem(
        id: 'token',
        title: 'T',
        token: const TokenData(secret: TotpSecret(secret: 'JBSWY3DPEHPK3PXP')),
        createdAt: now,
        updatedAt: now,
      ).toJson()..['login'] = <String, Object?>{};
      expect(() => VaultItem.fromJson(token), throwsFormatException);
    });

    test('VaultData 拒绝 v1 schema', () {
      expect(
        () => VaultData.fromJson(<String, Object?>{
          'schemaVersion': 1,
          'vaultId': 'v',
          'createdAt': now.toIso8601String(),
          'items': <Object?>[],
        }),
        throwsFormatException,
      );
    });
  });
}
