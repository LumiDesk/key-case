import 'package:flutter/material.dart';

import '../app/keycase_scope.dart';
import '../app/models/models.dart';
import '../app/security/security_audit.dart';
import '../common_widgets.dart';
import '../l10n/app_localizations.dart';
import 'detail_page.dart';
import 'item_tiles.dart';

/// 安全中心：弱密码 / 重复密码 / 长期未更新。
class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = KeyCaseScope.of(context);
    final l10n = AppLocalizations.of(context);
    final issues = auditVault(controller.state.activeItems);
    final grouped = <SecurityIssueKind, List<SecurityIssue>>{};
    for (final issue in issues) {
      grouped.putIfAbsent(issue.kind, () => <SecurityIssue>[]).add(issue);
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: KcPage(
          child: Column(
            children: <Widget>[
              KcSubHeader(
                title: l10n.securityTitle,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: issues.isEmpty
                    ? KcEmptyState(
                        icon: Icons.verified_user_outlined,
                        title: l10n.securityAllGood,
                        description: l10n.securityAllGoodDesc,
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 32),
                        children: <Widget>[
                          for (final kind in SecurityIssueKind.values)
                            if (grouped[kind] != null)
                              _IssueSection(kind: kind, issues: grouped[kind]!),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IssueSection extends StatelessWidget {
  const _IssueSection({required this.kind, required this.issues});

  final SecurityIssueKind kind;
  final List<SecurityIssue> issues;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (title, description, icon) = switch (kind) {
      SecurityIssueKind.weak => (
        l10n.securityWeak,
        l10n.securityWeakDesc,
        Icons.password_rounded,
      ),
      SecurityIssueKind.reused => (
        l10n.securityReused,
        l10n.securityReusedDesc,
        Icons.content_copy_rounded,
      ),
      SecurityIssueKind.stale => (
        l10n.securityStale,
        l10n.securityStaleDesc,
        Icons.schedule_rounded,
      ),
    };

    final uniqueItems = <String, VaultItem>{};
    for (final issue in issues) {
      for (final item in issue.items) {
        uniqueItems[item.id] = item;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        KcSectionLabel('$title · ${uniqueItems.length}'),
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 0, 26, 8),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  description,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        ),
        KcCard(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              for (var i = 0; i < uniqueItems.values.length; i++) ...<Widget>[
                KcLoginTile(
                  key: ValueKey<String>(
                    '${kind.name}_${uniqueItems.values.elementAt(i).id}',
                  ),
                  item: uniqueItems.values.elementAt(i),
                  onTap: () => _open(context, uniqueItems.values.elementAt(i)),
                ),
                if (i != uniqueItems.values.length - 1) const KcRowDivider(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _open(BuildContext context, VaultItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ItemDetailPage(itemId: item.id)),
    );
  }
}
