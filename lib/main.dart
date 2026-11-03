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

  /// 本次运行是否解锁过。为 true 时锁定不再销毁主界面，而是用解锁页盖住
  /// 当前页面，解锁后回到锁定前的位置。
  bool _sessionStarted = false;

  /// 盖在最上层的解锁路由；非 null 表示当前正锁屏。
  Route<void>? _lockRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastStatus = widget.controller.state.status;
    // 演示数据等场景可能在 runApp 之前就已解锁，这里同步一次会话标记。
    _sessionStarted = _lastStatus == VaultStatus.unlocked;
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
  ///
  /// 锁定不会关闭已打开的详情、搜索、编辑等页面：用全屏解锁路由盖住它们，
  /// 解锁后原地返回。保险库数据与密钥仍由 Controller 立即清空。
  void _handleStateChange() {
    final state = widget.controller.state;
    final previous = _lastStatus;
    _lastStatus = state.status;

    switch (state.status) {
      case VaultStatus.unlocked:
        _sessionStarted = true;
        if (previous == VaultStatus.locked) _dismissLockRoute();
      case VaultStatus.locked:
        if (previous == VaultStatus.unlocked) _showLockRoute();
      case VaultStatus.missing:
        // 保险库被删除后没有可恢复的会话，回到创建页。
        _sessionStarted = false;
        _dismissLockRoute();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        });
      case VaultStatus.loading:
        break;
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

  /// 锁定：在导航栈顶压一个不可返回的全屏解锁页，原页面留在下面。
  void _showLockRoute() {
    if (_lockRoute != null) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    final route = PageRouteBuilder<void>(
      settings: const RouteSettings(name: 'keycase_lock'),
      opaque: true,
      barrierDismissible: false,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => const _LockScreen(),
    );
    _lockRoute = route;
    unawaited(
      navigator.push<void>(route).whenComplete(() {
        if (identical(_lockRoute, route)) _lockRoute = null;
      }),
    );
  }

  /// 解锁成功：直接移除解锁页，回到锁定前的那一页。
  void _dismissLockRoute() {
    final route = _lockRoute;
    if (route == null) return;
    _lockRoute = null;
    _navigatorKey.currentState?.removeRoute(route);
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
          home: _RootGate(sessionStarted: _sessionStarted),
        );
      },
    );
  }
}

/// 根据保险库状态选择：创建 / 解锁 / 主界面。
///
/// 本次运行解锁过之后，锁定不再把主界面换回解锁页——解锁页是压在最上层的
/// 独立路由（见 [_LockScreen]），主界面保持原状即可。
class _RootGate extends StatelessWidget {
  const _RootGate({required this.sessionStarted});

  final bool sessionStarted;

  @override
  Widget build(BuildContext context) {
    final controller = KeyCaseScope.of(context);
    final status = controller.state.status;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: switch (status) {
        VaultStatus.loading => const _BootSplash(),
        VaultStatus.missing => const CreateVaultPage(),
        VaultStatus.locked =>
          sessionStarted ? const AppShell() : const UnlockPage(),
        VaultStatus.unlocked => const AppShell(),
      },
    );
  }
}

/// 锁屏遮罩：盖住锁定前的页面，只露出解锁表单；系统返回键不能关闭它。
class _LockScreen extends StatelessWidget {
  const _LockScreen();

  @override
  Widget build(BuildContext context) {
    return const PopScope(canPop: false, child: UnlockPage());
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
