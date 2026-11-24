import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/icons/icon_packs.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/pages/icon_picker_sheet.dart';

import 'support/controller_factory.dart';
import 'support/hosts.dart';

class _PickerLauncher extends StatefulWidget {
  const _PickerLauncher();

  @override
  State<_PickerLauncher> createState() => _PickerLauncherState();
}

class _PickerLauncherState extends State<_PickerLauncher> {
  IconRef? _picked;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextButton(
              key: const ValueKey<String>('open_icon_picker'),
              onPressed: () async {
                final result = await showIconPickerSheet(
                  context: context,
                  current: const IconRef(name: 'GitHub'),
                );
                if (!mounted) return;
                setState(() => _picked = result);
              },
              child: const Text('open'),
            ),
            Text(_picked?.name ?? 'none'),
          ],
        ),
      ),
    );
  }
}

void main() {
  // 图标包在后台 isolate 里解析，必须在 testWidgets 的 fake-async 之外预热，
  // 否则 await 永远等不到 isolate 回包。
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await IconPacks.instance.ensureLoaded();
  });

  testWidgets('图标选择器在图标下方显示名称与风格标签', (tester) async {
    final test = makeController();
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const _PickerLauncher(),
    );
    await tester.tap(find.byKey(const ValueKey<String>('open_icon_picker')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Plex');
    await tester.pumpAndSettle();

    // 图标下方有名称；全彩包还有一行风格标签。
    expect(find.text('Plex'), findsWidgets);
    expect(find.text('全彩'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey<String>('icon_dashboard:Plex')));
    await tester.pumpAndSettle();

    // 选中后回传带包前缀的图标标识。
    expect(find.text('dashboard:Plex'), findsOneWidget);
    await disposeTestController(tester, test.controller);
  });

  testWidgets('默认包图标使用裸名称，便于旧数据继续匹配', (tester) async {
    final test = makeController();
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const _PickerLauncher(),
    );
    await tester.tap(find.byKey(const ValueKey<String>('open_icon_picker')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'GitHub');
    await tester.pumpAndSettle();
    // 默认包不加风格标签，全彩包才需要区分。
    expect(find.text('徽章'), findsNothing);
    expect(find.byKey(const ValueKey<String>('icon_GitHub')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('icon_GitHub')));
    await tester.pumpAndSettle();

    expect(find.text('GitHub'), findsOneWidget);
    await disposeTestController(tester, test.controller);
  });
}
