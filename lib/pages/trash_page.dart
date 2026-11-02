import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/keycase_controller.dart';
import '../app/keycase_scope.dart';
import '../app/models/models.dart';
import '../app/util/date_format.dart';
import '../common_widgets.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';

/// 回收站：软删除的条目在这里恢复或永久删除。
class TrashPage extends StatelessWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = KeyCaseScope.of(context);
    final l10n = AppLocalizations.of(context);
    final items = <VaultItem>[...controller.state.trashedItems]
      ..sort(
        (a, b) =>
            (b.deletedAt ?? b.updatedAt).compareTo(a.deletedAt ?? a.updatedAt),
      );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: KcPage(
          child: Column(
            children: <Widget>[
              KcSubHeader(
                title: l10n.trashTitle,
                onBack: () => Navigator.of(context).maybePop(),
                actions: <Widget>[
                  if (items.isNotEmpty)
                    TextButton(
                      onPressed: () => _emptyAll(context, l10n, controller),
                      child: Text(
                        l10n.trashEmptyAll,
                        style: TextStyle(color: kcSemantic(context, kcDanger)),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: items.isEmpty
                    ? KcEmptyState(
                        icon: Icons.delete_outline_rounded,
                        title: l10n.trashEmpty,
                        description: l10n.trashEmptyDesc,
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 32),
                        children: <Widget>[
                          KcCard(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: <Widget>[
                                for (
                                  var i = 0;
                                  i < items.length;
                                  i++
                                ) ...<Widget>[
                                  _TrashRow(
                                    key: ValueKey<String>(items[i].id),
                                    item: items[i],
                                    onRestore: () =>
                                        controller.restoreItem(items[i].id),
                                    onPurge: () => _purge(
                                      context,
                                      l10n,
                                      controller,
                                      items[i],
                                    ),
                                  ),
                                  if (i != items.length - 1)
                                    const KcRowDivider(),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _purge(
    BuildContext context,
    AppLocalizations l10n,
    KeyCaseController controller,
    VaultItem item,
  ) async {
    final confirmed = await showKcConfirm(
      context: context,
      title: l10n.trashPurge,
      message: l10n.trashPurgeMessage,
      confirmLabel: l10n.trashPurge,
      destructive: true,
    );
    if (confirmed) {
      await controller.purgeItem(item.id);
    }
  }

  Future<void> _emptyAll(
    BuildContext context,
    AppLocalizations l10n,
    KeyCaseController controller,
  ) async {
    final confirmed = await showKcConfirm(
      context: context,
      title: l10n.trashEmptyAll,
      message: l10n.trashEmptyAllMessage,
      confirmLabel: l10n.trashEmptyAll,
      destructive: true,
    );
    if (confirmed) {
      await controller.emptyTrash();
    }
  }
}

class _TrashRow extends StatelessWidget {
  const _TrashRow({
    super.key,
    required this.item,
    required this.onRestore,
    required this.onPurge,
  });

  final VaultItem item;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      child: Row(
        children: <Widget>[
          KcItemIcon(item: item),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
                if (item.deletedAt != null)
                  Text(
                    formatRelative(context, item.deletedAt!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          TextButton(onPressed: onRestore, child: Text(l10n.actionRestore)),
          IconButton(
            onPressed: onPurge,
            tooltip: l10n.trashPurge,
            icon: Icon(
              Icons.delete_forever_outlined,
              size: 20,
              color: kcSemantic(context, kcDanger),
            ),
          ),
        ],
      ),
    );
  }
}
