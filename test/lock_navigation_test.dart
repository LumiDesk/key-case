import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/keycase_controller.dart';
import 'package:keycase/app/keycase_state.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/main.dart';
import 'package:keycase/pages/auth_pages.dart';
import 'package:keycase/pages/detail_page.dart';
import 'package:keycase/pages/editor_page.dart';

import 'support/controller_factory.dart';
import 'support/hosts.dart';

Future<void> pumpApp(WidgetTester tester, KeyCaseController controller) async {
  usePhoneSurface(tester);
  await tester.pumpWidget(KeyCaseApp(controller: controller));
  await tester.pumpAndSettle();
}

Future<void> unlockWithPassword(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'pw');
  await tester.tap(find.text('解锁'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('在详情页锁定，解锁后回到详情页', (tester) async {
    final test = makeController(
      preferences: const AppPreferences(languageCode: 'zh'),
      items: <VaultItem>[testLogin()],
    );
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpApp(tester, test.controller);
    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemDetailPage), findsOneWidget);

    test.controller.lock();
    await tester.pumpAndSettle();

    expect(find.byType(UnlockPage), findsOneWidget);
    expect(find.text('解锁 KeyCase'), findsOneWidget);

    // 锁屏期间系统返回键不能把解锁页关掉露出下面的内容。
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(UnlockPage), findsOneWidget);

    await unlockWithPassword(tester);

    expect(find.byType(UnlockPage), findsNothing);
    expect(find.byType(ItemDetailPage), findsOneWidget);
    expect(test.controller.state.isUnlocked, isTrue);
    await disposeTestController(tester, test.controller);
  });

  testWidgets('冷启动的锁定页解锁后进入主界面', (tester) async {
    final test = makeController(
      preferences: const AppPreferences(languageCode: 'zh'),
    );
    await test.controller.bootstrap();
    expect(test.controller.state.status, VaultStatus.locked);

    await pumpApp(tester, test.controller);
    expect(find.byType(UnlockPage), findsOneWidget);

    await unlockWithPassword(tester);

    expect(find.byType(UnlockPage), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    await disposeTestController(tester, test.controller);
  });

  testWidgets('删除保险库后回到创建页', (tester) async {
    final test = makeController(
      preferences: const AppPreferences(languageCode: 'zh'),
      items: <VaultItem>[testLogin()],
    );
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpApp(tester, test.controller);
    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemDetailPage), findsOneWidget);

    await test.controller.deleteVault();
    await tester.pumpAndSettle();

    expect(find.byType(CreateVaultPage), findsOneWidget);
    expect(find.byType(ItemDetailPage), findsNothing);
    await disposeTestController(tester, test.controller);
  });

  testWidgets('在设置 Tab 锁定，解锁后仍在设置 Tab', (tester) async {
    final test = makeController(
      preferences: const AppPreferences(languageCode: 'zh'),
    );
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpApp(tester, test.controller);
    await tester.tap(find.byKey(const ValueKey<String>('nav_settings')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );

    test.controller.lock();
    await tester.pumpAndSettle();
    await unlockWithPassword(tester);

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );
    await disposeTestController(tester, test.controller);
  });

  testWidgets('锁定时未保存的编辑内容不会丢', (tester) async {
    final test = makeController(
      preferences: const AppPreferences(languageCode: 'zh'),
    );
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpApp(tester, test.controller);
    await tester.tap(find.byKey(const ValueKey<String>('nav_tokens')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('kc_speed_dial_toggle')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('手动添加'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemEditorPage), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '草稿令牌');
    await tester.pump();

    test.controller.lock();
    await tester.pumpAndSettle();
    expect(find.byType(UnlockPage), findsOneWidget);

    await unlockWithPassword(tester);

    expect(find.byType(ItemEditorPage), findsOneWidget);
    final title = tester
        .widgetList<TextField>(find.byType(TextField))
        .first
        .controller!
        .text;
    expect(title, '草稿令牌');
    await disposeTestController(tester, test.controller);
  });
}
