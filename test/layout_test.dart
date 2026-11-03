import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/pages/home_page.dart';
import 'package:keycase/pages/settings_page.dart';

import 'support/controller_factory.dart';
import 'support/hosts.dart';

Future<void> pumpAt(
  WidgetTester tester, {
  required Widget page,
}) async {
  final test = makeController();
  await test.controller.bootstrap();
  await test.controller.unlock('pw');
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    kcTestApp(controller: test.controller, home: page),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('设置页在 360dp + 2x 字号下不溢出', (tester) async {
    await pumpAt(
      tester,
      page: SettingsPage(
        onLock: () {},
        onOpenTrash: () {},
        onOpenSecurity: () {},
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('首页在 360dp + 2x 字号下不溢出', (tester) async {
    await pumpAt(
      tester,
      page: HomePage(
        onOpenItem: (_) {},
        onOpenSearch: () {},
        onOpenSecurity: () {},
        onBrowseLogins: () {},
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
