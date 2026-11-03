import '../models/models.dart';
import 'vault_container.dart';
import 'vault_migrations_v1.dart';

export 'vault_migrations_v1.dart' show VaultDecoded, VaultMigrationReport;

/// payload 结构迁移。
///
/// bridge 构建支持 v1 → v2；final 构建会删除 v1 分支与本文件中的迁移入口。
/// 规则：只追加新版本，不回改历史。
class VaultMigrations {
  const VaultMigrations._();

  static VaultDecoded decode(Map<String, Object?> json) {
    final version = (json['schemaVersion'] as num?)?.toInt() ?? 1;

    if (version < 1) {
      throw const VaultFormatException(
        '保险库结构版本不合法',
        code: VaultErrorCode.corrupted,
      );
    }
    if (version > VaultData.currentSchemaVersion) {
      throw const VaultFormatException(
        '该保险库由更新版本的 KeyCase 创建，请先升级应用',
        code: VaultErrorCode.unsupportedVersion,
      );
    }
    if (version == 1) {
      return migrateV1Vault(json);
    }
    try {
      return VaultDecoded(data: VaultData.fromJson(json));
    } on FormatException catch (error) {
      throw VaultFormatException(
        '保险库正文格式不正确：${error.message}',
        code: VaultErrorCode.corrupted,
      );
    }
  }
}
