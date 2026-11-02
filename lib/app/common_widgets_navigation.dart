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
/// 收起时只占一个普通 FAB 的位置；展开时动作按钮堆叠在它上方。每个 FAB
/// 都使用唯一 heroTag，避免多按钮同屏时 Hero 冲突。
class KcSpeedDial extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomRight,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      for (var i = 0; i < actions.length; i++) ...<Widget>[
                        FloatingActionButton.extended(
                          key: ValueKey<String>(
                            'kc_speed_dial_${actions[i].id}',
                          ),
                          heroTag: 'kc_speed_dial_${actions[i].id}',
                          onPressed: actions[i].onPressed,
                          icon: Icon(actions[i].icon, size: 20),
                          label: Text(actions[i].label),
                        ),
                        if (i != actions.length - 1) const SizedBox(height: 10),
                      ],
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        FloatingActionButton(
          key: const ValueKey<String>('kc_speed_dial_toggle'),
          heroTag: 'kc_speed_dial_toggle',
          tooltip: expanded ? expandedTooltip : tooltip,
          onPressed: onToggle,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Icon(
              expanded ? Icons.close_rounded : Icons.add_rounded,
              key: ValueKey<bool>(expanded),
            ),
          ),
        ),
      ],
    );
  }
}
