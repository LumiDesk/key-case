import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/util/date_format.dart';
import 'package:keycase/l10n/app_localizations.dart';

Future<String> _captureRelative(
  WidgetTester tester,
  Locale locale,
  Duration age,
) async {
  var value = '';
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
        builder: (context) {
          value = formatRelative(context, DateTime.now().subtract(age));
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return value;
}

void main() {
  testWidgets('相对时间跟随中英文文案', (tester) async {
    final zh = await _captureRelative(
      tester,
      const Locale('zh'),
      const Duration(minutes: 10),
    );
    final en = await _captureRelative(
      tester,
      const Locale('en'),
      const Duration(minutes: 10),
    );

    expect(zh, '10 分钟前');
    expect(en, '10 min ago');
  });

  testWidgets('刚刚与小时级相对时间使用本地化文案', (tester) async {
    final justNow = await _captureRelative(
      tester,
      const Locale('zh'),
      const Duration(seconds: 5),
    );
    final hours = await _captureRelative(
      tester,
      const Locale('en'),
      const Duration(hours: 2),
    );

    expect(justNow, '刚刚');
    expect(hours, '2 h ago');
  });
}
