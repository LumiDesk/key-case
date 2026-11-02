/// TOTP / HOTP / Steam 的动态令牌参数。
///
/// secret 一律以 Base32 大写字符串保存（与 otpauth 一致），不保存原始字节：
/// 导出、二维码、Aegis 互导都以它为准，避免多处编码转换。
library;

/// 令牌类型。Steam 使用 5 位字母表与 30 秒周期，但算法仍是 HMAC-SHA1。
enum OtpType { totp, hotp, steam }

/// 令牌哈希算法。otpauth 里写作 SHA1 / SHA256 / SHA512。
enum OtpHashAlgorithm { sha1, sha256, sha512 }

class TotpSecret {
  const TotpSecret({
    this.type = OtpType.totp,
    required this.secret,
    this.algorithm = OtpHashAlgorithm.sha1,
    this.digits = 6,
    this.period = 30,
    this.counter = 0,
  });

  final OtpType type;

  /// Base32（RFC 4648），不含空格与填充符，统一大写。
  final String secret;
  final OtpHashAlgorithm algorithm;
  final int digits;
  final int period;

  /// 仅 HOTP 使用：已消费的计数器值，每次「下一个」后 +1 落库。
  final int counter;

  bool get isCounterBased => type == OtpType.hotp;

  /// Steam 固定 5 位字母，其余按 digits 取 6/8 位。
  int get effectiveDigits => type == OtpType.steam ? 5 : digits;

  TotpSecret copyWith({
    OtpType? type,
    String? secret,
    OtpHashAlgorithm? algorithm,
    int? digits,
    int? period,
    int? counter,
  }) {
    return TotpSecret(
      type: type ?? this.type,
      secret: secret ?? this.secret,
      algorithm: algorithm ?? this.algorithm,
      digits: digits ?? this.digits,
      period: period ?? this.period,
      counter: counter ?? this.counter,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type.name,
    'secret': secret,
    'algorithm': algorithm.name.toUpperCase(),
    'digits': digits,
    'period': period,
    'counter': counter,
  };

  factory TotpSecret.fromJson(Map<String, Object?> json) {
    return TotpSecret(
      type: _otpTypeFrom(json['type']),
      secret: (json['secret'] as String? ?? '').toUpperCase().replaceAll(
        ' ',
        '',
      ),
      algorithm: _algorithmFrom(json['algorithm']),
      digits: (json['digits'] as num?)?.toInt() ?? 6,
      period: (json['period'] as num?)?.toInt() ?? 30,
      counter: (json['counter'] as num?)?.toInt() ?? 0,
    );
  }

  static OtpType _otpTypeFrom(Object? value) {
    return switch (value) {
      'hotp' => OtpType.hotp,
      'steam' => OtpType.steam,
      _ => OtpType.totp,
    };
  }

  static OtpHashAlgorithm _algorithmFrom(Object? value) {
    return switch ((value as String? ?? '').toUpperCase()) {
      'SHA256' => OtpHashAlgorithm.sha256,
      'SHA512' => OtpHashAlgorithm.sha512,
      _ => OtpHashAlgorithm.sha1,
    };
  }
}
