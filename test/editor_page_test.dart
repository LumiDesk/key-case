import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/import/otpauth_parser.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/pages/editor_page.dart';

import 'support/controller_factory.dart';
import 'support/hosts.dart';

/// 模拟扫码结果：otpauth 链接解析成条目草稿。
VaultItem scannedToken() {
  final payload = parseOtpauthUri(
    'otpauth://totp/GitHub:alice@example.com'
    '?secret=JBSWY3DPEHPK3PXP&issuer=GitHub&algorithm=SHA1&digits=6&period=30',
  )!;
  return payload.toItem(DateTime.utc(2026, 1, 1));
}

void main() {
  testWidgets('扫码草稿打开新建令牌页并预填，点保存才写入', (tester) async {
    final test = makeController();
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: _EditorLauncher(draft: scannedToken()),
    );

    expect(find.text('新建令牌'), findsOneWidget);
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.controller!.text)
        .toList();
    expect(fields, <String>['GitHub', 'alice@example.com', 'JBSWY3DPEHPK3PXP']);
    // 打开编辑页只是草稿，还没有写进保险库。
    expect(test.controller.state.data!.items, isEmpty);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final items = test.controller.state.data!.items;
    expect(items, hasLength(1));
    final saved = items.single;
    expect(saved.kind, ItemKind.totp);
    expect(saved.title, 'GitHub');
    expect(saved.username, 'alice@example.com');
    expect(saved.totp!.secret, 'JBSWY3DPEHPK3PXP');
    expect(saved.totp!.digits, 6);
    expect(saved.totp!.period, 30);
    expect(find.byType(ItemEditorPage), findsNothing);
    await disposeTestController(tester, test.controller);
  });

  testWidgets('草稿未修改直接返回不弹放弃确认', (tester) async {
    final test = makeController();
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: _EditorLauncher(draft: scannedToken()),
    );

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('放弃修改？'), findsNothing);
    expect(find.byType(ItemEditorPage), findsNothing);
    expect(test.controller.state.data!.items, isEmpty);
    await disposeTestController(tester, test.controller);
  });

  testWidgets('改过草稿再返回会确认放弃', (tester) async {
    final test = makeController();
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: _EditorLauncher(draft: scannedToken()),
    );

    await tester.enterText(find.byType(TextField).first, 'GitHub Work');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('放弃修改？'), findsOneWidget);
    await disposeTestController(tester, test.controller);
  });
  testWidgets('登录项只在密码框右侧保留一个随机密码按钮', (tester) async {
    final test = makeController();
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const _EditorLauncher(),
    );

    expect(find.byType(ItemEditorPage), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byTooltip('生成随机密码'), findsOneWidget);
    expect(find.byIcon(Icons.casino_outlined), findsOneWidget);
    expect(find.byIcon(Icons.autorenew_rounded), findsNothing);
    await disposeTestController(tester, test.controller);
  });
}

/// 先把编辑页压进导航栈，这样「保存 / 返回」都能正常出栈。
class _EditorLauncher extends StatefulWidget {
  const _EditorLauncher({this.draft});

  final VaultItem? draft;

  @override
  State<_EditorLauncher> createState() => _EditorLauncherState();
}

class _EditorLauncherState extends State<_EditorLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ItemEditorPage(
            kind: widget.draft?.kind ?? ItemKind.login,
            initialDraft: widget.draft,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}
