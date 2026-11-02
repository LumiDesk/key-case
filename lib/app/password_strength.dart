import 'package:flutter/material.dart';

import 'app_theme.dart';
import '../l10n/app_localizations.dart';

/// 主密码强度条：四段小条 + 文字。创建页与改密对话框共用同一条。
class KcPasswordStrengthBar extends StatelessWidget {
  const KcPasswordStrengthBar({super.key, required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = switch (score) {
      <= 1 => kcSemantic(context, kcDanger),
      2 => kcSemantic(context, kcWarning),
      _ => kcSemantic(context, kcSuccess),
    };
    final label = switch (score) {
      <= 1 => l10n.strengthWeak,
      2 => l10n.strengthFair,
      3 => l10n.strengthGood,
      _ => l10n.strengthStrong,
    };
    return Row(
      children: <Widget>[
        for (var i = 0; i < 4; i++) ...<Widget>[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 4,
              decoration: BoxDecoration(
                color: i < score
                    ? color
                    : theme.colorScheme.onSurface.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (i < 3) const SizedBox(width: 4),
        ],
        const SizedBox(width: 10),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
