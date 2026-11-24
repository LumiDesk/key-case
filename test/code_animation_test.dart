import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/common_widgets.dart';
import 'package:keycase/l10n/app_localizations.dart';

/// 用按钮切换验证码，验证胶囊的换码过渡。
class _CapsuleHarness extends StatefulWidget {
  const _CapsuleHarness({
    required this.effect,
    this.disableAnimations = false,
    this.withNext = false,
  });

  final KcCodeEffect effect;
  final bool disableAnimations;
  final bool withNext;

  @override
  State<_CapsuleHarness> createState() => _CapsuleHarnessState();
}

class _CapsuleHarnessState extends State<_CapsuleHarness> {
  bool _second = false;

  String get _code => _second ? '789 012' : '123 456';
  String get _next => _second ? '345 678' : '901 234';

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        KcCodeCapsule(code: _code, effect: widget.effect, onTap: () {}),
        if (widget.withNext)
          KcAnimatedCode(
            text: _next,
            effect: widget.effect,
            fadeOnly: true,
            style: const TextStyle(fontSize: 12),
          ),
        TextButton(
          onPressed: () => setState(() => _second = !_second),
          child: const Text('next'),
        ),
      ],
    );
    if (!widget.disableAnimations) {
      return _app(Center(child: content));
    }
    return _app(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Center(child: content),
      ),
    );
  }

  Widget _app(Widget child) {
    return MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: child),
    );
  }
}

Future<void> _switch(WidgetTester tester) async {
  await tester.tap(find.text('next'));
  await tester.pump();
}

void main() {
  testWidgets('关闭动画时验证码直接替换', (tester) async {
    await tester.pumpWidget(const _CapsuleHarness(effect: KcCodeEffect.none));
    expect(find.text('123 456'), findsOneWidget);

    await _switch(tester);

    expect(find.text('123 456'), findsNothing);
    expect(find.text('789 012'), findsOneWidget);
  });

  testWidgets('滚动：旧码上移淡出，新码从下方推入', (tester) async {
    await tester.pumpWidget(const _CapsuleHarness(effect: KcCodeEffect.roll));
    await _switch(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('123 456'), findsOneWidget);
    expect(find.text('789 012'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('123 456'), findsNothing);
    expect(find.text('789 012'), findsOneWidget);
  });

  testWidgets('飘散：旧码拆成逐字粒子后消失', (tester) async {
    await tester.pumpWidget(const _CapsuleHarness(effect: KcCodeEffect.dust));
    await _switch(tester);
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      find.byKey(const ValueKey<String>('code_dust_particles')),
      findsOneWidget,
    );
    // 分组空格不生成粒子：6 位码就是 6 个字形。
    expect(find.text('1'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('code_dust_particles')),
      findsNothing,
    );
    expect(find.text('789 012'), findsOneWidget);
  });

  testWidgets('系统要求移除动画时不播过渡', (tester) async {
    await tester.pumpWidget(
      const _CapsuleHarness(effect: KcCodeEffect.dust, disableAnimations: true),
    );
    await _switch(tester);

    expect(find.text('123 456'), findsNothing);
    expect(find.text('789 012'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('code_dust_particles')),
      findsNothing,
    );
  });

  testWidgets('下一组数字只做淡入', (tester) async {
    await tester.pumpWidget(
      const _CapsuleHarness(effect: KcCodeEffect.dust, withNext: true),
    );
    await _switch(tester);
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.text('901 234'), findsOneWidget);
    expect(find.text('345 678'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('901 234'), findsNothing);
    expect(find.text('345 678'), findsOneWidget);
  });
}
