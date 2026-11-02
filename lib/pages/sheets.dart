import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_theme.dart';
import '../app/feedback.dart';
import '../l10n/app_localizations.dart';

/// 弹层统一入口。
///
/// 页面不得裸写 `showModalBottomSheet`：圆角、拖拽把手、安全区与最大高度必须
/// 一致，否则不同页面会出现三套观感。
Future<T?> showKcSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final theme = Theme.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: kcElevatedSurfaceColor(theme.brightness),
    showDragHandle: true,
    useSafeArea: true,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(kcRadiusXl)),
    ),
    constraints: const BoxConstraints(maxWidth: kcPageMaxWidth),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: builder(sheetContext),
      );
    },
  );
}

/// 二次确认。破坏性操作传 `destructive: true`，按钮会变成警示色。
Future<bool> showKcConfirm({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmLabel,
  bool destructive = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        backgroundColor: kcElevatedSurfaceColor(theme.brightness),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kcRadiusXl),
        ),
        title: Text(title, style: theme.textTheme.titleLarge),
        content: Text(message, style: theme.textTheme.bodyMedium),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: kcSemantic(context, kcDanger),
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel ?? l10n.actionDelete),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// 单行文本输入（重命名、备注等）。取消返回 null。
Future<String?> showKcTextInput({
  required BuildContext context,
  required String title,
  String? initialValue,
  String? hint,
  int maxLines = 1,
  bool obscure = false,
  TextInputType? keyboardType,
}) {
  return showKcSheet<String>(
    context: context,
    builder: (sheetContext) {
      return _TextInputSheet(
        title: title,
        initialValue: initialValue,
        hint: hint,
        maxLines: maxLines,
        obscure: obscure,
        keyboardType: keyboardType,
      );
    },
  );
}

class _TextInputSheet extends StatefulWidget {
  const _TextInputSheet({
    required this.title,
    this.initialValue,
    this.hint,
    this.maxLines = 1,
    this.obscure = false,
    this.keyboardType,
  });

  final String title;
  final String? initialValue;
  final String? hint;
  final int maxLines;
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  State<_TextInputSheet> createState() => _TextInputSheetState();
}

class _TextInputSheetState extends State<_TextInputSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: widget.obscure,
            maxLines: widget.maxLines,
            keyboardType: widget.keyboardType,
            decoration: InputDecoration(hintText: widget.hint),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.actionCancel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_controller.text),
                  child: Text(l10n.actionSave),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 复制到剪贴板并给出轻反馈。全应用统一走这里。
Future<void> copyToClipboard(
  BuildContext context,
  String value, {
  bool feedback = true,
}) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted || !feedback) return;
  final messenger = KcFeedbackScope.maybeOf(context);
  messenger?.show(AppLocalizations.of(context).copied);
}
