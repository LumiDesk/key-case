import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('中英文 ARB 键与占位符一致', () {
    final zh = jsonDecode(
      File('lib/l10n/app_zh.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final en = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;

    final zhKeys = zh.keys.where((key) => !key.startsWith('@')).toSet();
    final enKeys = en.keys.where((key) => !key.startsWith('@')).toSet();
    expect(zhKeys, enKeys, reason: 'ARB 键集合必须一致，文案才能跟随语言切换');

    final placeholder = RegExp(r'\{([a-zA-Z]\w*)[,}]');
    for (final key in zhKeys) {
      final zhPlaceholders = placeholder
          .allMatches('${zh[key]}')
          .map((match) => match.group(1))
          .toSet();
      final enPlaceholders = placeholder
          .allMatches('${en[key]}')
          .map((match) => match.group(1))
          .toSet();
      expect(zhPlaceholders, enPlaceholders, reason: '$key 的中英文占位符不一致');
    }
  });
}
