import '../crypto/base32.dart';
import 'icon_ref.dart';
import 'totp_secret.dart';

/// 条目类型：登录项（账号 + 密码）或动态令牌。
///
/// v2 起两类条目共用公共字段，但各自持有独立的 payload：
/// - 登录项只有 [LoginData]；
/// - 令牌只有 [TokenData]。
/// 这样 `password/urls` 不会出现在令牌上，`totp` 也不会出现在登录项上。
enum ItemKind { login, totp }

/// 登录项专属字段。
class LoginData {
  const LoginData({
    this.username = '',
    this.password = '',
    this.urls = const <String>[],
    this.notes = '',
  });

  final String username;
  final String password;

  /// 已过滤空串、去重，保持顺序。
  final List<String> urls;
  final String notes;

  LoginData copyWith({
    String? username,
    String? password,
    List<String>? urls,
    String? notes,
  }) {
    return LoginData(
      username: username ?? this.username,
      password: password ?? this.password,
      urls: urls ?? this.urls,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'username': username,
    'password': password,
    'urls': urls,
    'notes': notes,
  };

  factory LoginData.fromJson(Map<String, Object?> json) {
    final rawUrls = json['urls'];
    final seen = <String>{};
    final urls = <String>[];
    if (rawUrls is List) {
      for (final raw in rawUrls) {
        if (raw is! String) continue;
        final value = raw.trim();
        if (value.isEmpty) continue;
        if (seen.add(value)) urls.add(value);
      }
    }
    return LoginData(
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      urls: urls,
      notes: json['notes'] as String? ?? '',
    );
  }
}

/// 令牌专属字段。
class TokenData {
  const TokenData({required this.secret, this.account = '', this.notes = ''});

  final TotpSecret secret;

  /// 账号/用户名（v1 的 `username` 迁移到这里）。
  final String account;
  final String notes;

  TokenData copyWith({TotpSecret? secret, String? account, String? notes}) {
    return TokenData(
      secret: secret ?? this.secret,
      account: account ?? this.account,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'type': secret.type.name,
    'secret': secret.secret,
    'algorithm': secret.algorithm.name.toUpperCase(),
    'digits': secret.digits,
    'period': secret.period,
    'counter': secret.counter,
    'account': account,
    'notes': notes,
  };

  factory TokenData.fromJson(Map<String, Object?> json) {
    final secret = (json['secret'] as String? ?? '').trim();
    final normalized = normalizeBase32(secret);
    if (normalized.isEmpty) {
      throw const FormatException('令牌密钥不能为空');
    }
    try {
      base32Decode(normalized);
    } on FormatException {
      throw const FormatException('令牌密钥不是合法的 Base32');
    }

    final type = switch (json['type']) {
      'hotp' => OtpType.hotp,
      'steam' => OtpType.steam,
      _ => OtpType.totp,
    };
    final algorithm = switch ((json['algorithm'] as String? ?? '')
        .toUpperCase()) {
      'SHA256' => OtpHashAlgorithm.sha256,
      'SHA512' => OtpHashAlgorithm.sha512,
      _ => OtpHashAlgorithm.sha1,
    };
    final rawDigits = (json['digits'] as num?)?.toInt() ?? 6;
    final digits = type == OtpType.steam ? 5 : (rawDigits == 8 ? 8 : 6);
    final rawPeriod = (json['period'] as num?)?.toInt() ?? 30;
    final period = type == OtpType.steam
        ? 30
        : (rawPeriod >= 1 && rawPeriod <= 300 ? rawPeriod : 30);
    final counter = (json['counter'] as num?)?.toInt() ?? 0;

    return TokenData(
      secret: TotpSecret(
        type: type,
        secret: normalized,
        algorithm: type == OtpType.steam ? OtpHashAlgorithm.sha1 : algorithm,
        digits: digits,
        period: period,
        counter: counter < 0 ? 0 : counter,
      ),
      account: json['account'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }
}

/// 条目。
///
/// 公共字段平铺，类型专属字段放在 [login] 或 [token] 中；两者互斥。
/// 用 [VaultItem.loginItem] / [VaultItem.tokenItem] 构造，避免出现无效状态。
class VaultItem {
  const VaultItem._({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.favorite = false,
    this.icon,
    this.deletedAt,
    this.login,
    this.token,
  }) : assert(
         (kind == ItemKind.login && login != null && token == null) ||
             (kind == ItemKind.totp && token != null && login == null),
       );

  factory VaultItem.loginItem({
    required String id,
    required String title,
    required DateTime createdAt,
    required DateTime updatedAt,
    LoginData? login,
    bool favorite = false,
    IconRef? icon,
    DateTime? deletedAt,
  }) {
    return VaultItem._(
      id: id,
      kind: ItemKind.login,
      title: title,
      createdAt: createdAt,
      updatedAt: updatedAt,
      login: login ?? const LoginData(),
      favorite: favorite,
      icon: icon,
      deletedAt: deletedAt,
    );
  }

  factory VaultItem.tokenItem({
    required String id,
    required String title,
    required DateTime createdAt,
    required DateTime updatedAt,
    required TokenData token,
    bool favorite = false,
    IconRef? icon,
    DateTime? deletedAt,
  }) {
    return VaultItem._(
      id: id,
      kind: ItemKind.totp,
      title: title,
      createdAt: createdAt,
      updatedAt: updatedAt,
      token: token,
      favorite: favorite,
      icon: icon,
      deletedAt: deletedAt,
    );
  }

  final String id;
  final ItemKind kind;
  final String title;
  final bool favorite;
  final IconRef? icon;
  final DateTime createdAt;
  final DateTime updatedAt;
  final LoginData? login;
  final TokenData? token;

  /// 非 null 表示在回收站；软删除，只有「永久删除」才真正移除。
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
  bool get isToken => kind == ItemKind.totp;

  /// 供页面使用的派生访问器：只为减少 `login?.x ?? token?.x` 的重复。
  String get username => login?.username ?? token?.account ?? '';
  String get password => login?.password ?? '';
  List<String> get urls => login?.urls ?? const <String>[];
  String get notes => login?.notes ?? token?.notes ?? '';
  TotpSecret? get totp => token?.secret;

  /// 列表和详情的主标题：未填标题时退化为账号或服务名，避免空白行。
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    if (username.trim().isNotEmpty) return username.trim();
    return '';
  }

  static const Object _unset = Object();

  VaultItem copyWith({
    String? title,
    bool? favorite,
    Object? icon = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _unset,
  }) {
    return VaultItem._(
      id: id,
      kind: kind,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      favorite: favorite ?? this.favorite,
      icon: identical(icon, _unset) ? this.icon : icon as IconRef?,
      deletedAt: identical(deletedAt, _unset)
          ? this.deletedAt
          : deletedAt as DateTime?,
      login: login,
      token: token,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'kind': kind.name,
    'title': title,
    'favorite': favorite,
    'icon': icon?.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
    if (login != null) 'login': login!.toJson(),
    if (token != null) 'totp': token!.toJson(),
  };

  factory VaultItem.fromJson(Map<String, Object?> json) {
    final id = json['id'] as String? ?? '';
    if (id.isEmpty) {
      throw const FormatException('条目缺少 id');
    }
    final kind = json['kind'];
    final createdAt = _parseDate(json['createdAt']);
    final updatedAt = _parseDate(json['updatedAt']);
    if (createdAt == null || updatedAt == null) {
      throw const FormatException('条目缺少时间戳');
    }
    final title = json['title'] as String? ?? '';
    final favorite = json['favorite'] as bool? ?? false;
    final icon = json['icon'] is Map
        ? IconRef.fromJson((json['icon'] as Map).cast<String, Object?>())
        : null;
    final deletedAt = _parseDate(json['deletedAt']);

    if (kind == 'login') {
      final rawLogin = json['login'];
      if (rawLogin is! Map || json.containsKey('totp')) {
        throw const FormatException('登录项的 payload 不合法');
      }
      return VaultItem.loginItem(
        id: id,
        title: title,
        createdAt: createdAt,
        updatedAt: updatedAt,
        login: LoginData.fromJson(rawLogin.cast<String, Object?>()),
        favorite: favorite,
        icon: icon,
        deletedAt: deletedAt,
      );
    }
    if (kind == 'totp') {
      final rawToken = json['totp'];
      if (rawToken is! Map || json.containsKey('login')) {
        throw const FormatException('令牌的 payload 不合法');
      }
      return VaultItem.tokenItem(
        id: id,
        title: title,
        createdAt: createdAt,
        updatedAt: updatedAt,
        token: TokenData.fromJson(rawToken.cast<String, Object?>()),
        favorite: favorite,
        icon: icon,
        deletedAt: deletedAt,
      );
    }
    throw const FormatException('未知的条目类型');
  }
}

DateTime? _parseDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}
