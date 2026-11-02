import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/pages/editor_page.dart';
import 'package:keycase/pages/settings_page.dart';

import 'support/controller_factory.dart';
import 'support/hosts.dart';

void main() {
  testWidgets('编辑令牌高级设置使用锚点菜单并可切换选项', (tester) async {
    final test = makeController();
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const ItemEditorPage(kind: ItemKind.totp),
    );

    expect(find.text('TOTP'), findsOneWidget);
    await tester.tap(find.text('TOTP'));
    await tester.pumpAndSettle();

    final hotp = find.byKey(
      const ValueKey<String>('editor_token_type_menu_item_hotp'),
    );
    expect(hotp, findsOneWidget);
    await tester.tap(hotp);
    await tester.pumpAndSettle();

    expect(find.text('HOTP'), findsOneWidget);
  });

  testWidgets('设置页语言使用锚点菜单并写回偏好', (tester) async {
    final test = makeController();
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: SettingsPage(
        onLock: () {},
        onOpenTrash: () {},
        onOpenSecurity: () {},
      ),
    );

    await tester.tap(find.text('语言'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('settings_language_menu_item_en')),
    );
    await tester.pumpAndSettle();

    expect(test.controller.preferences.languageCode, 'en');
  });
}
