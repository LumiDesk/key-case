import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/keycase_scope.dart';
import '../app/models/models.dart';
import '../app/otp/otp_clock.dart';
import '../app/security/security_audit.dart';
import '../common_widgets.dart';
import '../l10n/app_localizations.dart';
import 'item_tiles.dart';

/// 首页派生数据的缓存：按 `VaultData` 实例失效，避免每次 build 重做审计与排序。
final Expando<_HomeCache> _homeCaches = Expando<_HomeCache>('home');

_HomeCache _cacheFor(VaultData? data) {
  if (data == null) return const _HomeCache.empty();
  return _homeCaches[data] ??= _HomeCache.from(data);
}

class _HomeCache {
  const _HomeCache({
    required this.issues,
    required this.favorites,
    required this.recent,
    required this.activeCount,
  });

  const _HomeCache.empty()
    : issues = 0,
      favorites = const <VaultItem>[],
      recent = const <VaultItem>[],
      activeCount = 0;

  factory _HomeCache.from(VaultData data) {
    final active = data.activeItems;
    final recent = <VaultItem>[...active]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return _HomeCache(
      issues: securityIssueItemCount(active),
      favorites: active.where((item) => item.favorite).toList(growable: false),
      recent: recent.take(5).toList(growable: false),
      activeCount: active.length,
    );
  }

  final int issues;
  final List<VaultItem> favorites;
  final List<VaultItem> recent;
  final int activeCount;
}

/// 首页：概览 + 安全提醒 + 收藏 + 最近更新。
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onOpenItem,
    required this.onOpenSearch,
    required this.onOpenSecurity,
    required this.onBrowseLogins,
  });

  final ValueChanged<VaultItem> onOpenItem;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenSecurity;
  final VoidCallback onBrowseLogins;

  @override
  Widget build(BuildContext context) {
    final controller = KeyCaseScope.of(context);
    final state = controller.state;
    final preferences = controller.preferences;
    final l10n = AppLocalizations.of(context);
    final logins = state.loginItems;
    final tokens = state.tokenItems;
    final cache = _cacheFor(state.data);
    final issues = cache.issues;
    final favorites = cache.favorites;
    final recentItems = cache.recent;
    final isEmpty = cache.activeCount == 0;

    return SafeArea(
      bottom: false,
      child: KcPage(
        child: Column(
          children: <Widget>[
            KcHeader(
              title: l10n.homeTitle,
              subtitle: l10n.homeSubtitle,
              actions: <Widget>[
                IconButton(
                  tooltip: l10n.actionSearch,
                  icon: const Icon(Icons.search_rounded),
                  onPressed: onOpenSearch,
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: <Widget>[
                  _OverviewCard(
                    logins: logins.length,
                    tokens: tokens.length,
                    issues: issues,
                    onOpenSecurity: onOpenSecurity,
                  ),
                  if (isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: KcCard(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 36,
                        ),
                        child: KcEmptyState(
                          icon: Icons.key_outlined,
                          title: l10n.homeEmptyTitle,
                          description: l10n.homeEmptyDesc,
                          action: FilledButton(
                            onPressed: onBrowseLogins,
                            child: Text(l10n.actionAdd),
                          ),
                        ),
                      ),
                    ),
                  if (favorites.isNotEmpty) ...<Widget>[
                    KcSectionLabel(l10n.homeFavorites),
                    _ItemCard(
                      items: favorites.take(4).toList(growable: false),
                      onOpenItem: onOpenItem,
                      preferences: preferences,
                      clock: controller.clock,
                    ),
                  ],
                  if (recentItems.isNotEmpty) ...<Widget>[
                    KcSectionLabel(l10n.homeRecent),
                    _ItemCard(
                      items: recentItems,
                      onOpenItem: onOpenItem,
                      preferences: preferences,
                      clock: controller.clock,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.logins,
    required this.tokens,
    required this.issues,
    required this.onOpenSecurity,
  });

  final int logins;
  final int tokens;
  final int issues;
  final VoidCallback onOpenSecurity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return KcCard(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.homeOverview,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _StatCell(
                  value: '$logins',
                  label: l10n.statLogins,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCell(
                  value: '$tokens',
                  label: l10n.statTokens,
                  color: kcSemantic(context, kcSuccess),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCell(
                  value: '$issues',
                  label: l10n.statSecurity,
                  color: issues > 0
                      ? kcSemantic(context, kcDanger)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(kcRadiusMd),
            onTap: onOpenSecurity,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: <Widget>[
                  Icon(
                    issues > 0
                        ? Icons.shield_outlined
                        : Icons.verified_user_outlined,
                    size: 18,
                    color: issues > 0
                        ? kcSemantic(context, kcWarning)
                        : kcSemantic(context, kcSuccess),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      issues > 0
                          ? l10n.homeSecurityAlert(issues)
                          : l10n.homeAllGood,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.72,
                        ),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(kcRadiusMd),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.items,
    required this.onOpenItem,
    required this.preferences,
    required this.clock,
  });

  final List<VaultItem> items;
  final ValueChanged<VaultItem> onOpenItem;
  final AppPreferences preferences;
  final OtpClock clock;

  @override
  Widget build(BuildContext context) {
    return KcCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (var i = 0; i < items.length; i++) ...<Widget>[
            if (items[i].isToken)
              KcTokenTile(
                key: ValueKey<String>(items[i].id),
                item: items[i],
                clock: clock,
                showCode: preferences.showTokenCodes,
                showNext: preferences.showNextToken,
                grouping: preferences.codeGrouping,
                onTap: () => onOpenItem(items[i]),
              )
            else
              KcLoginTile(
                key: ValueKey<String>(items[i].id),
                item: items[i],
                onTap: () => onOpenItem(items[i]),
              ),
            if (i != items.length - 1) const KcRowDivider(),
          ],
        ],
      ),
    );
  }
}
