import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/pages/app_shell.dart';

import 'support/controller_factory.dart';
import 'support/hosts.dart';

/// 主按钮图标的旋转角度（弧度）：收起是 0，展开是 45°。
double _toggleRotation(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find
        .ancestor(
          of: find.byIcon(Icons.add_rounded),
          matching: find.byType(Transform),
        )
        .first,
  );
  return math.atan2(
    transform.transform.storage[1],
    transform.transform.storage[0],
  );
}

void main() {
  testWidgets('令牌加号展开两个动作，再次点击收起', (tester) async {
    final test = makeController();
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const AppShell(),
    );
    await tester.tap(find.byKey(const ValueKey<String>('nav_tokens')));
    await tester.pumpAndSettle();

    final toggle = find.byKey(const ValueKey<String>('kc_speed_dial_toggle'));
    expect(toggle, findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.text('扫码添加'), findsOneWidget);
    expect(find.text('手动添加'), findsOneWidget);
    // 主按钮不换图标：加号旋转 45° 变成叉。
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(_toggleRotation(tester), closeTo(math.pi / 4, 1e-6));

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.text('扫码添加'), findsNothing);
    expect(find.text('手动添加'), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(_toggleRotation(tester), closeTo(0, 1e-6));
    await disposeTestController(tester, test.controller);
  });

  testWidgets('点击速拨外部区域会收起', (tester) async {
    final test = makeController();
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const AppShell(),
    );
    await tester.tap(find.byKey(const ValueKey<String>('nav_tokens')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('kc_speed_dial_toggle')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('token_dial_barrier')));
    await tester.pumpAndSettle();

    expect(find.text('扫码添加'), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    await disposeTestController(tester, test.controller);
  });

  testWidgets('手动添加动作收起速拨并进入编辑页', (tester) async {
    final test = makeController();
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const AppShell(),
    );
    await tester.tap(find.byKey(const ValueKey<String>('nav_tokens')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('kc_speed_dial_toggle')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('手动添加'));
    await tester.pumpAndSettle();

    expect(find.text('新建令牌'), findsOneWidget);
    await disposeTestController(tester, test.controller);
  });
}
