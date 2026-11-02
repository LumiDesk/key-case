import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/app/vault/vault_container.dart';
import 'package:keycase/app/vault/vault_migrations.dart';

void main() {
  group('VaultMigrations', () {
    test('当前版本正常解析', () {
      final data = VaultMigrations.decode(<String, Object?>{
        'schemaVersion': VaultData.currentSchemaVersion,
        'vaultId': 'vault',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'items': <Object?>[],
      });

      expect(data.vaultId, 'vault');
      expect(data.items, isEmpty);
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
}
