import '../app/keycase_controller.dart';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/crypto/base32.dart';
import '../app/keycase_scope.dart';
import '../app/models/models.dart';
import '../app/util/password_generator.dart';
import '../app/util/url_tools.dart';
import '../common_widgets.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';

/// 新建 / 编辑条目。
///
/// 用整页而不是半屏 sheet：字段多、键盘弹出后需要滚动，整页更稳；
/// 未保存返回时统一走「放弃修改？」确认。
class ItemEditorPage extends StatefulWidget {
  const ItemEditorPage({super.key, required this.kind, this.itemId});

  final ItemKind kind;
  final String? itemId;

  @override
  State<ItemEditorPage> createState() => _ItemEditorPageState();
}

class _ItemEditorPageState extends State<ItemEditorPage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _url = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _secret = TextEditingController();

  VaultItem? _original;
  bool _loaded = false;
  bool _obscurePassword = true;
  bool _obscureSecret = true;
  String? _error;

  OtpType _type = OtpType.totp;
  OtpHashAlgorithm _algorithm = OtpHashAlgorithm.sha1;
  int _digits = 6;
  int _period = 30;
  int _counter = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final id = widget.itemId;
    if (id != null) {
      final item = KeyCaseScope.read(context).state.data?.itemById(id);
      if (item != null) {
        _original = item;
        _title.text = item.title;
        _username.text = item.username;
        _password.text = item.password;
        _url.text = item.urls.isNotEmpty ? item.urls.first : '';
        _notes.text = item.notes;
        final totp = item.totp;
        if (totp != null) {
          _secret.text = totp.secret;
          _type = totp.type;
          _algorithm = totp.algorithm;
          _digits = totp.digits;
          _period = totp.period;
          _counter = totp.counter;
        }
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _username.dispose();
    _password.dispose();
    _url.dispose();
    _notes.dispose();
    _secret.dispose();
    super.dispose();
  }

  bool get _isToken => widget.kind == ItemKind.totp;

  bool get _isDirty {
    final original = _original;
    if (original == null) {
      return _title.text.trim().isNotEmpty ||
          _username.text.trim().isNotEmpty ||
          _password.text.isNotEmpty ||
          _url.text.trim().isNotEmpty ||
          _notes.text.trim().isNotEmpty ||
          _secret.text.trim().isNotEmpty;
    }
    if (_title.text != original.title) return true;
    if (_username.text != original.username) return true;
    if (_password.text != original.password) return true;
    if (_url.text != (original.urls.isNotEmpty ? original.urls.first : '')) {
      return true;
    }
    if (_notes.text != original.notes) return true;
    final totp = original.totp;
    if (totp != null) {
      if (_secret.text != totp.secret) return true;
      if (_type != totp.type) return true;
      if (_algorithm != totp.algorithm) return true;
      if (_digits != totp.digits) return true;
      if (_period != totp.period) return true;
      if (_counter != totp.counter) return true;
    }
    return false;
  }

  Future<void> _onBack() async {
    final l10n = AppLocalizations.of(context);
    if (_isDirty) {
      final discard = await showKcConfirm(
        context: context,
        title: l10n.editorDiscardTitle,
        message: l10n.editorDiscardMessage,
        confirmLabel: l10n.editorDiscard,
        destructive: true,
      );
      if (!discard || !mounted) return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final controller = KeyCaseScope.read(context);
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = l10n.editorTitleRequired);
      return;
    }
    final rawUrl = _url.text.trim();
    if (!_isToken && rawUrl.isNotEmpty && normalizeUrl(rawUrl) == null) {
      setState(() => _error = l10n.editorUrlInvalid);
      return;
    }

    final now = DateTime.now().toUtc();
    final original = _original;
    if (_isToken) {
      final secret = normalizeBase32(_secret.text);
      if (secret.isEmpty) {
        setState(() => _error = l10n.editorTokenSecret);
        return;
      }
      try {
        base32Decode(secret);
      } on FormatException {
        setState(() => _error = l10n.editorSecretInvalid);
        return;
      }
      final item = VaultItem(
        id: original?.id ?? '${now.microsecondsSinceEpoch}',
        kind: ItemKind.totp,
        title: title,
        username: _username.text.trim(),
        totp: TotpSecret(
          type: _type,
          secret: secret,
          algorithm: _algorithm,
          digits: _digits,
          period: _period,
          counter: _counter,
        ),
        createdAt: original?.createdAt ?? now,
        updatedAt: now,
        icon: original?.icon,
        favorite: original?.favorite ?? false,
      );
      await controller.saveItem(item);
    } else {
      final item = VaultItem(
        id: original?.id ?? '${now.microsecondsSinceEpoch}',
        kind: ItemKind.login,
        title: title,
        username: _username.text.trim(),
        password: _password.text,
        urls: rawUrl.isEmpty ? const <String>[] : <String>[rawUrl],
        notes: _notes.text.trim(),
        createdAt: original?.createdAt ?? now,
        updatedAt: now,
        icon: original?.icon,
        favorite: original?.favorite ?? false,
      );
      await controller.saveItem(item);
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _generatePassword() {
    final generated = generatePassword(const PasswordGeneratorOptions());
    setState(() {
      _password.text = generated;
      _obscurePassword = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isNew = _original == null;
    final title = _isToken
        ? (isNew ? l10n.editorNewToken : l10n.editorEditToken)
        : (isNew ? l10n.editorNewLogin : l10n.editorEditLogin);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: KcPage(
          child: Column(
            children: <Widget>[
              KcSubHeader(
                title: title,
                onBack: _onBack,
                actions: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton(
                      onPressed: _save,
                      child: Text(
                        l10n.actionSave,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
                  children: <Widget>[
                    if (_error != null) ...<Widget>[
                      _InlineError(text: _error!),
                      const SizedBox(height: 12),
                    ],
                    KcLabeledField(
                      label: _isToken
                          ? l10n.editorTokenIssuer
                          : l10n.editorTitle,
                      controller: _title,
                      hint: l10n.editorTitleHint,
                      autofocus: isNew,
                      onChanged: (_) => setState(() => _error = null),
                    ),
                    const SizedBox(height: 14),
                    KcLabeledField(
                      label: _isToken
                          ? l10n.editorTokenAccount
                          : l10n.editorUsername,
                      controller: _username,
                    ),
                    if (!_isToken) ...<Widget>[
                      const SizedBox(height: 14),
                      KcLabeledField(
                        label: l10n.editorPassword,
                        controller: _password,
                        obscure: _obscurePassword,
                        suffix: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                              ),
                            ),
                            IconButton(
                              onPressed: _generatePassword,
                              tooltip: l10n.editorGenerate,
                              icon: const Icon(Icons.casino_outlined, size: 20),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _generatePassword,
                          icon: const Icon(Icons.autorenew_rounded, size: 18),
                          label: Text(l10n.editorGenerate),
                        ),
                      ),
                      const SizedBox(height: 4),
                      KcLabeledField(
                        label: l10n.editorUrl,
                        controller: _url,
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 14),
                      KcLabeledField(
                        label: l10n.editorNotes,
                        controller: _notes,
                        maxLines: 4,
                      ),
                    ] else ...<Widget>[
                      const SizedBox(height: 14),
                      KcLabeledField(
                        label: l10n.editorTokenSecret,
                        controller: _secret,
                        obscure: _obscureSecret,
                        onChanged: (_) => setState(() => _error = null),
                        suffix: IconButton(
                          onPressed: () =>
                              setState(() => _obscureSecret = !_obscureSecret),
                          icon: Icon(
                            _obscureSecret
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      KcSectionLabel(l10n.editorAdvanced),
                      KcCard(
                        child: Column(
                          children: <Widget>[
                            _ChoiceRow(
                              label: l10n.editorTokenType,
                              value: switch (_type) {
                                OtpType.totp => l10n.tokenTypeTotp,
                                OtpType.hotp => l10n.tokenTypeHotp,
                                OtpType.steam => l10n.tokenTypeSteam,
                              },
                              onTap: () => _pickType(l10n),
                            ),
                            const KcRowDivider(indent: 0),
                            _ChoiceRow(
                              label: l10n.editorAlgorithm,
                              value: _algorithm.name.toUpperCase(),
                              onTap: () => _pickAlgorithm(l10n),
                            ),
                            const KcRowDivider(indent: 0),
                            _ChoiceRow(
                              label: l10n.editorDigits,
                              value: '$_digits',
                              onTap: () => _pickDigits(l10n),
                            ),
                            if (_type != OtpType.hotp) ...<Widget>[
                              const KcRowDivider(indent: 0),
                              _ChoiceRow(
                                label: l10n.editorPeriod,
                                value: '$_period s',
                                onTap: () => _pickPeriod(l10n),
                              ),
                            ],
                            if (_type == OtpType.hotp) ...<Widget>[
                              const KcRowDivider(indent: 0),
                              _ChoiceRow(
                                label: l10n.editorCounter,
                                value: '$_counter',
                                onTap: () async {
                                  final value = await showKcTextInput(
                                    context: context,
                                    title: l10n.editorCounter,
                                    initialValue: '$_counter',
                                    keyboardType: TextInputType.number,
                                  );
                                  final parsed = int.tryParse(value ?? '');
                                  if (parsed != null && parsed >= 0) {
                                    setState(() => _counter = parsed);
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickType(AppLocalizations l10n) async {
    final value = await showKcOptionSheet<OtpType>(
      context: context,
      title: l10n.editorTokenType,
      selected: _type,
      options: <({OtpType value, String label})>[
        (value: OtpType.totp, label: l10n.tokenTypeTotp),
        (value: OtpType.hotp, label: l10n.tokenTypeHotp),
        (value: OtpType.steam, label: l10n.tokenTypeSteam),
      ],
    );
    if (value != null) {
      setState(() {
        _type = value;
        if (value == OtpType.steam) _digits = 5;
      });
    }
  }

  Future<void> _pickAlgorithm(AppLocalizations l10n) async {
    final value = await showKcOptionSheet<OtpHashAlgorithm>(
      context: context,
      title: l10n.editorAlgorithm,
      selected: _algorithm,
      options: <({OtpHashAlgorithm value, String label})>[
        for (final algorithm in OtpHashAlgorithm.values)
          (value: algorithm, label: algorithm.name.toUpperCase()),
      ],
    );
    if (value != null) setState(() => _algorithm = value);
  }

  Future<void> _pickDigits(AppLocalizations l10n) async {
    final value = await showKcOptionSheet<int>(
      context: context,
      title: l10n.editorDigits,
      selected: _digits,
      options: const <({int value, String label})>[
        (value: 6, label: '6'),
        (value: 8, label: '8'),
      ],
    );
    if (value != null) setState(() => _digits = value);
  }

  Future<void> _pickPeriod(AppLocalizations l10n) async {
    final value = await showKcOptionSheet<int>(
      context: context,
      title: l10n.editorPeriod,
      selected: _period,
      options: const <({int value, String label})>[
        (value: 30, label: '30'),
        (value: 60, label: '60'),
      ],
    );
    if (value != null) setState(() => _period = value);
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
        child: Row(
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.text});

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
