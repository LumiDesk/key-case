import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/app_theme.dart';
import 'package:keycase/app/feedback.dart';
import 'package:keycase/app/keycase_controller.dart';
import 'package:keycase/app/keycase_scope.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/l10n/app_localizations.dart';

Widget kcTestApp({
  required KeyCaseController controller,
  required Widget home,
  Locale locale = const Locale('zh'),
  KcFeedbackController? feedback,
}) {
  return AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildKeyCaseTheme(
        brightness: Brightness.light,
        preferences: controller.preferences,
      ),
      builder: (context, child) {
        final scoped = KeyCaseScope(
          controller: controller,
          child: child ?? const SizedBox.shrink(),
        );
        if (feedback == null) return scoped;
        return KcFeedbackHost(controller: feedback, child: scoped);
      },
      home: Material(color: Colors.transparent, child: home),
    ),
  );
}

void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> pumpKcPage(
  WidgetTester tester, {
  required KeyCaseController controller,
  required Widget page,
  Locale locale = const Locale('zh'),
  KcFeedbackController? feedback,
}) async {
  usePhoneSurface(tester);
  await tester.pumpWidget(
    kcTestApp(
      controller: controller,
      home: page,
      locale: locale,
      feedback: feedback,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> disposeTestController(
  WidgetTester tester,
  KeyCaseController controller,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  controller.dispose();
}

VaultItem testLogin({
  String id = 'login-1',
  String title = 'GitHub',
  String username = 'talyra42',
  String password = 'Tr0ub4dor-correct',
  List<String> urls = const <String>['https://github.com'],
  String notes = '',
  bool favorite = false,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return VaultItem(
    id: id,
    kind: ItemKind.login,
    title: title,
    username: username,
    password: password,
    urls: urls,
    notes: notes,
    favorite: favorite,
    createdAt: now,
    updatedAt: now,
  );
}

VaultItem testToken({
  String id = 'token-1',
  String title = 'GitHub',
  String secret = 'JBSWY3DPEHPK3PXP',
  OtpType type = OtpType.totp,
  int digits = 6,
  int period = 30,
  bool favorite = false,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return VaultItem(
    id: id,
    kind: ItemKind.totp,
    title: title,
    totp: TotpSecret(
      type: type,
      secret: secret,
      digits: digits,
      period: period,
    ),
    favorite: favorite,
    createdAt: now,
    updatedAt: now,
  );
}
