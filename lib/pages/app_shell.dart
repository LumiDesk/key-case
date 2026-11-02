import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/feedback.dart';
import '../app/keycase_scope.dart';
import '../app/models/models.dart';
import '../common_widgets.dart';
import '../l10n/app_localizations.dart';
import 'detail_page.dart';
import 'editor_page.dart';
import 'home_page.dart';
import 'list_pages.dart';
import 'scan_page.dart';
import 'search_page.dart';
import 'security_page.dart';
import 'settings_page.dart';
import 'trash_page.dart';

/// 已解锁后的主壳：四个根页面 + 底部导航。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final PageController _pages = PageController();
  int _index = 0;
  bool _tokenDialOpen = false;

  /// 首页第一次返回后的退出确认窗口；窗口内再次返回才退出应用。
  bool _exitArmed = false;
  Timer? _exitArmTimer;

  @override
  void dispose() {
    _exitArmTimer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _resetExitArm() {
    _exitArmTimer?.cancel();
    _exitArmTimer = null;
    _exitArmed = false;
  }

  void _goTo(int index) {
    _resetExitArm();
    setState(() {
      _index = index;
      _tokenDialOpen = false;
    });
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  void _closeTokenDial() {
    if (!_tokenDialOpen) return;
    setState(() => _tokenDialOpen = false);
  }

  /// 系统返回键：外部页面由各自路由处理；这里只处理主壳。
  void _handleBack(bool didPop, Object? result) {
    if (didPop) return;
    if (_tokenDialOpen) {
      _closeTokenDial();
      return;
    }
    if (_index != 0) {
      _resetExitArm();
      _goTo(0);
      return;
    }
    if (_exitArmed) {
      _resetExitArm();
      unawaited(SystemNavigator.pop());
      return;
    }
    _exitArmed = true;
    _exitArmTimer?.cancel();
    _exitArmTimer = Timer(const Duration(seconds: 2), _resetExitArm);
    KcFeedbackScope.maybeOf(context)
        ?.show(AppLocalizations.of(context).pressBackAgainToExit);
  }

  Future<void> _openItem(VaultItem item) async {
    _resetExitArm();
    _closeTokenDial();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ItemDetailPage(itemId: item.id)),
    );
  }

  Future<void> _openSearch() async {
    _resetExitArm();
    _closeTokenDial();
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SearchPage()));
  }

  Future<void> _openEditor({
    ItemKind kind = ItemKind.login,
    String? itemId,
  }) async {
    _resetExitArm();
    _closeTokenDial();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ItemEditorPage(kind: kind, itemId: itemId),
      ),
    );
  }

  void _openTokenScan() {
    _resetExitArm();
    _closeTokenDial();
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const TokenScanPage()));
  }

  void _openManualToken() {
    _resetExitArm();
    _closeTokenDial();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ItemEditorPage(kind: ItemKind.totp),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = KeyCaseScope.of(context);
    final l10n = AppLocalizations.of(context);

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: _handleBack,
      child: Scaffold(
        body: Stack(
          children: <Widget>[
            PageView(
              controller: _pages,
              onPageChanged: (index) {
                _resetExitArm();
                setState(() {
                  _index = index;
                  _tokenDialOpen = false;
                });
              },
              children: <Widget>[
                HomePage(
                  onOpenItem: _openItem,
                  onOpenSearch: _openSearch,
                  onOpenSecurity: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SecurityPage(),
                    ),
                  ),
                  onBrowseLogins: () => _goTo(1),
                ),
                LoginsPage(onOpenItem: _openItem, onAdd: _openEditor),
                TokensPage(
                  onOpenItem: _openItem,
                  onAdd: _openManualToken,
                  onScan: _openTokenScan,
                ),
                SettingsPage(
                  onLock: controller.lock,
                  onOpenTrash: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const TrashPage()),
                  ),
                  onOpenSecurity: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SecurityPage(),
                    ),
                  ),
                ),
              ],
            ),
            if (_tokenDialOpen)
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey<String>('token_dial_barrier'),
                  behavior: HitTestBehavior.translucent,
                  onTap: _closeTokenDial,
                ),
              ),
          ],
        ),
        floatingActionButton: switch (_index) {
          1 => FloatingActionButton(
            key: const ValueKey<String>('login_add_fab'),
            heroTag: 'login_add_fab',
            onPressed: () => _openEditor(),
            tooltip: l10n.editorNewLogin,
            child: const Icon(Icons.add_rounded),
          ),
          2 => KcSpeedDial(
            expanded: _tokenDialOpen,
            onToggle: () => setState(() => _tokenDialOpen = !_tokenDialOpen),
            tooltip: l10n.editorNewToken,
            expandedTooltip: l10n.actionClose,
            actions: <KcSpeedDialAction>[
              KcSpeedDialAction(
                id: 'scan',
                label: l10n.tokenAddScan,
                icon: Icons.qr_code_scanner_rounded,
                onPressed: _openTokenScan,
              ),
              KcSpeedDialAction(
                id: 'manual',
                label: l10n.tokenAddManual,
                icon: Icons.keyboard_rounded,
                onPressed: _openManualToken,
              ),
            ],
          ),
          _ => null,
        },
        bottomNavigationBar: _buildNav(l10n),
      ),
    );
  }

  Widget _buildNav(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: NavigationBar(
        height: 64,
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.12),
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: <Widget>[
          _destination(
            Icons.home_outlined,
            Icons.home_rounded,
            l10n.navHome,
            'home',
          ),
          _destination(
            Icons.key_outlined,
            Icons.key_rounded,
            l10n.navLogins,
            'logins',
          ),
          _destination(
            Icons.schedule_outlined,
            Icons.schedule_rounded,
            l10n.navTokens,
            'tokens',
          ),
          _destination(
            Icons.settings_outlined,
            Icons.settings_rounded,
            l10n.navSettings,
            'settings',
          ),
        ],
      ),
    );
  }

  Widget _destination(
    IconData icon,
    IconData selectedIcon,
    String label,
    String keySuffix,
  ) {
    return NavigationDestination(
      key: ValueKey<String>('nav_$keySuffix'),
      icon: Icon(icon),
      selectedIcon: Icon(selectedIcon),
      label: label,
    );
  }
}
