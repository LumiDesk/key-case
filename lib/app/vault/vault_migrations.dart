import '../models/models.dart';
import 'vault_container.dart';

/// payload 结构迁移。
///
/// 规则：
/// - 已发布的迁移段永远不改，只追加「升到 N+1」的新段；
/// - 每次改模型都提升 [VaultData.currentSchemaVersion]，并补一条迁移；
/// - 迁移矩阵测试覆盖「每个历史版本都能升到当前版本」。
///
/// v1 是首个正式版本，因此目前只有恒等迁移。
class VaultMigrations {
  const VaultMigrations._();

  /// 从 vN 升到 vN+1 的函数表，键是源版本。
  static final Map<int, Map<String, Object?> Function(Map<String, Object?>)>
  _steps = <int, Map<String, Object?> Function(Map<String, Object?>)>{
    // 1: (json) => json,   // 1 -> 2 时在这里追加
  };

  static VaultData decode(Map<String, Object?> json) {
    var current = json;
    var version = (json['schemaVersion'] as num?)?.toInt() ?? 1;

    if (version < 1) {
      throw const VaultFormatException('保险库结构版本不合法');
    }
    if (version > VaultData.currentSchemaVersion) {
      throw const VaultFormatException('该保险库由更新版本的 KeyCase 创建，请先升级应用');
    }

    while (version < VaultData.currentSchemaVersion) {
      final step = _steps[version];
      if (step == null) {
        throw VaultFormatException('缺少从 v$version 到 v${version + 1} 的迁移');
      }
      current = step(current);
      version += 1;
      current['schemaVersion'] = version;
    }

    return VaultData.fromJson(current);
  }
}
