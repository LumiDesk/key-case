import 'package:anchored_menu/anchored_menu.dart';
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/keycase_scope.dart';
import '../app/models/models.dart';
import '../app/otp/otp.dart';
import '../app/otp/otp_clock.dart';
import '../app/vault/vault_query.dart';
import '../common_widgets.dart';
import '../l10n/app_localizations.dart';
import 'item_tiles.dart';
import 'scan_page.dart';
import 'search_page.dart';

/// 登录项列表。
class LoginsPage extends StatefulWidget {
  const LoginsPage({super.key, required this.onOpenItem, required this.onAdd});

  final ValueChanged<VaultItem> onOpenItem;
  final VoidCallback onAdd;

  @override
  State<LoginsPage> createState() => _LoginsPageState();
}

class _LoginsPageState extends State<LoginsPage> {
  ItemSort _sort = ItemSort.name;

  @override
  Widget build(BuildContext context) {
    final controller = KeyCaseScope.of(context);
    final items = sortItems(controller.state.loginItems, _sort);
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      bottom: false,
      child: KcPage(
        child: Column(
          children: <Widget>[
            KcHeader(
              title: l10n.loginsTitle,
              subtitle: '${items.length}',
              actions: <Widget>[
                IconButton(
                  tooltip: l10n.actionSearch,
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const SearchPage()),
                  ),
                ),
                _SortMenu(
                  sort: _sort,
                  onChanged: (value) => setState(() => _sort = value),
                ),
              ],
            ),
            Expanded(
              child: items.isEmpty
                  ? KcEmptyState(
                      icon: Icons.key_outlined,
                      title: l10n.loginsEmpty,
                      description: l10n.loginsEmptyDesc,
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 96),
                      children: _buildGroups(items, l10n),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroups(List<VaultItem> items, AppLocalizations l10n) {
    final groups = groupByInitial(items);
    return <Widget>[
      for (final group in groups) ...<Widget>[
        KcLetterHeader(letter: group.letter),
        KcCard(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              for (var i = 0; i < group.items.length; i++) ...<Widget>[
                KcLoginTile(
                  key: ValueKey<String>(group.items[i].id),
                  item: group.items[i],
                  onTap: () => widget.onOpenItem(group.items[i]),
                ),
                if (i != group.items.length - 1) const KcRowDivider(),
              ],
            ],
          ),
        ),
      ],
    ];
  }
}

/// 令牌列表。
class TokensPage extends StatefulWidget {
  const TokensPage({
    super.key,
    required this.onOpenItem,
    required this.onAdd,
    required this.onScan,
  });

  final ValueChanged<VaultItem> onOpenItem;
  final VoidCallback onAdd;
  final VoidCallback onScan;

  @override
  State<TokensPage> createState() => _TokensPageState();
}

class _TokensPageState extends State<TokensPage> {
  ItemSort _sort = ItemSort.name;

  @override
  Widget build(BuildContext context) {
    final controller = KeyCaseScope.of(context);
    final preferences = controller.preferences;
    final items = sortItems(controller.state.tokenItems, _sort);
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      bottom: false,
      child: KcPage(
        child: Column(
          children: <Widget>[
            KcHeader(
              title: l10n.tokensTitle,
              subtitle: '${items.length}',
              actions: <Widget>[
                IconButton(
                  tooltip: l10n.actionSearch,
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const SearchPage()),
                  ),
                ),
                _SortMenu(
                  sort: _sort,
                  onChanged: (value) => setState(() => _sort = value),
                ),
              ],
            ),
            if (items.isNotEmpty)
              _TokenTickerBar(clock: controller.clock, items: items),
            Expanded(
              child: items.isEmpty
                  ? KcEmptyState(
                      icon: Icons.schedule_outlined,
                      title: l10n.tokensEmpty,
                      description: l10n.tokensEmptyDesc,
                      action: FilledButton.icon(
                        onPressed: widget.onScan,
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 18,
                        ),
                        label: Text(l10n.editorScanQr),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 96),
                      children: _buildGroups(
                        items,
                        preferences,
                        controller.clock,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroups(
    List<VaultItem> items,
    AppPreferences preferences,
    OtpClock clock,
  ) {
    final groups = groupByInitial(items);
    return <Widget>[
      for (final group in groups) ...<Widget>[
        KcLetterHeader(letter: group.letter),
        KcCard(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              for (var i = 0; i < group.items.length; i++) ...<Widget>[
                KcTokenTile(
                  key: ValueKey<String>(group.items[i].id),
                  item: group.items[i],
                  clock: clock,
                  showCode: preferences.showTokenCodes,
                  showNext: preferences.showNextToken,
                  grouping: preferences.codeGrouping,
                  onTap: () => widget.onOpenItem(group.items[i]),
                ),
                if (i != group.items.length - 1) const KcRowDivider(),
              ],
            ],
          ),
        ),
      ],
    ];
  }
}

/// 令牌列表顶部统一进度条：取最短周期的剩余比例，避免每行各画一条。
class _TokenTickerBar extends StatelessWidget {
  const _TokenTickerBar({required this.clock, required this.items});

  final OtpClock clock;
  final List<VaultItem> items;

  @override
  Widget build(BuildContext context) {
    final secrets = items
        .map((item) => item.totp)
        .whereType<TotpSecret>()
        .where((secret) => !secret.isCounterBased)
        .toList();
    if (secrets.isEmpty) return const SizedBox(height: 6);
    final period = secrets
        .map((secret) => secret.period)
        .reduce((a, b) => a < b ? a : b);

    return ValueListenableBuilder<int>(
      valueListenable: clock.seconds,
      builder: (context, seconds, _) {
        final time = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        final remaining = period - (seconds % period);
        final progress = remaining / period;
        final urgent = remaining <= 5;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.08),
              color: urgent
                  ? kcSemantic(context, kcDanger)
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      },
    );
  }
}

/// 排序菜单：2–8 项静态单选，走外部组件库。
class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.sort, required this.onChanged});

  final ItemSort sort;
  final ValueChanged<ItemSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnchoredMenuChoice<ItemSort>(
      values: ItemSort.values,
      selected: sort,
      idOf: (value) => value.name,
      labelOf: (value) => switch (value) {
        ItemSort.name => l10n.sortByName,
        ItemSort.recent => l10n.sortByRecent,
        ItemSort.favoritesFirst => l10n.sortByFavorites,
      },
      onSelected: onChanged,
      semanticLabel: l10n.actionSort,
      builder: (context, openMenu, menuOpen) => IconButton(
        tooltip: l10n.actionSort,
        onPressed: openMenu,
        isSelected: menuOpen,
        icon: const Icon(Icons.sort_rounded),
      ),
    );
  }
}
