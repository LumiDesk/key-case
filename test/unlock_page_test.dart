import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/keycase_state.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/app/platform/biometric_auth.dart';
import 'package:keycase/pages/auth_pages.dart';

import 'support/controller_factory.dart';
import 'support/hosts.dart';

void main() {
  testWidgets('解锁页出现时自动弹出指纹并解锁', (tester) async {
    final test = makeController(
      preferences: const AppPreferences(biometricEnabled: true),
    );
    test.native.vaultKey = Uint8List(32);
    test.biometrics.result = BiometricResult.success;
    await test.controller.bootstrap();

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const UnlockPage(),
    );

    expect(test.biometrics.authenticateCalls, 1);
    expect(test.controller.state.isUnlocked, isTrue);
  });

  testWidgets('未启用指纹时不会自动弹出', (tester) async {
    final test = makeController();
    await test.controller.bootstrap();

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const UnlockPage(),
    );

    expect(test.biometrics.authenticateCalls, 0);
    expect(test.controller.state.status, VaultStatus.locked);
  });

  testWidgets('自动弹出被取消时静默回退且不重复弹出', (tester) async {
    final test = makeController(
      preferences: const AppPreferences(biometricEnabled: true),
    );
    test.biometrics.result = BiometricResult.canceled;
    await test.controller.bootstrap();

    await pumpKcPage(
      tester,
      controller: test.controller,
      page: const UnlockPage(),
    );

    expect(test.biometrics.authenticateCalls, 1);
    expect(test.controller.state.status, VaultStatus.locked);
    expect(test.controller.state.error, isNull);

    await tester.pump(const Duration(seconds: 2));
    expect(test.biometrics.authenticateCalls, 1);
  });

  testWidgets('页面在后台创建时等回到前台再弹出一次', (tester) async {
    final test = makeController(
      preferences: const AppPreferences(biometricEnabled: true),
    );
    test.native.vaultKey = Uint8List(32);
    await test.controller.bootstrap();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    usePhoneSurface(tester);
    await tester.pumpWidget(
      kcTestApp(controller: test.controller, home: const UnlockPage()),
    );
    await tester.pump();

    expect(test.biometrics.authenticateCalls, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(test.biometrics.authenticateCalls, 1);
  });
}
