import '../app/keycase_controller.dart';

import 'dart:async';

import 'package:anchored_menu/anchored_menu.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_theme.dart';
import '../app/feedback.dart';
import '../app/keycase_scope.dart';
import '../app/logging/app_logger.dart';
import '../app/models/models.dart';
import '../app/otp/otp.dart';
import '../app/security/security_audit.dart';
import '../app/util/date_format.dart';
import '../app/util/url_tools.dart';
import '../common_widgets.dart';
import '../l10n/app_localizations.dart';
import 'editor_page.dart';
import 'sheets.dart';

/// 条目详情：登录项显示字段，令牌显示大码磁贴。
class ItemDetailPage extends StatefulWidget {
  const ItemDetailPage({super.key, required this.itemId});

  final String itemId;

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  bool _showPassword = false;

  /// 手动揭开验证码的截止时间；到点后自动恢复隐藏。
  DateTime? _revealUntil;
  Timer? _revealTimer;

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  void _openEditor(VaultItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ItemEditorPage(kind: item.kind, itemId: item.id),
      ),
    );
  }

  Future<void> _confirmDelete(VaultItem item) async {
    final l10n = AppLocalizations.of(context);
    final controller = KeyCaseScope.read(context);
    final confirmed = await showKcConfirm(
      context: context,
      title: l10n.detailDelete,
      message: l10n.detailDeleteMessage,
      confirmLabel: l10n.detailDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await controller.deleteItem(item.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = KeyCaseScope.of(context);
    final l10n = AppLocalizations.of(context);
    final item = controller.state.data?.itemById(widget.itemId);
    if (item == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final preferences = controller.preferences;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: KcPage(
          child: Column(
            children: <Widget>[
              KcSubHeader(
                title: item.isToken ? l10n.navTokens : l10n.navLogins,
                onBack: () => Navigator.of(context).maybePop(),
                actions: <Widget>[
                  AnchoredMenuButton(
                    icon: Icons.more_vert_rounded,
                    tooltip: l10n.actionEdit,
                    entries: <AnchoredMenuEntry>[
                      AnchoredMenuItem(
                        id: 'edit',
                        title: l10n.actionEdit,
                        icon: Icons.edit_outlined,
                        onPressed: () => _openEditor(item),
                      ),
                      AnchoredMenuItem(
                        id: 'favorite',
                        title: item.favorite
                            ? l10n.detailUnfavorite
                            : l10n.detailFavorite,
                        icon: item.favorite
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        onPressed: () => controller.toggleFavorite(item.id),
                      ),
                      const AnchoredMenuDivider(),
                      AnchoredMenuItem(
                        id: 'delete',
                        title: l10n.detailDelete,
                        icon: Icons.delete_outline_rounded,
                        foregroundColor: kcSemantic(context, kcDanger),
                        onPressed: () => _confirmDelete(item),
                      ),
                    ],
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
                  children: <Widget>[
                    _DetailHero(item: item),
                    const SizedBox(height: 14),
                    if (item.isToken)
                      TapRegion(
                        onTapOutside: (_) => _hideCode(),
                        child: _TokenPanel(
                          item: item,
                          showCode: preferences.showTokenCodes,
                          showNext: preferences.showNextToken,
                          grouping: preferences.codeGrouping,
                          revealedUntil: _revealUntil,
                          onReveal: _revealFor,
                        ),
                      )
                    else
                      _LoginPanel(
                        item: item,
                        showPassword: _showPassword,
                        onTogglePassword: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                    if (item.isToken) ...<Widget>[
                      KcSectionLabel(l10n.editorAdvanced),
                      KcCard(
                        child: Column(
                          children: <Widget>[
                            KcDetailRow(
                              label: l10n.detailTokenType,
                              value: _typeLabel(item.totp!.type, l10n),
                            ),
                            KcDetailRow(
                              label: l10n.detailTokenAlgorithm,
                              value: item.totp!.algorithm.name.toUpperCase(),
                            ),
                            KcDetailRow(
                              label: l10n.detailTokenDigits,
                              value: '${item.totp!.effectiveDigits}',
                            ),
                            KcDetailRow(
                              label: l10n.detailTokenPeriod,
                              value: '${item.totp!.period}s',
                            ),
                            if (item.totp!.isCounterBased)
                              KcDetailRow(
                                label: l10n.detailTokenCounter,
                                value: '${item.totp!.counter}',
                              ),
                          ],
                        ),
                      ),
                    ],
                    KcSectionLabel(l10n.detailUpdated),
                    KcCard(
                      child: Column(
                        children: <Widget>[
                          KcDetailRow(
                            label: l10n.detailCreated,
                            value: formatDateTime(context, item.createdAt),
                          ),
                          KcDetailRow(
                            label: l10n.detailUpdated,
                            value: formatDateTime(context, item.updatedAt),
                          ),
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

  void _revealFor() {
    setState(() {
      _revealUntil = DateTime.now().add(const Duration(seconds: 10));
    });
    _revealTimer?.cancel();
    _revealTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _revealUntil = null);
    });
  }

  void _hideCode() {
    _revealTimer?.cancel();
    _revealTimer = null;
    if (_revealUntil == null) return;
    setState(() => _revealUntil = null);
  }
}

String _typeLabel(OtpType type, AppLocalizations l10n) => switch (type) {
  OtpType.totp => l10n.tokenTypeTotp,
  OtpType.hotp => l10n.tokenTypeHotp,
  OtpType.steam => l10n.tokenTypeSteam,
};

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.item});

  final VaultItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        KcItemIcon(item: item, size: 56),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall,
              ),
              if (item.username.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    item.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.item,
    required this.showPassword,
    required this.onTogglePassword,
  });

  final VaultItem item;
  final bool showPassword;
  final VoidCallback onTogglePassword;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = KeyCaseScope.read(context);
    return KcCard(
      child: Column(
        children: <Widget>[
          KcDetailRow(
            label: l10n.detailUsername,
            value: item.username,
            onCopy: item.username.isEmpty
                ? null
                : () => copyToClipboard(context, item.username),
          ),
          KcDetailRow(
            label: l10n.detailPassword,
            value: item.password,
            obscure: !showPassword,
            onCopy: item.password.isEmpty
                ? null
                : () => copyToClipboard(context, item.password),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  onPressed: onTogglePassword,
                  tooltip: showPassword
                      ? l10n.detailHideCode
                      : l10n.detailShowCode,
                  icon: Icon(
                    showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                ),
                if (isWeakPassword(item.password))
                  Tooltip(
                    message: l10n.securityWeak,
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: kcSemantic(context, kcWarning),
                    ),
                  ),
              ],
            ),
          ),
          for (final url in item.urls)
            KcDetailRow(
              label: l10n.detailUrl,
              value: displayUrl(url),
              onCopy: () => copyToClipboard(context, url),
              onTap: () => _openUrl(context, url),
            ),
          KcDetailRow(
            label: l10n.detailNotes,
            value: item.notes,
            onCopy: item.notes.isEmpty
                ? null
                : () => copyToClipboard(context, item.notes),
          ),
          if (item.urls.isEmpty && item.notes.isEmpty) const SizedBox.shrink(),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => controller.toggleFavorite(item.id),
              icon: Icon(
                item.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 18,
              ),
              label: Text(
                item.favorite ? l10n.detailUnfavorite : l10n.detailFavorite,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String raw) async {
    final normalized = normalizeUrl(raw);
    if (normalized == null) return;
    try {
      final launched = await launchUrl(
        Uri.parse(normalized),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        KcFeedbackScope.maybeOf(context)
            ?.show(AppLocalizations.of(context).errorOpenLinkFailed);
      }
    } catch (error) {
      AppLogger.warn('open url failed: $error');
      if (context.mounted) {
        KcFeedbackScope.maybeOf(context)
            ?.show(AppLocalizations.of(context).errorOpenLinkFailed);
      }
    }
  }
}

class _TokenPanel extends StatelessWidget {
  const _TokenPanel({
    required this.item,
    required this.showCode,
    required this.showNext,
    required this.grouping,
    required this.revealedUntil,
    required this.onReveal,
  });

  final VaultItem item;
  final bool showCode;
  final bool showNext;
  final CodeGrouping grouping;
  final DateTime? revealedUntil;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final secret = item.totp;
    if (secret == null) return const SizedBox.shrink();
    final controller = KeyCaseScope.of(context);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ValueListenableBuilder<int>(
      valueListenable: controller.clock.seconds,
      builder: (context, seconds, _) {
        final time = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        final revealed =
            revealedUntil != null && DateTime.now().isBefore(revealedUntil!);
        final visible = showCode || revealed;
        final counter = otpCounterAt(secret, time);
        final code = generateOtpCode(secret: secret, counter: counter);
        final remaining = otpSecondsRemaining(secret, time);
        final formatted = formatOtpCode(
          code,
          grouping,
          steam: secret.type == OtpType.steam,
        );
        final next = secret.isCounterBased ? null : nextOtpCode(secret, time);

        return Column(
          children: <Widget>[
            Material(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(kcRadiusLg),
              child: InkWell(
                borderRadius: BorderRadius.circular(kcRadiusLg),
                onTap: () {
                  if (!visible) onReveal();
                  unawaited(copyToClipboard(context, code));
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              visible ? formatted : hiddenOtpCode(formatted),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontSize: 30,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w700,
                                color: visible
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.45,
                                      ),
                                fontFeatures: const <FontFeature>[
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            if (showNext && next != null && visible)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  formatOtpCode(
                                    next,
                                    grouping,
                                    steam: secret.type == OtpType.steam,
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.45),
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              visible ? l10n.actionCopy : l10n.detailShowCode,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (secret.isCounterBased)
                        IconButton.filledTonal(
                          onPressed: () {
                            controller.advanceHotp(item.id);
                          },
                          icon: const Icon(Icons.skip_next_rounded),
                          tooltip: l10n.actionNext,
                        )
                      else
                        KcCountdownRing(
                          remaining: remaining,
                          period: secret.period,
                          size: 44,
                          stroke: 4,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (secret.isCounterBased)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
                child: Row(
                  children: <Widget>[
                    Text(
                      '${l10n.detailTokenCounter}: ${secret.counter}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => controller.advanceHotp(item.id),
                      icon: const Icon(Icons.skip_next_rounded, size: 18),
                      label: Text(l10n.actionNext),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
