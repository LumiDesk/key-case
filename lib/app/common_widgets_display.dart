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
    final custom = item.icon;
    if (custom != null && custom.isCustom) {
      final bytes = custom.imageBytes;
      if (bytes != null && bytes.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.24),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) =>
                LetterAvatar(seed: item.displayTitle, size: size),
          ),
        );
      }
    }
    return ValueListenableBuilder<bool>(
      valueListenable: IconPacks.instance.loaded,
      builder: (context, _, _) {
        final ref = IconPacks.instance.resolve(item);
        if (ref != null) {
          return KcBrandIcon(ref: ref, size: size);
        }
        return LetterAvatar(seed: item.displayTitle, size: size);
      },
    );
  }
}

/// 验证码换码动效。设置里的 [CodeAnimation] 在页面层映射成它。
enum KcCodeEffect { none, fade, roll, dust }

/// 把用户偏好映射成具体的换码动效。
KcCodeEffect kcCodeEffectOf(CodeAnimation animation) => switch (animation) {
  CodeAnimation.off => KcCodeEffect.none,
  CodeAnimation.dust => KcCodeEffect.dust,
  CodeAnimation.roll => KcCodeEffect.roll,
};

/// 会随内容切换做过渡的验证码文本。
///
/// - [KcCodeEffect.roll]：旧码上移淡出、新码从下方推入（记分牌）。
/// - [KcCodeEffect.dust]：旧码逐字飘散淡出，新码淡入。
/// - [KcCodeEffect.fade]：只做淡入淡出。
///
/// 系统开启「移除动画」时一律降级成直接替换。
class KcAnimatedCode extends StatefulWidget {
  const KcAnimatedCode({
    super.key,
    required this.text,
    required this.style,
    this.effect = KcCodeEffect.none,
    this.fadeOnly = false,
  });

  final String text;
  final TextStyle? style;
  final KcCodeEffect effect;

  /// 辅助行（下一组）只淡入，不参与飘散/滚动。
  final bool fadeOnly;

  @override
  State<KcAnimatedCode> createState() => _KcAnimatedCodeState();
}

class _KcAnimatedCodeState extends State<KcAnimatedCode>
    with SingleTickerProviderStateMixin {
  static const Duration _rollDuration = Duration(milliseconds: 300);
  static const Duration _dustDuration = Duration(milliseconds: 460);
  static const Duration _fadeDuration = Duration(milliseconds: 180);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _rollDuration,
  );

  String? _previous;
  KcCodeEffect _effect = KcCodeEffect.none;
  String? _particleText;
  List<({String char, double left, double top})> _particles =
      const <({String char, double left, double top})>[];

  @override
  void didUpdateWidget(covariant KcAnimatedCode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text) return;
    final effect = _resolveEffect();
    if (effect == KcCodeEffect.none) {
      _previous = null;
      _controller.reset();
      return;
    }
    // 这里正处在重建阶段，直接改字段即可，不需要 setState。
    _previous = oldWidget.text;
    _effect = effect;
    _particleText = null;
    _controller
      ..duration = switch (effect) {
        KcCodeEffect.dust => _dustDuration,
        KcCodeEffect.roll => _rollDuration,
        _ => _fadeDuration,
      }
      ..forward(from: 0).whenComplete(() {
        if (!mounted) return;
        setState(() => _previous = null);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  KcCodeEffect _resolveEffect() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return KcCodeEffect.none;
    // 关闭动效时连下一组的淡入也不做，保持完全静态的替换。
    if (widget.effect == KcCodeEffect.none) return KcCodeEffect.none;
    if (widget.fadeOnly) return KcCodeEffect.fade;
    return widget.effect;
  }

  @override
  Widget build(BuildContext context) {
    final previous = _previous;
    if (previous == null) {
      return Text(widget.text, style: widget.style);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        // 新码本身作为 Stack 的定尺寸层：不额外放占位 Text，避免同一段文字
        // 在树上出现两份（无障碍与测试都会读两次）。
        final incoming = _effect == KcCodeEffect.dust
            ? Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Text(widget.text, style: widget.style),
              )
            : _buildIncoming(t);
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: <Widget>[
            incoming,
            Positioned.fill(
              child: IgnorePointer(child: _buildOutgoing(context, previous, t)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOutgoing(BuildContext context, String previous, double t) {
    switch (_effect) {
      case KcCodeEffect.roll:
        return Transform.translate(
          offset: Offset(0, -_lineHeight * t),
          child: Opacity(
            opacity: (1 - t).clamp(0.0, 1.0),
            child: Text(previous, style: widget.style),
          ),
        );
      case KcCodeEffect.dust:
        return Stack(
          key: const ValueKey<String>('code_dust_particles'),
          clipBehavior: Clip.none,
          children: _dustParticles(context, previous, t),
        );
      case KcCodeEffect.fade:
      case KcCodeEffect.none:
        return Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Text(previous, style: widget.style),
        );
    }
  }

  Widget _buildIncoming(double t) {
    final offset = _effect == KcCodeEffect.roll ? _lineHeight : 4.0;
    return Transform.translate(
      offset: Offset(0, offset * (1 - t)),
      child: Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Text(widget.text, style: widget.style),
      ),
    );
  }

  double get _lineHeight => (widget.style?.fontSize ?? 16) * 1.25;

  List<Widget> _dustParticles(BuildContext context, String text, double t) {
    _ensureParticles(context, text);
    return <Widget>[
      for (var i = 0; i < _particles.length; i++)
        _particle(_particles[i], i, t),
    ];
  }

  Widget _particle(
    ({String char, double left, double top}) particle,
    int index,
    double t,
  ) {
    final driftX = (index.isEven ? 1.0 : -1.0) * (4 + (index % 5) * 1.8);
    final driftY = -(9 + (index % 4) * 4).toDouble();
    return Positioned(
      left: particle.left,
      top: particle.top,
      child: Transform.translate(
        offset: Offset(driftX * t, driftY * t),
        child: Transform.rotate(
          angle: (index % 3 - 1) * 0.08 * t,
          child: Transform.scale(
            scale: 1 - 0.22 * t,
            child: Opacity(
              opacity: (1 - t).clamp(0.0, 1.0),
              child: Text(particle.char, style: widget.style),
            ),
          ),
        ),
      ),
    );
  }

  /// 逐字的落点只算一次：动画期间文本与样式都不变。
  void _ensureParticles(BuildContext context, String text) {
    if (_particleText == text && _particles.isNotEmpty) return;
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final particles = <({String char, double left, double top})>[];
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      // 分组空格没有字形，直接丢弃。
      if (char.trim().isEmpty) continue;
      final boxes = painter.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + 1),
      );
      if (boxes.isEmpty) continue;
      final box = boxes.first;
      particles.add((char: char, left: box.left, top: box.top));
    }
    painter.dispose();
    _particleText = text;
    _particles = particles;
  }
}

/// 验证码胶囊：等宽数字 + 点击复制。
class KcCodeCapsule extends StatelessWidget {
  const KcCodeCapsule({
    super.key,
    required this.code,
    required this.onTap,
    this.hidden = false,
    this.effect = KcCodeEffect.none,
  });

  final String code;
  final VoidCallback onTap;
  final bool hidden;

  /// 换码过渡效果；列表里跟随「换码动画」设置。
  final KcCodeEffect effect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = theme.colorScheme.onSurface;
    return Semantics(
      button: true,
      label: hidden ? l10n.detailShowCode : l10n.actionCopy,
      child: ExcludeSemantics(
        child: Material(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(kcRadiusSm),
          child: InkWell(
            borderRadius: BorderRadius.circular(kcRadiusSm),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: KcAnimatedCode(
                text: hidden ? hiddenOtpCode(code) : code,
                effect: effect,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
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
    return Semantics(
      label: '$remaining s',
      child: ExcludeSemantics(
        child: SizedBox(
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

/// 表单内联错误：与所有页面共用同一套图标、字号与语义色。
class KcInlineError extends StatelessWidget {
  const KcInlineError(this.text, {super.key});

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

/// 图标网格：图标 + 名称 +（非默认包）风格标签。
///
/// 图标选择器与图标库共用同一套格子，避免两处各写一份同构布局。
class KcIconGrid extends StatelessWidget {
  const KcIconGrid({
    super.key,
    required this.icons,
    required this.onIconTap,
    required this.keyPrefix,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
  });

  final List<IconPackIcon> icons;
  final ValueChanged<IconPackIcon> onIconTap;

  /// 格子 key 的前缀，测试与页面用 `<前缀>_<图标标识>` 定位。
  final String keyPrefix;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      // 2 倍字号下格子会被文字撑破；图标名称只做辅助识别，限制放大。
      maxScaleFactor: 1.3,
      child: GridView.builder(
        padding: padding,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 4,
          crossAxisSpacing: 8,
          childAspectRatio: 0.82,
        ),
        itemCount: icons.length,
        itemBuilder: (context, index) => _KcIconCell(
          icon: icons[index],
          cellKey: '${keyPrefix}_${icons[index].ref}',
          onTap: () => onIconTap(icons[index]),
        ),
      ),
    );
  }
}

class _KcIconCell extends StatelessWidget {
  const _KcIconCell({
    required this.icon,
    required this.cellKey,
    required this.onTap,
  });

  final IconPackIcon icon;
  final String cellKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return InkWell(
      key: ValueKey<String>(cellKey),
      borderRadius: BorderRadius.circular(kcRadiusMd),
      onTap: onTap,
      child: Tooltip(
        message: iconTooltip(l10n, icon),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            KcBrandIcon(ref: icon.ref, size: 36),
            const SizedBox(height: 4),
            Text(
              icon.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            if (icon.pack != IconPackId.simple)
              Text(
                packLabel(l10n, icon.pack),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.42),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 详情页的一行：图标 + 标签 + 值 + 复制。
class KcDetailRow extends StatelessWidget {
  const KcDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.onCopy,
    this.onTap,
    this.obscure = false,
    this.trailing,
  });

  final String label;
  final String value;
  final VoidCallback? onCopy;
  final VoidCallback? onTap;
  final bool obscure;
  final Widget? trailing;

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

/// 分组标题 + 卡片内的长文本（备注等）。
///
/// 高度随内容展开、可长按选择复制；不提供复制按钮，避免阅读型长文本旁边
/// 出现操作图标。短字段继续用 [KcDetailRow]。
class KcTextSection extends StatelessWidget {
  const KcTextSection({
    super.key,
    required this.title,
    required this.text,
    this.cardMargin = const EdgeInsets.symmetric(horizontal: 12),
  });

  final String title;
  final String text;
  final EdgeInsetsGeometry cardMargin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        KcSectionLabel(title),
        KcCard(
          margin: cardMargin,
          child: SelectableText(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}
