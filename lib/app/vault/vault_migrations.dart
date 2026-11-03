import '../models/models.dart';
import 'vault_container.dart';

/// payload 结构版本守卫。
///
/// 当前只接受 [VaultData.currentSchemaVersion]；其他版本由本守卫拒绝。
/// 未来新增结构时在这里追加 N -> N+1，不回改历史段。
class VaultMigrations {
  const VaultMigrations._();

  static VaultData decode(Map<String, Object?> json) {
    final version = (json['schemaVersion'] as num?)?.toInt();
    if (version == null || version < 1) {
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
    if (version < VaultData.currentSchemaVersion) {
      throw const VaultFormatException(
        '该保险库结构版本不受支持',
        code: VaultErrorCode.unsupportedVersion,
      );
    }
    try {
      return VaultData.fromJson(json);
    } on FormatException catch (error) {
      throw VaultFormatException(
        '保险库正文格式不正确：${error.message}',
        code: VaultErrorCode.corrupted,
      );
    }
  }
}
