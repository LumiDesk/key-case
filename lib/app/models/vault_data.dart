import 'vault_item.dart';

/// 解密后的保险库内容。
///
/// 这是唯一会被序列化进加密容器的对象；偏好（主题、自动锁定等）走设备 KV，
/// 不进这里，因此换设备导入备份不会覆盖当前设备的显示偏好。
class VaultData {
  const VaultData({
    this.schemaVersion = currentSchemaVersion,
    required this.vaultId,
    required this.createdAt,
    this.items = const <VaultItem>[],
  });

  /// payload 结构版本。加字段/改语义时必须 +1，并在 VaultMigrations 里补一段。
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String vaultId;
  final DateTime createdAt;
  final List<VaultItem> items;

  List<VaultItem> get activeItems =>
      items.where((item) => !item.isDeleted).toList(growable: false);

  List<VaultItem> get trashedItems =>
      items.where((item) => item.isDeleted).toList(growable: false);

  VaultItem? itemById(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  VaultData copyWith({
    int? schemaVersion,
    String? vaultId,
    DateTime? createdAt,
    List<VaultItem>? items,
  }) {
    return VaultData(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      vaultId: vaultId ?? this.vaultId,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'vaultId': vaultId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'items': items.map((item) => item.toJson()).toList(),
  };

  factory VaultData.fromJson(Map<String, Object?> json) {
    final rawItems = json['items'];
    return VaultData(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      vaultId: json['vaultId'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map((map) => VaultItem.fromJson(map.cast<String, Object?>()))
                .toList()
          : const <VaultItem>[],
    );
  }
}
