import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/pages/editor_page.dart';
import 'package:keycase/pages/scan_page.dart';

import 'support/controller_factory.dart';
import 'support/hosts.dart';

void main() {
  testWidgets('扫码识别后进入预填的编辑页，不直接写入', (tester) async {
    final test = makeController();
    await test.controller.bootstrap();
    await test.controller.unlock('pw');

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const TokenScanPage(
        initialLink:
            'otpauth://totp/GitHub:alice@example.com'
            '?secret=JBSWY3DPEHPK3PXP&issuer=GitHub',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ItemEditorPage), findsOneWidget);
    expect(find.text('新建令牌'), findsOneWidget);
    expect(test.controller.state.data!.items, isEmpty);
    await disposeTestController(tester, test.controller);
  });
}
