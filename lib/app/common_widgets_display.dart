part of '../common_widgets.dart';

// 展示域：头像、验证码胶囊、倒计时环、详情行。

/// 首字母头像。没有品牌图标时用它，颜色由标题哈希决定。
class LetterAvatar extends StatelessWidget {
  const LetterAvatar({
    super.key,
    required this.seed,
    this.size = 38,
    this.radius = 12,
  });

  final String seed;
  final double size;
  final double radius;

  static const List<Color> _palette = <Color>[
    Color(0xFF2563EB),
    Color(0xFF0E8C8C),
    Color(0xFF7C3AED),
    Color(0xFFD97706),
    Color(0xFFDB2777),
    Color(0xFF1F9D55),
  ];

  @override
  Widget build(BuildContext context) {
    final trimmed = seed.trim();
    final letter = trimmed.isEmpty
        ? '?'
        : trimmed.characters.first.toUpperCase();
    final color = _palette[trimmed.hashCode.abs() % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: color,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// 条目列表左侧的图标容器：优先品牌图标，匹配不到再用首字母头像。
class KcItemIcon extends StatelessWidget {
  const KcItemIcon({super.key, required this.item, this.size = 38});

  final VaultItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AegisIconPack.instance.loaded,
      builder: (context, _, _) {
        final name = AegisIconPack.instance.resolve(item);
        if (name != null) {
          return AegisIcon(name: name, size: size);
        }
        return LetterAvatar(seed: item.displayTitle, size: size);
      },
    );
  }
}

/// 验证码胶囊：等宽数字 + 点击复制。
class KcCodeCapsule extends StatelessWidget {
  const KcCodeCapsule({
    super.key,
    required this.code,
    required this.onTap,
    this.hidden = false,
    this.failed = false,
  });

  final String code;
  final VoidCallback onTap;
  final bool hidden;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = failed
        ? kcSemantic(context, kcDanger)
        : theme.colorScheme.onSurface;
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(kcRadiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(kcRadiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            hidden ? hiddenOtpCode(code) : code,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

/// 倒计时环：剩余比例画弧，最后 5 秒转成警示色。
class KcCountdownRing extends StatelessWidget {
  const KcCountdownRing({
    super.key,
    required this.remaining,
    required this.period,
    this.size = 26,
    this.stroke = 3,
  });

  final int remaining;
  final int period;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = period <= 0 ? 0.0 : (remaining / period).clamp(0.0, 1.0);
    final urgent = remaining <= 5;
    final color = urgent
        ? kcSemantic(context, kcDanger)
        : theme.colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          color: color,
          trackColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
          stroke: stroke,
        ),
        child: Center(
          child: Text(
            '$remaining',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.34,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}

/// 详情页的一行：图标 + 标签 + 值 + 复制。
class KcDetailRow extends StatelessWidget {
  const KcDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.onCopy,
    this.onTap,
    this.obscure = false,
    this.trailing,
    this.monospace = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final VoidCallback? onCopy;
  final VoidCallback? onTap;
  final bool obscure;
  final Widget? trailing;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return InkWell(
      borderRadius: BorderRadius.circular(kcRadiusMd),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
            ),
            Expanded(
              child: Text(
                obscure ? '••••••••' : value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontFeatures: monospace
                      ? const <FontFeature>[FontFeature.tabularFigures()]
                      : null,
                  letterSpacing: monospace ? 0.6 : 0,
                ),
              ),
            ),
            ?trailing,
            if (onCopy != null)
              IconButton(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: AppLocalizations.of(context).actionCopy,
              ),
          ],
        ),
      ),
    );
  }
}
