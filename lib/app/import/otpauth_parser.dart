import '../models/models.dart';

/// otpauth URI 解析结果。
class OtpauthPayload {
  const OtpauthPayload({
    required this.type,
    required this.secret,
    this.issuer = '',
    this.account = '',
    this.algorithm = OtpHashAlgorithm.sha1,
    this.digits = 6,
    this.period = 30,
    this.counter = 0,
  });

  final OtpType type;
  final String secret;
  final String issuer;
  final String account;
  final OtpHashAlgorithm algorithm;
  final int digits;
  final int period;
  final int counter;

  String get displayTitle =>
      issuer.trim().isNotEmpty ? issuer.trim() : account.trim();

  TotpSecret toSecret() => TotpSecret(
    type: type,
    secret: secret,
    algorithm: algorithm,
    digits: digits,
    period: period,
    counter: counter,
  );

  VaultItem toItem(DateTime now) => VaultItem.tokenItem(
    id: now.microsecondsSinceEpoch.toString(),
    title: displayTitle,
    token: TokenData(secret: toSecret(), account: account.trim()),
    createdAt: now,
    updatedAt: now,
  );
}

/// 解析 `otpauth://totp/Issuer:account?secret=...`。
///
/// 容错范围：大小写、URL 编码、缺 issuer（从 label 前缀取）、
/// 数字与周期越界时回退默认值。密钥非法（不是 Base32）返回 null。
OtpauthPayload? parseOtpauthUri(String raw) {
  final Uri uri;
  try {
    uri = Uri.parse(raw.trim());
  } on FormatException {
    return null;
  }
  if (uri.scheme.toLowerCase() != 'otpauth') return null;

  final hostType = switch (uri.host.toLowerCase()) {
    'hotp' => OtpType.hotp,
    'totp' => OtpType.totp,
    'steam' => OtpType.steam,
    _ => null,
  };
  final params = uri.queryParameters;
  final isSteam =
      hostType == OtpType.steam ||
      (params['encoder'] ?? '').toLowerCase() == 'steam' ||
      (params['issuer'] ?? '').toLowerCase() == 'steam';
  final type = isSteam ? OtpType.steam : hostType;
  if (type == null) return null;
  final secret = (params['secret'] ?? '').toUpperCase().replaceAll(' ', '');
  if (secret.isEmpty) return null;
  if (!RegExp(r'^[A-Z2-7]+=*$').hasMatch(secret)) return null;

  final label = Uri.decodeComponent(
    uri.path.startsWith('/') ? uri.path.substring(1) : uri.path,
  );
  var issuer = (params['issuer'] ?? '').trim();
  var account = label.trim();
  final separator = label.indexOf(':');
  if (separator > 0) {
    if (issuer.isEmpty) issuer = label.substring(0, separator).trim();
    account = label.substring(separator + 1).trim();
  }

  final algorithm = type == OtpType.steam
      ? OtpHashAlgorithm.sha1
      : switch ((params['algorithm'] ?? 'SHA1').toUpperCase()) {
          'SHA256' => OtpHashAlgorithm.sha256,
          'SHA512' => OtpHashAlgorithm.sha512,
          _ => OtpHashAlgorithm.sha1,
        };
  final rawDigits = int.tryParse(params['digits'] ?? '');
  final digits = type == OtpType.steam ? 5 : (rawDigits == 8 ? 8 : 6);
  final rawPeriod = int.tryParse(params['period'] ?? '');
  final period = type == OtpType.steam
      ? 30
      : (rawPeriod != null && rawPeriod >= 1 && rawPeriod <= 300
            ? rawPeriod
            : 30);
  final counter = int.tryParse(params['counter'] ?? '') ?? 0;

  return OtpauthPayload(
    type: type,
    secret: secret,
    issuer: issuer,
    account: account,
    algorithm: algorithm,
    digits: digits,
    period: period,
    counter: counter < 0 ? 0 : counter,
  );
}

/// 生成 otpauth URI（导出/分享用）。
String buildOtpauthUri(
  TotpSecret secret, {
  String issuer = '',
  String account = '',
}) {
  final label = issuer.isEmpty
      ? Uri.encodeComponent(account)
      : '${Uri.encodeComponent(issuer)}:${Uri.encodeComponent(account)}';
  final type = secret.type == OtpType.hotp ? 'hotp' : 'totp';
  final params = <String, String>{
    'secret': secret.secret,
    'algorithm': secret.algorithm.name.toUpperCase(),
    'digits': '${secret.digits}',
    'period': '${secret.period}',
    if (secret.type == OtpType.hotp) 'counter': '${secret.counter}',
    if (issuer.isNotEmpty) 'issuer': issuer,
    if (secret.type == OtpType.steam) 'encoder': 'steam',
  };
  final query = params.entries
      .map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}')
      .join('&');
  return 'otpauth://$type/$label?$query';
}
