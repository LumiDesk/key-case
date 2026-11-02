import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/feedback.dart';
import 'package:keycase/pages/app_shell.dart';

import 'support/controller_factory.dart';
import 'support/hosts.dart';

void main() {
  testWidgets('非首页按返回先回到主页', (tester) async {
    final test = makeController();
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const AppShell(),
    );
    await tester.tap(find.byKey(const ValueKey<String>('nav_settings')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    await disposeTestController(tester, test.controller);
  });

  testWidgets('首页第一次返回显示提示，第二次返回才退出', (tester) async {
    final feedback = KcFeedbackController();
    final exitCalls = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') exitCalls.add(call.method);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    final test = makeController();
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const AppShell(),
      feedback: feedback,
    );

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('再次返回退出软件'), findsOneWidget);
    expect(exitCalls, isEmpty);
    expect(test.controller.state.isUnlocked, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 250));

    expect(exitCalls, <String>['SystemNavigator.pop']);
    await disposeTestController(tester, test.controller);
    feedback.dispose();
  });

  testWidgets('首页提示过期后再次返回会重新提示', (tester) async {
    final feedback = KcFeedbackController();
    final test = makeController();
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const AppShell(),
      feedback: feedback,
    );

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 3));
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('再次返回退出软件'), findsOneWidget);
    await disposeTestController(tester, test.controller);
    feedback.dispose();
  });
}
