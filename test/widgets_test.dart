import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/app_theme.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/common_widgets.dart';
import 'package:keycase/l10n/app_localizations.dart';

Widget host(Widget child) {
  return MaterialApp(
    theme: buildKeyCaseTheme(
      brightness: Brightness.light,
      preferences: const AppPreferences(),
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('首字母头像显示首字母', (tester) async {
    await tester.pumpWidget(host(const LetterAvatar(seed: 'GitHub')));
    expect(find.text('G'), findsOneWidget);
  });

  testWidgets('空标题回落到问号', (tester) async {
    await tester.pumpWidget(host(const LetterAvatar(seed: '   ')));
    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('分段控件切换选中值', (tester) async {
    var selected = 'a';
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => KcSegmentedControl<String>(
            values: const <String>['a', 'b', 'c'],
            selected: selected,
            labelOf: (value) => value.toUpperCase(),
            onChanged: (value) => setState(() => selected = value),
          ),
        ),
      ),
    );
    expect(find.text('A'), findsOneWidget);
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(selected, 'b');
  });

  testWidgets('卡片承载内容', (tester) async {
    await tester.pumpWidget(host(const KcCard(child: Text('内容'))));
    expect(find.text('内容'), findsOneWidget);
  });

  testWidgets('详情行点击复制回调生效', (tester) async {
    var copied = false;
    await tester.pumpWidget(
      host(
        KcDetailRow(
          label: '账号',
          value: 'talyra42',
          onCopy: () => copied = true,
        ),
      ),
    );
    expect(find.text('talyra42'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.copy_rounded));
    expect(copied, isTrue);
  });

  testWidgets('隐藏态验证码不泄露数字', (tester) async {
    await tester.pumpWidget(
      host(
        KcCodeCapsule(code: '123 456', hidden: true, onTap: () {}),
      ),
    );
    expect(find.text('123 456'), findsNothing);
    expect(find.textContaining('•'), findsOneWidget);
  });
}
