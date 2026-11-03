import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/app/vault/vault_container.dart';
import 'package:keycase/app/vault/vault_migrations.dart';

void main() {
  group('VaultMigrations', () {
    test('当前版本正常解析', () {
      final decoded = VaultMigrations.decode(<String, Object?>{
        'schemaVersion': VaultData.currentSchemaVersion,
        'vaultId': 'vault',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'items': <Object?>[],
      });

      expect(decoded.data.vaultId, 'vault');
      expect(decoded.data.items, isEmpty);
      expect(decoded.migration, isNull);
    });

    test('拒绝未来版本', () {
      expect(
        () => VaultMigrations.decode(<String, Object?>{
          'schemaVersion': VaultData.currentSchemaVersion + 1,
          'vaultId': 'vault',
          'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          'items': <Object?>[],
        }),
        throwsA(isA<VaultFormatException>()),
      );
    });

    test('拒绝非法版本', () {
      expect(
        () => VaultMigrations.decode(<String, Object?>{
          'schemaVersion': 0,
          'vaultId': 'vault',
          'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          'items': <Object?>[],
        }),
        throwsA(isA<VaultFormatException>()),
      );
    });
  });

  group('v1 -> v2', () {
    Map<String, Object?> v1Item({
      required String id,
      required String kind,
      String title = 'GitHub',
      String username = 'alice',
      String password = '',
      List<String> urls = const <String>[],
      String notes = '',
      Map<String, Object?>? totp,
      DateTime? deletedAt,
    }) {
      return <String, Object?>{
        'id': id,
        'kind': kind,
        'title': title,
        'username': username,
        'password': password,
        'urls': urls,
        'notes': notes,
        'totp': totp,
        'favorite': true,
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 1, 2).toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
      };
    }

    Map<String, Object?> v1Vault(List<Object?> items) => <String, Object?>{
      'schemaVersion': 1,
      'vaultId': 'vault',
      'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      'items': items,
    };

    test('登录项与令牌分别进入 payload', () {
      final decoded = VaultMigrations.decode(
        v1Vault(<Object?>[
          v1Item(
            id: 'login',
            kind: 'login',
            password: 'p@ss',
            urls: const <String>['https://github.com', ' https://github.com '],
            notes: 'login note',
          ),
          v1Item(
            id: 'token',
            kind: 'totp',
            username: 'alice@example.com',
            notes: 'token note',
            totp: <String, Object?>{
              'type': 'steam',
              'secret': 'mzxw6ytboi',
              'algorithm': 'SHA256',
              'digits': 8,
              'period': 60,
              'counter': 2,
            },
          ),
        ]),
      );

      expect(decoded.migration, isNotNull);
      expect(decoded.migration!.total, 2);
      expect(decoded.migration!.migrated, 2);
      expect(decoded.data.items, hasLength(2));
      final login = decoded.data.items[0];
      expect(login.login, isNotNull);
      expect(login.token, isNull);
      expect(login.password, 'p@ss');
      expect(login.urls, <String>['https://github.com']);
      expect(login.notes, 'login note');

      final token = decoded.data.items[1];
      expect(token.token, isNotNull);
      expect(token.login, isNull);
      expect(token.totp!.type, OtpType.steam);
      expect(token.totp!.secret, 'MZXW6YTBOI');
      expect(token.totp!.algorithm, OtpHashAlgorithm.sha1);
      expect(token.totp!.digits, 5);
      expect(token.totp!.period, 30);
      expect(token.username, 'alice@example.com');
      expect(token.notes, 'token note');
    });

    test('空密钥令牌被跳过，登录项丢弃 totp 并记录修复', () {
      final decoded = VaultMigrations.decode(
        v1Vault(<Object?>[
          v1Item(
            id: 'login',
            kind: 'login',
            totp: <String, Object?>{'secret': 'JBSWY3DPEHPK3PXP'},
          ),
          v1Item(
            id: 'broken',
            kind: 'totp',
            totp: <String, Object?>{'type': 'totp', 'secret': ''},
          ),
        ]),
      );

      expect(decoded.data.items, hasLength(1));
      expect(decoded.migration!.skipped, 1);
      expect(decoded.migration!.repaired, 1);
      expect(decoded.migration!.warnings, contains('login-totp-dropped'));
      expect(decoded.migration!.warnings, contains('token-invalid-secret'));
    });

    test('重复 id 重新生成且仍保持唯一', () {
      final decoded = VaultMigrations.decode(
        v1Vault(<Object?>[
          v1Item(id: 'same', kind: 'login'),
          v1Item(id: 'same', kind: 'login'),
        ]),
      );

      final ids = decoded.data.items.map((item) => item.id).toList();
      expect(ids.toSet(), hasLength(2));
      expect(decoded.migration!.warnings, contains('item-id-regenerated'));
    });
  });
}
