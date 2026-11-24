import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/pages/settings_page.dart';

import 'support/controller_factory.dart';
import 'support/hosts.dart';

SettingsPage settingsPage() =>
    SettingsPage(onLock: () {}, onOpenTrash: () {}, onOpenSecurity: () {});

void main() {
  testWidgets('回收站副标题显示条数而不是裸数字', (tester) async {
    final trashed = testLogin(title: '旧账号')
        .copyWith(deletedAt: DateTime.utc(2026, 1, 2));
    final test = makeController(items: <VaultItem>[trashed]);
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(tester, controller: test.controller, page: settingsPage());
    await tester.scrollUntilVisible(
      find.text('回收站'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('共 1 条'), findsOneWidget);
    await disposeTestController(tester, test.controller);
  });

  testWidgets('空回收站显示暂无，关于区包含 GitHub 链接', (tester) async {
    final test = makeController();
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(tester, controller: test.controller, page: settingsPage());
    await tester.scrollUntilVisible(
      find.text('GitHub'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('暂无'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('github.com/LumiDesk/key-case'), findsOneWidget);
    await disposeTestController(tester, test.controller);
  });

  testWidgets('换码动画可切换并写进偏好', (tester) async {
    final test = makeController();
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(tester, controller: test.controller, page: settingsPage());
    await tester.ensureVisible(find.text('换码动画'));
    await tester.pumpAndSettle();
    expect(find.text('飘散'), findsOneWidget);

    await tester.tap(find.text('换码动画'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('滚动').last);
    await tester.pumpAndSettle();

    expect(test.controller.preferences.codeAnimation, CodeAnimation.roll);
    expect(find.text('滚动'), findsOneWidget);
    await disposeTestController(tester, test.controller);
  });
}
