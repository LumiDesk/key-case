import 'package:flutter/material.dart';

import '../app/app_theme.dart';
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
import 'sheets.dart';
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

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    setState(() => _index = index);
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openItem(VaultItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ItemDetailPage(itemId: item.id)),
    );
  }

  Future<void> _openSearch() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SearchPage()));
  }

  Future<void> _openEditor({
    ItemKind kind = ItemKind.login,
    String? itemId,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ItemEditorPage(kind: kind, itemId: itemId),
      ),
    );
  }

  Future<void> _addToken() async {
    final l10n = AppLocalizations.of(context);
    final choice = await showKcOptionSheet<String>(
      context: context,
      title: l10n.editorNewToken,
      options: <({String value, String label})>[
        (value: 'scan', label: l10n.editorScanQr),
        (value: 'manual', label: l10n.actionAdd),
      ],
    );
    if (!mounted || choice == null) return;
    if (choice == 'scan') {
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const TokenScanPage()));
    } else {
      await _openEditor(kind: ItemKind.totp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = KeyCaseScope.of(context);
    final l10n = AppLocalizations.of(context);
    final onTokenTab = _index == 2;

    return Scaffold(
      body: PageView(
        controller: _pages,
        onPageChanged: (index) => setState(() => _index = index),
        children: <Widget>[
          HomePage(
            onOpenItem: _openItem,
            onOpenSearch: _openSearch,
            onOpenSecurity: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SecurityPage()),
            ),
            onBrowseLogins: () => _goTo(1),
          ),
          LoginsPage(onOpenItem: _openItem, onAdd: _openEditor),
          TokensPage(
            onOpenItem: _openItem,
            onAdd: () => _openEditor(kind: ItemKind.totp),
            onScan: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TokenScanPage()),
            ),
          ),
          SettingsPage(
            onLock: controller.lock,
            onOpenTrash: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const TrashPage())),
            onOpenSecurity: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SecurityPage()),
            ),
          ),
        ],
      ),
      floatingActionButton: _index == 1
          ? FloatingActionButton(
              onPressed: () => _openEditor(),
              tooltip: l10n.editorNewLogin,
              child: const Icon(Icons.add_rounded),
            )
          : _index == 2
          ? FloatingActionButton(
              onPressed: _addToken,
              tooltip: l10n.editorNewToken,
              child: const Icon(Icons.add_rounded),
            )
          : null,
      bottomNavigationBar: _buildNav(l10n),
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
