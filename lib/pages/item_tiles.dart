import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/models/models.dart';
import '../app/otp/otp.dart';
import '../app/otp/otp_clock.dart';
import '../common_widgets.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';

/// 登录项行。
class KcLoginTile extends StatelessWidget {
  const KcLoginTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
  });

  final VaultItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return _ItemRow(
      item: item,
      onTap: onTap,
      onLongPress: onLongPress,
      trailing: item.favorite
          ? Icon(
              Icons.star_rounded,
              size: 18,
              color: kcSemantic(context, kcWarning),
            )
          : null,
    );
  }
}

/// 令牌行：验证码胶囊 + 倒计时环；点胶囊揭开并复制，点整行进详情。
class KcTokenTile extends StatefulWidget {
  const KcTokenTile({
    super.key,
    required this.item,
    required this.clock,
    required this.showCode,
    required this.showNext,
    required this.grouping,
    required this.onTap,
    this.onLongPress,
  });

  final VaultItem item;
  final OtpClock clock;
  final bool showCode;
  final bool showNext;
  final CodeGrouping grouping;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<KcTokenTile> createState() => _KcTokenTileState();
}

class _KcTokenTileState extends State<KcTokenTile> {
  DateTime? _revealedUntil;
  Timer? _revealTimer;

  bool get _isRevealed =>
      _revealedUntil != null && DateTime.now().isBefore(_revealedUntil!);

  @override
  void didUpdateWidget(covariant KcTokenTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        (widget.showCode && !oldWidget.showCode)) {
      _hideCode(notify: false);
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  void _revealCode() {
    setState(() {
      _revealedUntil = DateTime.now().add(const Duration(seconds: 10));
    });
    _revealTimer?.cancel();
    // 只负责揭开态 10 秒后自动隐藏，不参与验证码计算；OTP ticker 仍只有 OtpClock。
    _revealTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _revealedUntil = null);
    });
  }

  void _hideCode({bool notify = true}) {
    _revealTimer?.cancel();
    _revealTimer = null;
    if (_revealedUntil == null) return;
    if (notify) {
      setState(() => _revealedUntil = null);
    } else {
      _revealedUntil = null;
    }
  }

  void _handleCodeTap(String code, bool visible) {
    if (!visible) _revealCode();
    unawaited(copyToClipboard(context, code));
  }

  @override
  Widget build(BuildContext context) {
    final secret = widget.item.totp;
    if (secret == null) {
      return _ItemRow(
        item: widget.item,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
      );
    }
    final l10n = AppLocalizations.of(context);
    return TapRegion(
      onTapOutside: (_) => _hideCode(),
      child: _ItemRow(
        item: widget.item,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        trailing: ValueListenableBuilder<int>(
          valueListenable: widget.clock.seconds,
          builder: (context, seconds, _) {
            final time = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
            final counter = otpCounterAt(secret, time);
            final code = generateOtpCode(secret: secret, counter: counter);
            final remaining = otpSecondsRemaining(secret, time);
            final visible = widget.showCode || _isRevealed;
            final next = secret.isCounterBased
                ? null
                : nextOtpCode(secret, time);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    KcCodeCapsule(
                      code: formatOtpCode(
                        code,
                        widget.grouping,
                        steam: secret.type == OtpType.steam,
                      ),
                      hidden: !visible,
                      onTap: () => _handleCodeTap(code, visible),
                    ),
                    if (widget.showNext && next != null && visible)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          formatOtpCode(
                            next,
                            widget.grouping,
                            steam: secret.type == OtpType.steam,
                          ),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface
                                    .withValues(alpha: 0.45),
                                fontFeatures: const <FontFeature>[
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                if (secret.isCounterBased)
                  IconButton(
                    tooltip: l10n.detailTokenCounter,
                    onPressed: widget.onTap,
                    icon: const Icon(Icons.numbers_rounded, size: 20),
                  )
                else
                  KcCountdownRing(remaining: remaining, period: secret.period),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.trailing,
  });

  final VaultItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = item.username.trim().isNotEmpty
        ? item.username.trim()
        : (item.urls.isNotEmpty ? item.urls.first : '');
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 列表分组头：字母 + 细分隔线。
class KcLetterHeader extends StatelessWidget {
  const KcLetterHeader({super.key, required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Row(
        children: <Widget>[
          Text(
            letter,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              height: 1,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            ),
          ),
        ],
      ),
    );
  }
}
