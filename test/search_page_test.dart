import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/pages/detail_page.dart';
import 'package:keycase/pages/item_tiles.dart';
import 'package:keycase/pages/search_page.dart';

import 'support/controller_factory.dart';
import 'support/hosts.dart';

void main() {
  testWidgets('搜索结果点击后打开条目详情', (tester) async {
    final test = makeController(items: <VaultItem>[testLogin()]);
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const SearchPage(),
    );

    await tester.enterText(find.byType(TextField), 'GitHub');
    await tester.pump();
    expect(find.byType(KcLoginTile), findsOneWidget);

    await tester.tap(find.byType(KcLoginTile));
    await tester.pumpAndSettle();

    expect(find.byType(ItemDetailPage), findsOneWidget);
    expect(find.text('talyra42'), findsWidgets);
    await disposeTestController(tester, test.controller);
  });
}
