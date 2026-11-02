part of '../common_widgets.dart';

// 表单域：设置行、开关行、分段控件、带标签输入框。

/// 设置项：左侧图标 + 标题/副标题 + 右侧尾随控件或 chevron。
class KcSettingsRow extends StatelessWidget {
  const KcSettingsRow({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.destructive = false,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dangerColor = kcSemantic(context, kcDanger);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (destructive ? dangerColor : theme.colorScheme.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: destructive ? dangerColor : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: destructive ? dangerColor : null,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.58,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
          ],
        ),
      ),
    );
  }
}

/// 开关行：点击整行即可切换。
class KcSwitchRow extends StatelessWidget {
  const KcSwitchRow({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return KcSettingsRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

/// 卡片内的分组分隔线：整行穿过图标下方。
class KcRowDivider extends StatelessWidget {
  const KcRowDivider({super.key, this.indent = 58});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: indent,
      endIndent: 14,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
    );
  }
}

/// 静态单选行：2–8 项受控选项统一走锚点菜单。
///
/// [dense] 为 true 时渲染卡片内的「标签 + 当前值 + chevron」紧凑行；
/// 否则渲染设置页的 `KcSettingsRow`。不要为单个页面另写菜单行。
class KcMenuRow<T> extends StatelessWidget {
  const KcMenuRow({
    super.key,
    required this.title,
    required this.value,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.icon,
    this.subtitle,
    this.idOf,
    this.semanticLabel,
    this.trailingColor,
    this.dense = false,
    this.keyPrefix = 'kc_menu',
  });

  final String title;
  final String value;
  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;
  final IconData? icon;
  final String? subtitle;
  final String Function(T value)? idOf;
  final String? semanticLabel;
  final Color? trailingColor;
  final bool dense;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return AnchoredMenuChoice<T>(
      values: values,
      selected: selected,
      idOf: idOf ?? (value) => '$value',
      labelOf: labelOf,
      onSelected: onSelected,
      semanticLabel: semanticLabel ?? title,
      keyPrefix: keyPrefix,
      builder: (context, openMenu, _) => dense
          ? _buildDense(context, openMenu)
          : _buildSetting(context, openMenu),
    );
  }

  Widget _buildSetting(BuildContext context, VoidCallback openMenu) {
    final theme = Theme.of(context);
    return KcSettingsRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: openMenu,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (trailingColor != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: trailingColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.expand_more_rounded,
            size: 20,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }

  Widget _buildDense(BuildContext context, VoidCallback openMenu) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: openMenu,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: <Widget>[
            Text(
              title,
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

/// 带外置标签的输入框：表单里统一用它，避免只剩 placeholder。
class KcLabeledField extends StatelessWidget {
  const KcLabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.maxLines = 1,
    this.suffix,
    this.autofocus = false,
    this.onChanged,
    this.textInputAction,
    this.focusNode,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final int maxLines;
  final Widget? suffix;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscure,
          keyboardType: keyboardType,
          maxLines: maxLines,
          autofocus: autofocus,
          onChanged: onChanged,
          textInputAction: textInputAction,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}
