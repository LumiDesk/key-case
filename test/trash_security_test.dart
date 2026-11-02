import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/pages/security_page.dart';
import 'package:keycase/pages/trash_page.dart';
import 'package:keycase/pages/item_tiles.dart';

import 'support/controller_factory.dart';
import 'support/hosts.dart';

void main() {
  testWidgets('回收站可以恢复条目', (tester) async {
    final trashed = testLogin(title: '旧账号')
        .copyWith(deletedAt: DateTime.utc(2026, 1, 2));
    final test = makeController(items: <VaultItem>[trashed]);
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const TrashPage(),
    );

    expect(find.text('旧账号'), findsOneWidget);
    await tester.tap(find.text('恢复'));
    await tester.pumpAndSettle();

    expect(test.controller.state.activeItems.single.title, '旧账号');
    expect(find.text('回收站是空的'), findsOneWidget);
    await disposeTestController(tester, test.controller);
  });

  testWidgets('安全中心展示弱密码与复用密码', (tester) async {
    final test = makeController(
      items: <VaultItem>[
        testLogin(id: 'a', title: 'A', password: '123456'),
        testLogin(id: 'b', title: 'B', password: '123456'),
      ],
    );
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const SecurityPage(),
    );

    expect(find.textContaining('弱密码'), findsOneWidget);
    expect(find.textContaining('重复使用的密码'), findsOneWidget);
    expect(find.byType(KcLoginTile), findsNWidgets(4));
    await disposeTestController(tester, test.controller);
  });

  testWidgets('安全中心没有问题显示空态', (tester) async {
    final test = makeController(
      items: <VaultItem>[
        testLogin(id: 'safe', title: 'Safe', password: 'Correct-Horse-2026!'),
      ],
    );
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const SecurityPage(),
    );

    expect(find.text('没有发现问题'), findsOneWidget);
    await disposeTestController(tester, test.controller);
  });
}
