import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/main.dart';

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

  test('设备 locale 带地区时仍匹配到中文', () {
    expect(
      resolveAppLocalizations(const Locale('zh', 'CN')).noticeBiometricEnabled,
      '已启用指纹解锁',
    );
    expect(
      resolveAppLocalizations(const Locale('en', 'US')).noticeBiometricEnabled,
      'Fingerprint unlock enabled',
    );
  });
}
