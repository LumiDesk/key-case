import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/keycase_controller.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/pages/detail_page.dart';
import 'package:keycase/pages/editor_page.dart';
import 'package:keycase/pages/home_page.dart';
import 'package:keycase/pages/settings_page.dart';

import 'support/controller_factory.dart';
import 'support/hosts.dart';

final String longNotes = List<String>.generate(
  12,
  (index) => '第 ${index + 1} 行：这是一段很长的备注，用来验证自动换行与高度自适应',
).join('\n');

Future<KeyCaseController> pumpAt(
  WidgetTester tester, {
  required Widget page,
  List<VaultItem> items = const <VaultItem>[],
}) async {
  final test = makeController(items: items);
  await test.controller.bootstrap();
  await test.controller.unlock('pw');
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(kcTestApp(controller: test.controller, home: page));
  await tester.pumpAndSettle();
  return test.controller;
}

void main() {
  testWidgets('设置页在 360dp + 2x 字号下不溢出', (tester) async {
    final controller = await pumpAt(
      tester,
      page: SettingsPage(
        onLock: () {},
        onOpenTrash: () {},
        onOpenSecurity: () {},
      ),
    );
    expect(tester.takeException(), isNull);
    await disposeTestController(tester, controller);
  });

  testWidgets('首页在 360dp + 2x 字号下不溢出', (tester) async {
    final controller = await pumpAt(
      tester,
      page: HomePage(
        onOpenItem: (_) {},
        onOpenSearch: () {},
        onOpenSecurity: () {},
        onBrowseLogins: () {},
      ),
    );
    expect(tester.takeException(), isNull);
    await disposeTestController(tester, controller);
  });

  testWidgets('登录项详情页在 360dp + 2x 字号下不溢出', (tester) async {
    final controller = await pumpAt(
      tester,
      items: <VaultItem>[testLogin(notes: longNotes)],
      page: const ItemDetailPage(itemId: 'login-1'),
    );
    expect(tester.takeException(), isNull);
    await disposeTestController(tester, controller);
  });

  testWidgets('令牌详情页在 360dp + 2x 字号下不溢出', (tester) async {
    final controller = await pumpAt(
      tester,
      items: <VaultItem>[testToken(notes: longNotes)],
      page: const ItemDetailPage(itemId: 'token-1'),
    );
    expect(tester.takeException(), isNull);
    await disposeTestController(tester, controller);
  });

  testWidgets('编辑页长备注在 360dp + 2x 字号下不溢出', (tester) async {
    final controller = await pumpAt(
      tester,
      page: ItemEditorPage(
        kind: ItemKind.login,
        initialDraft: testLogin(notes: longNotes),
      ),
    );
    expect(tester.takeException(), isNull);
    await disposeTestController(tester, controller);
  });
}
