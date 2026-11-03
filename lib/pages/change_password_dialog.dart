import 'package:flutter/material.dart';

import '../app/keycase_controller.dart';
import '../app/keycase_scope.dart';
import '../app/messages.dart';
import '../app/password_strength.dart';
import '../app/security/security_audit.dart';
import '../common_widgets.dart';
import '../l10n/app_localizations.dart';

/// 修改主密码对话框：三字段 + 强度条，与创建页保持同一套视觉。
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final controller = KeyCaseScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await controller.changeMasterPassword(
      currentPassword: _current.text,
      newPassword: _next.text,
      confirmPassword: _confirm.text,
    );
    if (!mounted) return;
    if (!ok) {
      final error = controller.state.error;
      setState(() {
        _busy = false;
        _error = error == null
            ? l10n.errorPasswordIncorrect
            : errorText(l10n, error);
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.changePasswordTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            KcLabeledField(
              label: l10n.currentPassword,
              controller: _current,
              obscure: true,
            ),
            const SizedBox(height: 12),
            KcLabeledField(
              label: l10n.newPassword,
              controller: _next,
              obscure: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            KcPasswordStrengthBar(score: masterPasswordScore(_next.text)),
            const SizedBox(height: 12),
            KcLabeledField(
              label: l10n.confirmNewPassword,
              controller: _confirm,
              obscure: true,
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 10),
              KcInlineError(_error!),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.actionSave),
        ),
      ],
    );
  }
}
