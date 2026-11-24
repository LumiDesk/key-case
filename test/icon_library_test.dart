import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/icons/brand_icon.dart';
import 'package:keycase/app/icons/icon_packs.dart';
import 'package:keycase/pages/icon_library_page.dart';
import 'package:keycase/pages/settings_page.dart';

import 'support/controller_factory.dart';
import 'support/hosts.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await IconPacks.instance.ensureLoaded();
  });

  testWidgets('设置页的图标区进入只读图标库', (tester) async {
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
    await tester.scrollUntilVisible(
      find.text('浏览图标'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('浏览图标'), findsOneWidget);

    await tester.tap(find.text('浏览图标'));
    await tester.pumpAndSettle();

    expect(find.byType(IconLibraryPage), findsOneWidget);
    expect(find.text('图标库'), findsOneWidget);
    await disposeTestController(tester, test.controller);
  });

  testWidgets('图标库显示总数、可按包筛选、可点开预览', (tester) async {
    final test = makeController();
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const IconLibraryPage(),
    );

    expect(
      find.text('${IconPacks.instance.allIcons.length} 个图标'),
      findsOneWidget,
    );

    // 搜索只保留命中项（别名也会命中，用注册表算出预期条数）。
    await tester.enterText(find.byType(TextField).first, 'proxmox');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('icon_library_dashboard:Proxmox')),
      findsOneWidget,
    );
    expect(
      find.text('${IconPacks.instance.search('proxmox').length} 个图标'),
      findsOneWidget,
    );

    // 切到「单色」包：只剩该包的图标。
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('按图标包筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('单色').last);
    await tester.pumpAndSettle();
    expect(
      find.text('${IconPacks.instance.iconsOf(IconPackId.aegis).length} 个图标'),
      findsOneWidget,
    );

    // 点开一格查看大图预览（预览用 72dp 的大图标）。
    final first = IconPacks.instance.iconsOf(IconPackId.aegis).first;
    await tester.tap(find.byKey(ValueKey<String>('icon_library_${first.ref}')));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is KcBrandIcon && widget.size == 72,
      ),
      findsOneWidget,
    );
    await disposeTestController(tester, test.controller);
  });
}
