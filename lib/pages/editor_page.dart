import '../app/keycase_controller.dart';

import 'package:flutter/material.dart';

import '../app/crypto/base32.dart';
import '../app/keycase_scope.dart';
import '../app/models/models.dart';
import '../app/util/password_generator.dart';
import '../app/util/url_tools.dart';
import '../common_widgets.dart';
import '../l10n/app_localizations.dart';
import 'icon_picker_sheet.dart';
import 'sheets.dart';

/// 新建 / 编辑条目。
///
/// 用整页而不是半屏 sheet：字段多、键盘弹出后需要滚动，整页更稳；
/// 未保存返回时统一走「放弃修改？」确认。
///
/// 新建时可以用 [initialDraft] 预填字段（扫码添加令牌走这条路）：草稿只是
/// 表单初值，页面不会自动保存，用户点「保存」才真正写入保险库。
class ItemEditorPage extends StatefulWidget {
  const ItemEditorPage({
    super.key,
    required this.kind,
    this.itemId,
    this.initialDraft,
  });

  final ItemKind kind;
  final String? itemId;

  /// 仅新建时生效；与 [itemId] 同时传入时以编辑中的条目为准。
  final VaultItem? initialDraft;

  @override
  State<ItemEditorPage> createState() => _ItemEditorPageState();
}

class _ItemEditorPageState extends State<ItemEditorPage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _urls = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _secret = TextEditingController();

  VaultItem? _original;
  IconRef? _icon;
  bool _loaded = false;

  /// 页面打开时的字段初值；用来判断有没有未保存的修改。
  _EditorSnapshot? _baseline;
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
    final item = id == null
        ? null
        : KeyCaseScope.read(context).state.data?.itemById(id);
    if (item != null) {
      _original = item;
      _applyItem(item);
    } else {
      final draft = widget.initialDraft;
      if (draft != null) _applyItem(draft);
    }
    _baseline = _snapshot();
  }

  void _applyItem(VaultItem item) {
    _icon = item.icon;
    _title.text = item.title;
    _username.text = item.username;
    _password.text = item.password;
    _urls.text = item.urls.join('\n');
    _notes.text = item.notes;
    final totp = item.totp;
    if (totp == null) return;
    _secret.text = totp.secret;
    _type = totp.type;
    _algorithm = totp.algorithm;
    _digits = totp.digits;
    _period = totp.period;
    _counter = totp.counter;
  }

  @override
  void dispose() {
    _title.dispose();
    _username.dispose();
    _password.dispose();
    _urls.dispose();
    _notes.dispose();
    _secret.dispose();
    super.dispose();
  }

  bool get _isToken => widget.kind == ItemKind.totp;

  _EditorSnapshot _snapshot() => (
    title: _title.text,
    username: _username.text,
    password: _password.text,
    urls: _urls.text,
    notes: _notes.text,
    secret: _secret.text,
    type: _type,
    algorithm: _algorithm,
    digits: _digits,
    period: _period,
    counter: _counter,
    icon: _icon,
  );

  bool get _isDirty => _baseline != null && _snapshot() != _baseline;

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
    final urls = <String>[];
    final seenUrls = <String>{};
    for (final raw in _urls.text.split(RegExp(r'\r?\n'))) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      final normalized = normalizeUrl(value);
      if (normalized == null) {
        setState(() => _error = l10n.editorUrlInvalid);
        return;
      }
      if (seenUrls.add(normalized)) urls.add(normalized);
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
      final item = VaultItem.tokenItem(
        id: original?.id ?? '${now.microsecondsSinceEpoch}',
        title: title,
        token: TokenData(
          secret: TotpSecret(
            type: _type,
            secret: secret,
            algorithm: _algorithm,
            digits: _digits,
            period: _period,
            counter: _counter,
          ),
          account: _username.text.trim(),
          notes: _notes.text.trim(),
        ),
        createdAt: original?.createdAt ?? now,
        updatedAt: now,
        icon: _icon,
        favorite: original?.favorite ?? false,
      );
      await controller.saveItem(item);
    } else {
      final item = VaultItem.loginItem(
        id: original?.id ?? '${now.microsecondsSinceEpoch}',
        title: title,
        login: LoginData(
          username: _username.text.trim(),
          password: _password.text,
          urls: urls,
          notes: _notes.text.trim(),
        ),
        createdAt: original?.createdAt ?? now,
        updatedAt: now,
        icon: _icon,
        favorite: original?.favorite ?? false,
      );
      await controller.saveItem(item);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickIcon() async {
    final picked = await showIconPickerSheet(context: context, current: _icon);
    if (picked == null || !mounted) return;
    // 空名字代表「恢复自动匹配」，等价于清掉显式选择。
    setState(
      () => _icon = picked.name.isEmpty && !picked.isCustom ? null : picked,
    );
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
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
                        KcInlineError(_error!),
                        const SizedBox(height: 12),
                      ],
                      KcLabeledField(
                        label: _isToken
                            ? l10n.editorTokenIssuer
                            : l10n.editorTitle,
                        controller: _title,
                        hint: l10n.editorTitleHint,
                        // 扫码预填的草稿已经有内容，不再抢焦点弹键盘。
                        autofocus: isNew && widget.initialDraft == null,
                        onChanged: (_) => setState(() => _error = null),
                      ),
                      const SizedBox(height: 8),
                      _EditorIconRow(
                        icon: _icon,
                        fallbackSeed: _title.text,
                        onTap: _pickIcon,
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
                                icon: const Icon(
                                  Icons.casino_outlined,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        KcLabeledField(
                          label: l10n.editorUrls,
                          controller: _urls,
                          keyboardType: TextInputType.multiline,
                          maxLines: 3,
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
                            onPressed: () => setState(
                              () => _obscureSecret = !_obscureSecret,
                            ),
                            icon: Icon(
                              _obscureSecret
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        KcLabeledField(
                          label: l10n.editorNotes,
                          controller: _notes,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 18),
                        KcSectionLabel(l10n.editorAdvanced),
                        KcCard(
                          child: Column(
                            children: <Widget>[
                              KcMenuRow<OtpType>(
                                title: l10n.editorTokenType,
                                value: switch (_type) {
                                  OtpType.totp => l10n.tokenTypeTotp,
                                  OtpType.hotp => l10n.tokenTypeHotp,
                                  OtpType.steam => l10n.tokenTypeSteam,
                                },
                                values: OtpType.values,
                                selected: _type,
                                idOf: (value) => value.name,
                                labelOf: (value) => switch (value) {
                                  OtpType.totp => l10n.tokenTypeTotp,
                                  OtpType.hotp => l10n.tokenTypeHotp,
                                  OtpType.steam => l10n.tokenTypeSteam,
                                },
                                onSelected: (value) => setState(() {
                                  _type = value;
                                  if (value == OtpType.steam) {
                                    _algorithm = OtpHashAlgorithm.sha1;
                                    _digits = 5;
                                    _period = 30;
                                  } else if (_digits == 5) {
                                    _digits = 6;
                                  }
                                }),
                                dense: true,
                                keyPrefix: 'editor_token_type',
                              ),
                              if (_type != OtpType.steam) ...<Widget>[
                                const KcRowDivider(indent: 0),
                                KcMenuRow<OtpHashAlgorithm>(
                                  title: l10n.editorAlgorithm,
                                  value: _algorithm.name.toUpperCase(),
                                  values: OtpHashAlgorithm.values,
                                  selected: _algorithm,
                                  idOf: (value) => value.name,
                                  labelOf: (value) => value.name.toUpperCase(),
                                  onSelected: (value) =>
                                      setState(() => _algorithm = value),
                                  dense: true,
                                  keyPrefix: 'editor_algorithm',
                                ),
                                const KcRowDivider(indent: 0),
                                KcMenuRow<int>(
                                  title: l10n.editorDigits,
                                  value: '$_digits',
                                  values: const <int>[6, 8],
                                  selected: _digits,
                                  idOf: (value) => '$value',
                                  labelOf: (value) => '$value',
                                  onSelected: (value) =>
                                      setState(() => _digits = value),
                                  dense: true,
                                  keyPrefix: 'editor_digits',
                                ),
                              ],
                              if (_type == OtpType.totp) ...<Widget>[
                                const KcRowDivider(indent: 0),
                                KcMenuRow<int>(
                                  title: l10n.editorPeriod,
                                  value: '$_period s',
                                  values: <int>[
                                    30,
                                    60,
                                    if (_period != 30 && _period != 60) _period,
                                  ],
                                  selected: _period,
                                  idOf: (value) => '$value',
                                  labelOf: (value) => '$value',
                                  onSelected: (value) =>
                                      setState(() => _period = value),
                                  dense: true,
                                  keyPrefix: 'editor_period',
                                ),
                              ],
                              if (_type == OtpType.hotp) ...<Widget>[
                                const KcRowDivider(indent: 0),
                                KcValueRow(
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
      ),
    );
  }
}

/// 编辑页的图标行：预览 + 「选择图标」。
class _EditorIconRow extends StatelessWidget {
  const _EditorIconRow({
    required this.icon,
    required this.fallbackSeed,
    required this.onTap,
  });

  final IconRef? icon;
  final String fallbackSeed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final previewItem = VaultItem.loginItem(
      id: 'preview',
      title: fallbackSeed.trim().isEmpty ? '?' : fallbackSeed.trim(),
      icon: icon,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return KcCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          KcItemIcon(item: previewItem, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context).editorIcon,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}

/// 编辑页字段快照：只用来判断「有没有改过」，不参与保存。
typedef _EditorSnapshot = ({
  String title,
  String username,
  String password,
  String urls,
  String notes,
  String secret,
  OtpType type,
  OtpHashAlgorithm algorithm,
  int digits,
  int period,
  int counter,
  IconRef? icon,
});
