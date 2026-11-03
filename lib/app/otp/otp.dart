/// TOTP / HOTP / Steam 验证码计算（纯函数，无 Flutter 依赖）。
///
/// 与 RFC 6238 / RFC 4226 对齐；测试用官方测试向量校验，
/// 因此这里不做任何「差不多就行」的容错。
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../crypto/base32.dart';
import '../models/models.dart';

const String _steamAlphabet = '23456789BCDFGHJKMNPQRTVWXY';

/// 计数器值对应的验证码。
///
/// [counter] 对 TOTP/Steam 是「时间片 = 秒 / 周期」，对 HOTP 是持久化的计数器。
String generateOtpCode({required TotpSecret secret, required int counter}) {
  final key = base32Decode(secret.secret);
  final hash = _hmac(secret.algorithm, key, counter);
  if (secret.type == OtpType.steam) {
    return _steamFromHash(hash);
  }
  return _truncate(hash, secret.digits);
}

/// 某个时刻的计数器：TOTP 与 Steam 都是 `epochSeconds ~/ period`。
int otpCounterAt(TotpSecret secret, DateTime time) {
  if (secret.type == OtpType.hotp) return secret.counter;
  return time.millisecondsSinceEpoch ~/ 1000 ~/ secret.period;
}

/// 当前时间片剩余秒数（1..period）；HOTP 没有倒计时，返回 0。
int otpSecondsRemaining(TotpSecret secret, DateTime time) {
  if (secret.type == OtpType.hotp) return 0;
  final period = secret.period;
  final seconds = time.millisecondsSinceEpoch ~/ 1000;
  final elapsed = seconds % period;
  return period - elapsed;
}

/// 下一组的验证码（TOTP/Steam）。
String nextOtpCode(TotpSecret secret, DateTime time) =>
    generateOtpCode(secret: secret, counter: otpCounterAt(secret, time) + 1);

Uint8List _hmac(OtpHashAlgorithm algorithm, Uint8List key, int counter) {
  final message = Uint8List(8);
  final view = ByteData.sublistView(message);
  view.setUint32(0, (counter >> 32) & 0xFFFFFFFF);
  view.setUint32(4, counter & 0xFFFFFFFF);
  final mac = switch (algorithm) {
    OtpHashAlgorithm.sha1 => Hmac(sha1, key),
    OtpHashAlgorithm.sha256 => Hmac(sha256, key),
    OtpHashAlgorithm.sha512 => Hmac(sha512, key),
  };
  return Uint8List.fromList(mac.convert(message).bytes);
}

/// RFC 4226 动态截断。
String _truncate(Uint8List hash, int digits) {
  final offset = hash[hash.length - 1] & 0x0F;
  final binary =
      ((hash[offset] & 0x7F) << 24) |
      ((hash[offset + 1] & 0xFF) << 16) |
      ((hash[offset + 2] & 0xFF) << 8) |
      (hash[offset + 3] & 0xFF);
  final modulo = _pow10(digits);
  return (binary % modulo).toString().padLeft(digits, '0');
}

/// Steam Guard：5 位字母，按 26 进制反复取余。
String _steamFromHash(Uint8List hash) {
  final offset = hash[hash.length - 1] & 0x0F;
  var binary =
      ((hash[offset] & 0x7F) << 24) |
      ((hash[offset + 1] & 0xFF) << 16) |
      ((hash[offset + 2] & 0xFF) << 8) |
      (hash[offset + 3] & 0xFF);
  final buffer = StringBuffer();
  for (var i = 0; i < 5; i++) {
    buffer.write(_steamAlphabet[binary % _steamAlphabet.length]);
    binary ~/= _steamAlphabet.length;
  }
  return buffer.toString();
}

int _pow10(int exponent) {
  var value = 1;
  for (var i = 0; i < exponent; i++) {
    value *= 10;
  }
  return value;
}

/// 按「自动 / 3 位 / 4 位 / 不分组」排版验证码。
///
/// 自动规则：6 位 → 3+3，8 位 → 4+4，其余原样；Steam 永不分组。
String formatOtpCode(String code, CodeGrouping grouping, {bool steam = false}) {
  if (steam) return code;
  final size = switch (grouping) {
    CodeGrouping.none => 0,
    CodeGrouping.three => 3,
    CodeGrouping.four => 4,
    CodeGrouping.auto => code.length == 8 ? 4 : (code.length == 6 ? 3 : 0),
  };
  if (size <= 0 || code.isEmpty) return code;
  final buffer = StringBuffer();
  for (var i = 0; i < code.length; i++) {
    if (i > 0 && i % size == 0) buffer.write(' ');
    buffer.write(code[i]);
  }
  return buffer.toString();
}

/// 隐藏态占位符：保留分组空格，只把可见字符换成圆点。
///
/// 入参必须是已经 [formatOtpCode] 过的文本；这样 6 位码显示为 `••• •••`，
/// 不会把分隔空格也算成一个点。
String hiddenOtpCode(String code) {
  final buffer = StringBuffer();
  for (final rune in code.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(char.trim().isEmpty ? char : '•');
  }
  return buffer.toString();
}
