import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/app_theme.dart';
import 'app/dev_seed.dart';
import 'app/feedback.dart';
import 'app/icons/aegis_icon_pack.dart';
import 'app/keycase_controller.dart';
import 'app/keycase_scope.dart';
import 'app/keycase_state.dart';
import 'app/messages.dart';
import 'app/models/models.dart';
import 'l10n/app_localizations.dart';
import 'pages/app_shell.dart';
import 'pages/auth_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = KeyCaseController();
  await controller.bootstrap();
  // 图标包只读一次；没读完之前列表先用首字母头像。
  unawaited(AegisIconPack.instance.ensureLoaded());
  await prepareDemoIfNeeded(controller);
  runApp(KeyCaseApp(controller: controller));
}

class KeyCaseApp extends StatefulWidget {
  const KeyCaseApp({super.key, required this.controller});

  final KeyCaseController controller;

  @override
  State<KeyCaseApp> createState() => _KeyCaseAppState();
}

class _KeyCaseAppState extends State<KeyCaseApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final KcFeedbackController _feedback = KcFeedbackController();
  VaultStatus _lastStatus = VaultStatus.loading;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastStatus = widget.controller.state.status;
    widget.controller.addListener(_handleStateChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleStateChange);
    WidgetsBinding.instance.removeObserver(this);
    _feedback.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        widget.controller.handleAppPaused();
      case AppLifecycleState.resumed:
        widget.controller.handleAppResumed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// 出错与一次性提示统一在这里消费：错误只在已解锁时用轻提示，
  /// 锁定/创建页把错误显示在表单里。
  void _handleStateChange() {
    final state = widget.controller.state;
    final wasUnlocked = _lastStatus == VaultStatus.unlocked;
    _lastStatus = state.status;
    if (wasUnlocked && state.status != VaultStatus.unlocked) {
      // 锁定后把已打开的详情/编辑/搜索等页面一起关掉，不能让明文留在栈顶。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      });
    }
    final l10n = _localizations();
    if (state.notice != null) {
      _feedback.show(
        importNoticeText(l10n, state.notice!, state.lastImportCount),
      );
      widget.controller.clearNotice();
    }
    if (state.error != null && state.status == VaultStatus.unlocked) {
      _feedback.show(errorText(l10n, state.error!));
      widget.controller.clearError();
    }
  }

  AppLocalizations _localizations() {
    final language = widget.controller.preferences.languageCode;
    final locale = language.isEmpty
        ? WidgetsBinding.instance.platformDispatcher.locale
        : Locale(language);
    return lookupAppLocalizations(
      AppLocalizations.supportedLocales.contains(locale)
          ? locale
          : const Locale('zh'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final preferences = widget.controller.preferences;
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'KeyCase',
          debugShowCheckedModeBanner: false,
          theme: buildKeyCaseTheme(
            brightness: Brightness.light,
            preferences: preferences,
          ),
          darkTheme: buildKeyCaseTheme(
            brightness: Brightness.dark,
            preferences: preferences,
          ),
          themeMode: switch (preferences.themeMode) {
            ThemeModePreference.system => ThemeMode.system,
            ThemeModePreference.light => ThemeMode.light,
            ThemeModePreference.dark => ThemeMode.dark,
          },
          locale: preferences.languageCode.isEmpty
              ? null
              : Locale(preferences.languageCode),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return KcFeedbackHost(
              controller: _feedback,
              child: KeyCaseScope(
                controller: widget.controller,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: const _RootGate(),
        );
      },
    );
  }
}

/// 根据保险库状态选择：创建 / 解锁 / 主界面。
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final controller = KeyCaseScope.of(context);
    final status = controller.state.status;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: switch (status) {
        VaultStatus.loading => const _BootSplash(),
        VaultStatus.missing => const CreateVaultPage(),
        VaultStatus.locked => const UnlockPage(),
        VaultStatus.unlocked => const AppShell(),
      },
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Icon(
          Icons.key_rounded,
          size: 42,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
