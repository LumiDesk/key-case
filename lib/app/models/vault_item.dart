import 'icon_ref.dart';
import 'totp_secret.dart';

/// 条目类型：登录项（账号 + 密码）或动态令牌。
///
/// 两者共用一个列表与一套详情/编辑骨架，靠 kind 分支；不建两张表，
/// 因为搜索、收藏、回收站、备份都要同时覆盖两类条目。
enum ItemKind { login, totp }

class VaultItem {
  const VaultItem({
    required this.id,
    required this.kind,
    this.title = '',
    this.username = '',
    this.password = '',
    this.urls = const <String>[],
    this.notes = '',
    this.totp,
    this.icon,
    this.favorite = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final ItemKind kind;
  final String title;
  final String username;
  final String password;
  final List<String> urls;
  final String notes;
  final TotpSecret? totp;
  final IconRef? icon;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 非 null 表示在回收站；软删除，只有「永久删除」才真正移除。
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
  bool get isToken => kind == ItemKind.totp;

  /// 列表和详情的主标题：未填标题时退化为账号或服务名，避免空白行。
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    if (username.trim().isNotEmpty) return username.trim();
    return '';
  }

  static const Object _unset = Object();

  VaultItem copyWith({
    String? id,
    ItemKind? kind,
    String? title,
    String? username,
    String? password,
    List<String>? urls,
    String? notes,
    Object? totp = _unset,
    Object? icon = _unset,
    bool? favorite,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _unset,
  }) {
    return VaultItem(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      urls: urls ?? this.urls,
      notes: notes ?? this.notes,
      totp: identical(totp, _unset) ? this.totp : totp as TotpSecret?,
      icon: identical(icon, _unset) ? this.icon : icon as IconRef?,
      favorite: favorite ?? this.favorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: identical(deletedAt, _unset)
          ? this.deletedAt
          : deletedAt as DateTime?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'kind': kind.name,
    'title': title,
    'username': username,
    'password': password,
    'urls': urls,
    'notes': notes,
    'totp': totp?.toJson(),
    'icon': icon?.toJson(),
    'favorite': favorite,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };

  factory VaultItem.fromJson(Map<String, Object?> json) {
    final now = DateTime.now().toUtc();
    final rawUrls = json['urls'];
    return VaultItem(
      id: json['id'] as String? ?? '',
      kind: json['kind'] == 'totp' ? ItemKind.totp : ItemKind.login,
      title: json['title'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      urls: rawUrls is List
          ? rawUrls.whereType<String>().where((e) => e.trim().isNotEmpty).toList()
          : const <String>[],
      notes: json['notes'] as String? ?? '',
      totp: json['totp'] is Map
          ? TotpSecret.fromJson((json['totp'] as Map).cast<String, Object?>())
          : null,
      icon: json['icon'] is Map
          ? IconRef.fromJson((json['icon'] as Map).cast<String, Object?>())
          : null,
      favorite: json['favorite'] as bool? ?? false,
      createdAt: _parseDate(json['createdAt']) ?? now,
      updatedAt: _parseDate(json['updatedAt']) ?? now,
      deletedAt: _parseDate(json['deletedAt']),
    );
  }
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}
