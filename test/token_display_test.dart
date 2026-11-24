import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/app/otp/otp.dart';
import 'package:keycase/pages/detail_page.dart';
import 'package:keycase/pages/item_tiles.dart';

import 'support/controller_factory.dart';
import 'support/hosts.dart';

const int fixedSeconds = 1767225600;

String codeAt(TotpSecret secret, {int offset = 0}) {
  final time = DateTime.fromMillisecondsSinceEpoch(fixedSeconds * 1000);
  return generateOtpCode(
    secret: secret,
    counter: otpCounterAt(secret, time) + offset,
  );
}

String formattedAt(TotpSecret secret, {int offset = 0}) {
  return formatOtpCode(
    codeAt(secret, offset: offset),
    CodeGrouping.auto,
    steam: secret.type == OtpType.steam,
  );
}

void main() {
  testWidgets('隐藏令牌显示与原始位数一致的圆点，下一组也只显示圆点', (tester) async {
    final token = testToken();
    final test = makeController(
      preferences: const AppPreferences(codeAnimation: CodeAnimation.off),
      items: <VaultItem>[token],
    );
    await test.controller.bootstrap();
    await test.controller.unlock('pw');
    test.controller.clock.seconds.value = fixedSeconds;

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: Scaffold(
        body: Column(
          children: <Widget>[
            KcTokenTile(
              item: token,
              clock: test.controller.clock,
              showCode: false,
              showNext: true,
              grouping: CodeGrouping.auto,
              onTap: () {},
            ),
            const Text('outside'),
          ],
        ),
      ),
    );

    final secret = token.totp!;
    final formatted = formattedAt(secret);
    final nextFormatted = formattedAt(secret, offset: 1);
    final hidden = hiddenOtpCode(formatted);

    expect(hidden.replaceAll(' ', '').length, 6);
    // 主验证码与「下一组」都隐藏，两行都是同样位数的圆点。
    expect(find.text(hidden), findsNWidgets(2));
    expect(find.text(formatted), findsNothing);
    expect(find.text(nextFormatted), findsNothing);
    await disposeTestController(tester, test.controller);
  });

  testWidgets('点击隐藏验证码会揭开并复制，点别处立即隐藏', (tester) async {
    final token = testToken();
    final test = makeController(
      preferences: const AppPreferences(codeAnimation: CodeAnimation.off),
      items: <VaultItem>[token],
    );
    await test.controller.bootstrap();
    await test.controller.unlock('pw');
    test.controller.clock.seconds.value = fixedSeconds;

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: Scaffold(
        body: Column(
          children: <Widget>[
            KcTokenTile(
              item: token,
              clock: test.controller.clock,
              showCode: false,
              showNext: true,
              grouping: CodeGrouping.auto,
              onTap: () {},
            ),
            const Text('outside'),
          ],
        ),
      ),
    );

    final secret = token.totp!;
    final formatted = formattedAt(secret);
    final nextFormatted = formattedAt(secret, offset: 1);
    final hidden = hiddenOtpCode(formatted);

    await tester.tap(find.text(hidden).first);
    await tester.pump();

    expect(find.text(formatted), findsOneWidget);
    expect(find.text(nextFormatted), findsOneWidget);

    await tester.tap(find.text('outside'));
    await tester.pump();

    expect(find.text(hidden), findsNWidgets(2));
    expect(find.text(formatted), findsNothing);
    expect(find.text(nextFormatted), findsNothing);
    await disposeTestController(tester, test.controller);
  });

  testWidgets('揭开后 10 秒自动隐藏', (tester) async {
    final token = testToken();
    final test = makeController(
      preferences: const AppPreferences(codeAnimation: CodeAnimation.off),
      items: <VaultItem>[token],
    );
    await test.controller.bootstrap();
    await test.controller.unlock('pw');
    test.controller.clock.seconds.value = fixedSeconds;

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: Scaffold(
        body: KcTokenTile(
          item: token,
          clock: test.controller.clock,
          showCode: false,
          showNext: false,
          grouping: CodeGrouping.auto,
          onTap: () {},
        ),
      ),
    );

    final hidden = hiddenOtpCode(formattedAt(token.totp!));
    await tester.tap(find.text(hidden));
    await tester.pump();
    expect(find.text(hidden), findsNothing);

    await tester.pump(const Duration(seconds: 11));
    expect(find.text(hidden), findsOneWidget);
    await disposeTestController(tester, test.controller);
  });

  testWidgets('8 位令牌隐藏后仍是 8 个圆点', (tester) async {
    final token = testToken(digits: 8);
    final test = makeController(
      preferences: const AppPreferences(codeAnimation: CodeAnimation.off),
      items: <VaultItem>[token],
    );
    await test.controller.bootstrap();
    await test.controller.unlock('pw');
    test.controller.clock.seconds.value = fixedSeconds;

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: Scaffold(
        body: KcTokenTile(
          item: token,
          clock: test.controller.clock,
          showCode: false,
          showNext: false,
          grouping: CodeGrouping.auto,
          onTap: () {},
        ),
      ),
    );

    final formatted = formattedAt(token.totp!);
    expect(formatted.length, 9);
    expect(hiddenOtpCode(formatted), '•••• ••••');
    expect(find.text(hiddenOtpCode(formatted)), findsOneWidget);
    await disposeTestController(tester, test.controller);
  });

  testWidgets('详情页点击隐藏验证码后揭开并复制，点外部隐藏', (tester) async {
    final token = testToken();
    final test = makeController(
      preferences: const AppPreferences(
        showTokenCodes: false,
        showNextToken: true,
        codeAnimation: CodeAnimation.off,
      ),
      items: <VaultItem>[token],
    );
    await test.controller.bootstrap();
    await test.controller.unlock('pw');
    test.controller.clock.seconds.value = fixedSeconds;

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const ItemDetailPage(itemId: 'token-1'),
    );

    final formatted = formattedAt(token.totp!);
    final hidden = hiddenOtpCode(formatted);
    // 主验证码与下一组各一行圆点。
    expect(find.text(hidden), findsNWidgets(2));

    await tester.tap(find.text(hidden).first);
    await tester.pump();
    expect(find.text(formatted), findsOneWidget);

    await tester.tap(find.text('GitHub').first);
    await tester.pump();
    expect(find.text(hidden), findsNWidgets(2));
    await disposeTestController(tester, test.controller);
  });
}
