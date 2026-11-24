part of '../common_widgets.dart';

// 导航域：主悬浮按钮与其向上展开的动作组。

/// 速拨动作：图标、标签与点击回调都由调用方提供。
class KcSpeedDialAction {
  const KcSpeedDialAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

/// 主悬浮按钮 + 向上展开的动作组。
///
/// 收起时只占一个普通 FAB 的位置；展开时动作依次缩放淡入并从下方就位，
/// 主按钮的加号旋转 45° 变成叉。每个 FAB 都使用唯一 heroTag，避免多按钮
/// 同屏时 Hero 冲突。
class KcSpeedDial extends StatefulWidget {
  const KcSpeedDial({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.tooltip,
    required this.expandedTooltip,
    required this.actions,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final String tooltip;
  final String expandedTooltip;
  final List<KcSpeedDialAction> actions;

  @override
  State<KcSpeedDial> createState() => _KcSpeedDialState();
}

class _KcSpeedDialState extends State<KcSpeedDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 160),
  );

  @override
  void initState() {
    super.initState();
    if (widget.expanded) _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant KcSpeedDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded == widget.expanded) return;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.value = widget.expanded ? 1 : 0;
      return;
    }
    if (widget.expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _buildActions(),
        ),
        FloatingActionButton(
          key: const ValueKey<String>('kc_speed_dial_toggle'),
          heroTag: 'kc_speed_dial_toggle',
          tooltip: widget.expanded ? widget.expandedTooltip : widget.tooltip,
          onPressed: widget.onToggle,
          child: AnimatedBuilder(
            animation: _controller,
            // 加号转 45° 就是叉，比换图标更连贯。
            builder: (context, _) => Transform.rotate(
              angle: _controller.value * math.pi / 4,
              child: const Icon(Icons.add_rounded),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    final t = _controller.value;
    if (t == 0) return const SizedBox.shrink();
    final eased = Curves.easeOutCubic.transform(t);
    return IgnorePointer(
      ignoring: t < 0.5,
      child: ClipRect(
        child: Align(
          alignment: Alignment.bottomRight,
          heightFactor: eased,
          child: Padding(
            padding: EdgeInsets.only(bottom: 12 * eased),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (var i = 0; i < widget.actions.length; i++) ...<Widget>[
                  _actionButton(i, t),
                  if (i != widget.actions.length - 1)
                    SizedBox(height: 10 * eased),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(int index, double t) {
    // 自下而上错位入场：靠近主按钮的动作先就位。
    final start = index * 0.12;
    final local = ((t - start) / (1 - start)).clamp(0.0, 1.0);
    final curved = Curves.easeOutCubic.transform(local);
    final action = widget.actions[index];
    return Opacity(
      opacity: curved,
      child: Transform.translate(
        offset: Offset(0, (1 - curved) * 16),
        child: Transform.scale(
          scale: 0.86 + 0.14 * curved,
          alignment: Alignment.centerRight,
          child: FloatingActionButton.extended(
            key: ValueKey<String>('kc_speed_dial_${action.id}'),
            heroTag: 'kc_speed_dial_${action.id}',
            onPressed: action.onPressed,
            icon: Icon(action.icon, size: 20),
            label: Text(action.label),
          ),
        ),
      ),
    );
  }
}
