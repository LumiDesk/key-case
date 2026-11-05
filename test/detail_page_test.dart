import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/app_theme.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/common_widgets.dart';
import 'package:keycase/pages/detail_page.dart';

import 'support/controller_factory.dart';
import 'support/hosts.dart';

void main() {
  testWidgets('顶栏收藏星标可切换，卡片与菜单里不再有收藏', (tester) async {
    final test = makeController(items: <VaultItem>[testLogin()]);
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const ItemDetailPage(itemId: 'login-1'),
    );

    final star = find.byKey(const ValueKey<String>('detail_favorite'));
    expect(star, findsOneWidget);
    expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
    expect(find.widgetWithText(TextButton, '收藏'), findsNothing);

    await tester.tap(star);
    await tester.pumpAndSettle();

    expect(test.controller.state.data!.itemById('login-1')!.favorite, isTrue);
    final filled = tester.widget<Icon>(find.byIcon(Icons.star_rounded));
    expect(filled.color, kcWarningOnLight);

    await tester.tap(star);
    await tester.pumpAndSettle();

    expect(test.controller.state.data!.itemById('login-1')!.favorite, isFalse);
    expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);

    // 更多菜单只保留编辑与危险操作，收藏不再重复出现。
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    expect(find.text('收藏'), findsNothing);
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('移到回收站'), findsOneWidget);
    await disposeTestController(tester, test.controller);
  });

  testWidgets('登录项备注完整显示、可长按选择且没有复制按钮', (tester) async {
    final notes = List<String>.generate(
      6,
      (index) => '第 ${index + 1} 行：恢复码与备用邮箱',
    ).join('\n');
    final test = makeController(items: <VaultItem>[testLogin(notes: notes)]);
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const ItemDetailPage(itemId: 'login-1'),
    );

    final selectable = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );
    expect(selectable.data, notes);
    expect(selectable.maxLines, isNull);

    final section = find.byType(KcTextSection);
    expect(section, findsOneWidget);
    expect(
      find.descendant(of: section, matching: find.byIcon(Icons.copy_rounded)),
      findsNothing,
    );
    // 只保留分组标题，不再有卡片内重复的「备注」字段名。
    expect(find.text('备注'), findsOneWidget);
    await disposeTestController(tester, test.controller);
  });

  testWidgets('令牌备注标题不重复，长文本同样可选', (tester) async {
    const notes = '由 Zero Trust 管理\n恢复码见离线保险箱';
    final test = makeController(items: <VaultItem>[testToken(notes: notes)]);
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const ItemDetailPage(itemId: 'token-1'),
    );

    expect(find.text('备注'), findsOneWidget);
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      notes,
    );
    expect(find.text('高级设置'), findsOneWidget);
    await disposeTestController(tester, test.controller);
  });
}
