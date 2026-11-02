import 'dart:math';

import '../crypto/random.dart';

const String _lower = 'abcdefghijkmnopqrstuvwxyz';
const String _upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const String _digits = '23456789';
const String _symbols = '!@#\$%^&*()-_=+[]{}';

class PasswordGeneratorOptions {
  const PasswordGeneratorOptions({
    this.length = 20,
    this.lowercase = true,
    this.uppercase = true,
    this.digits = true,
    this.symbols = true,
  });

  final int length;
  final bool lowercase;
  final bool uppercase;
  final bool digits;
  final bool symbols;

  /// 至少一类字符，否则生成空集合。
  bool get isUsable => lowercase || uppercase || digits || symbols;

  PasswordGeneratorOptions copyWith({
    int? length,
    bool? lowercase,
    bool? uppercase,
    bool? digits,
    bool? symbols,
  }) {
    return PasswordGeneratorOptions(
      length: length ?? this.length,
      lowercase: lowercase ?? this.lowercase,
      uppercase: uppercase ?? this.uppercase,
      digits: digits ?? this.digits,
      symbols: symbols ?? this.symbols,
    );
  }
}

/// 生成随机密码。
///
/// 逐字符用 [Random.secure] 取下标，并保证每类被勾选的字符至少出现一次，
/// 避免「勾了符号却一个符号都没有」这种实际很常见的结果。
String generatePassword(PasswordGeneratorOptions options) {
  final pools = <String>[
    if (options.lowercase) _lower,
    if (options.uppercase) _upper,
    if (options.digits) _digits,
    if (options.symbols) _symbols,
  ];
  if (pools.isEmpty) return '';

  final length = max(options.length, pools.length);
  final chars = <String>[];
  // 先每类各取一个，再从全部字符里补齐。
  for (final pool in pools) {
    chars.add(pool[randomInt(pool.length)]);
  }
  final all = pools.join();
  while (chars.length < length) {
    chars.add(all[randomInt(all.length)]);
  }
  // 洗牌，避免前几位固定按字符类顺序出现。
  for (var i = chars.length - 1; i > 0; i--) {
    final j = randomInt(i + 1);
    final tmp = chars[i];
    chars[i] = chars[j];
    chars[j] = tmp;
  }
  return chars.join();
}

/// 用同一把安全随机源取 [max] 以内的下标，拒绝采样避免取模偏差。
int randomInt(int max) {
  if (max <= 0) return 0;
  final limit = 256 - (256 % max);
  while (true) {
    final value = randomBytes(1)[0];
    if (value < limit) return value % max;
  }
}
