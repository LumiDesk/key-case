import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/keycase_scope.dart';
import '../app/messages.dart';
import '../app/security/security_audit.dart';
import '../common_widgets.dart';
import '../l10n/app_localizations.dart';

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
                _StrengthBar(score: score),
                const SizedBox(height: 16),
                KcLabeledField(
                  label: l10n.confirmPassword,
                  controller: _confirm,
                  obscure: _obscure,
                  textInputAction: TextInputAction.done,
                ),
                if (state.error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _AuthError(text: errorText(l10n, state.error!)),
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

class _UnlockPageState extends State<UnlockPage> {
  final TextEditingController _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
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
    await controller.unlockWithBiometrics(reason: l10n.biometricUnlockReason);
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
                    _AuthError(text: errorText(l10n, state.error!)),
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

class _AuthError extends StatelessWidget {
  const _AuthError({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = kcSemantic(context, kcDanger);
    return Row(
      children: <Widget>[
        Icon(Icons.error_outline_rounded, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// 主密码强度：四段小条 + 文字。
class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.score});

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
