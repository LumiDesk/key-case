import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';

/// 自定义主题色：HSV 三个滑条 + 实时预览。
///
/// 不输入 Hex，直接用色相/饱和度/亮度调色，
/// 预览块同时显示「主色上的文字」对比效果。
Future<Color?> showThemeColorPickerSheet({
  required BuildContext context,
  required Color initialColor,
}) {
  return showKcSheet<Color>(
    context: context,
    builder: (_) => _ThemeColorPickerSheet(initialColor: initialColor),
  );
}

class _ThemeColorPickerSheet extends StatefulWidget {
  const _ThemeColorPickerSheet({required this.initialColor});

  final Color initialColor;

  @override
  State<_ThemeColorPickerSheet> createState() => _ThemeColorPickerSheetState();
}

class _ThemeColorPickerSheetState extends State<_ThemeColorPickerSheet> {
  late HSVColor _hsv = HSVColor.fromColor(
    widget.initialColor.withValues(alpha: 1),
  );

  Color get _color => _hsv.toColor();

  void _update(HSVColor value) => setState(() => _hsv = value);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final onColor = _color.computeLuminance() > 0.48
        ? Colors.black
        : Colors.white;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.themeColorTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Container(
              height: 76,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(kcRadiusLg),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    l10n.themeColorPreview,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: onColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _hex(_color),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: onColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _HsvSlider(
              label: l10n.themeColorHue,
              value: _hsv.hue,
              max: 360,
              activeColor: _color,
              onChanged: (value) => _update(_hsv.withHue(value)),
            ),
            _HsvSlider(
              label: l10n.themeColorSaturation,
              value: _hsv.saturation,
              max: 1,
              activeColor: _color,
              onChanged: (value) => _update(_hsv.withSaturation(value)),
            ),
            _HsvSlider(
              label: l10n.themeColorBrightness,
              value: _hsv.value,
              max: 1,
              activeColor: _color,
              onChanged: (value) => _update(_hsv.withValue(value)),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.actionCancel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_color),
                    child: Text(l10n.actionSave),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _hex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).toUpperCase().padLeft(6, '0')}';
  }
}

class _HsvSlider extends StatelessWidget {
  const _HsvSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.activeColor,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ),
              Text(
                max > 1 ? '${value.round()}°' : '${(value * 100).round()}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: value.clamp(0, max),
              max: max,
              activeColor: activeColor,
              inactiveColor: activeColor.withValues(alpha: 0.25),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
