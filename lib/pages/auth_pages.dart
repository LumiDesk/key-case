import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/keycase_controller.dart';
import '../app/keycase_scope.dart';
import '../app/messages.dart';
import '../app/password_strength.dart';
import '../app/security/security_audit.dart';
import '../common_widgets.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';

/// 首次启动：创建保险库。
class CreateVaultPage extends StatefulWidget {
  const CreateVaultPage({super.key});

  @override
  State<CreateVaultPage> createState() => _CreateVaultPageState();
}

class _CreateVaultPageState extends State<CreateVaultPage> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = KeyCaseScope.read(context);
    await controller.createVault(
      password: _password.text,
      confirm: _confirm.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = KeyCaseScope.of(context);
    final state = controller.state;
    final l10n = AppLocalizations.of(context);
    final score = masterPasswordScore(_password.text);

    return Scaffold(
      body: SafeArea(
        child: KcPage(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 32, 14, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const _AuthHero(
                  icon: Icons.lock_outline_rounded,
                  titleKey: _AuthTitle.create,
                ),
                const SizedBox(height: 28),
                KcLabeledField(
                  label: l10n.masterPassword,
                  controller: _password,
                  hint: l10n.passwordHint,
                  obscure: _obscure,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                KcPasswordStrengthBar(score: score),
                const SizedBox(height: 16),
                KcLabeledField(
                  label: l10n.confirmPassword,
                  controller: _confirm,
                  obscure: _obscure,
                  textInputAction: TextInputAction.done,
                ),
                if (state.error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  KcInlineError(errorText(l10n, state.error!)),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: state.busy ? null : _submit,
                    child: state.busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.createVault),
                  ),
                ),
                const SizedBox(height: 8),
                _RecoveryActions(mode: _AuthTitle.create),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 解锁页。
class UnlockPage extends StatefulWidget {
  const UnlockPage({super.key});

  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<UnlockPage> with WidgetsBindingObserver {
  final TextEditingController _password = TextEditingController();
  bool _obscure = true;
  bool _autoPromptAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleAutoPrompt();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _password.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleAutoPrompt();
  }

  /// 解锁页出现时自动弹一次指纹；在后台创建则等回到前台再弹。
  void _scheduleAutoPrompt() {
    if (_autoPromptAttempted) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    _autoPromptAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = KeyCaseScope.read(context);
      if (!controller.state.biometricEnrolled || controller.state.busy) return;
      final l10n = AppLocalizations.of(context);
      unawaited(
        controller.unlockWithBiometrics(
          reason: l10n.biometricUnlockReason,
          cancelLabel: l10n.actionCancel,
          hint: l10n.biometricPromptHint,
        ),
      );
    });
  }

  Future<void> _submit() async {
    final controller = KeyCaseScope.read(context);
    await controller.unlock(_password.text);
    if (mounted && !controller.state.isUnlocked) {
      _password.clear();
    }
  }

  Future<void> _biometric() async {
    final controller = KeyCaseScope.read(context);
    final l10n = AppLocalizations.of(context);
    await controller.unlockWithBiometrics(
      reason: l10n.biometricUnlockReason,
      cancelLabel: l10n.actionCancel,
      hint: l10n.biometricPromptHint,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = KeyCaseScope.of(context);
    final state = controller.state;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: KcPage(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 24, 14, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _AuthHero(
                    icon: Icons.key_rounded,
                    titleKey: _AuthTitle.unlock,
                  ),
                  const SizedBox(height: 28),
                  KcLabeledField(
                    label: l10n.masterPassword,
                    controller: _password,
                    obscure: _obscure,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (state.error != null) controller.clearError();
                    },
                    suffix: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                  if (state.error != null) ...<Widget>[
                    const SizedBox(height: 12),
                    KcInlineError(errorText(l10n, state.error!)),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: state.busy ? null : _submit,
                      child: state.busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.unlock),
                    ),
                  ),
                  if (state.biometricEnrolled) ...<Widget>[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: state.busy ? null : _biometric,
                        icon: const Icon(Icons.fingerprint_rounded, size: 22),
                        label: Text(l10n.useBiometric),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kcRadiusMd),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const _RecoveryActions(mode: _AuthTitle.unlock),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _AuthTitle { create, unlock }

/// 锁定/创建页的恢复入口：导入加密备份；已存在库时允许删除重来。
class _RecoveryActions extends StatelessWidget {
  const _RecoveryActions({required this.mode});

  final _AuthTitle mode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: <Widget>[
        TextButton.icon(
          onPressed: () => _restoreFromBackup(context),
          icon: const Icon(Icons.settings_backup_restore_rounded, size: 18),
          label: Text(l10n.restoreFromBackup),
        ),
        if (mode == _AuthTitle.unlock)
          TextButton(
            onPressed: () => _deleteVault(context),
            style: TextButton.styleFrom(
              foregroundColor: kcSemantic(context, kcDanger),
            ),
            child: Text(l10n.deleteVaultAction),
          ),
      ],
    );
  }
}

Future<void> _restoreFromBackup(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final controller = KeyCaseScope.read(context);
  final bytes = await controller.pickBackupFile(label: l10n.importBackupTitle);
  if (bytes == null || !context.mounted) return;
  final confirmed = await showKcConfirm(
    context: context,
    title: l10n.restoreFromBackup,
    message: l10n.restoreBackupMessage,
    confirmLabel: l10n.restoreFromBackup,
  );
  if (!confirmed || !context.mounted) return;
  final password = await showKcTextInput(
    context: context,
    title: l10n.importBackupTitle,
    hint: l10n.importBackupPassword,
    obscure: true,
  );
  if (password == null || password.isEmpty || !context.mounted) return;
  await controller.importBackup(bytes: bytes, password: password);
}

Future<void> _deleteVault(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final controller = KeyCaseScope.read(context);
  final confirmed = await showKcConfirm(
    context: context,
    title: l10n.settingsDeleteVault,
    message: l10n.settingsDeleteVaultMessage,
    confirmLabel: l10n.deleteVaultAction,
    destructive: true,
  );
  if (confirmed) await controller.deleteVault();
}

class _AuthHero extends StatelessWidget {
  const _AuthHero({required this.icon, required this.titleKey});

  final IconData icon;
  final _AuthTitle titleKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (title, subtitle) = switch (titleKey) {
      _AuthTitle.create => (l10n.createTitle, l10n.createSubtitle),
      _AuthTitle.unlock => (l10n.unlockTitle, l10n.unlockSubtitle),
    };
    return Column(
      children: <Widget>[
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(kcRadiusXl),
          ),
          child: Icon(icon, size: 34, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
