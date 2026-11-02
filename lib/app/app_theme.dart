import 'package:anchored_menu/anchored_menu.dart';
import 'package:flutter/material.dart';

import 'models/models.dart';

// 画布与内容基色：一律不透明实色，不做玻璃/模糊/渐变。
const Color kcCanvasLight = Color(0xFFF3F5F8);
const Color kcCanvasDark = Color(0xFF101318);
const Color kcSurfaceLight = Color(0xFFFFFFFF);
const Color kcCardSurfaceDark = Color(0xFF1A1F27);
const Color kcSurfaceRaisedDark = Color(0xFF232A35);
const Color kcSurfaceAltLight = Color(0xFFF5F8FC);
const Color kcInk = Color(0xFF151922);
const Color kcLine = Color(0xFFE1E8F1);

/// KeyCase 的主色：信任蓝。
const Color kcAccent = Color(0xFF2563EB);
const Color kcDanger = Color(0xFFE84D6A);
const Color kcWarning = Color(0xFFFFB33E);
const Color kcSuccess = Color(0xFF12B8A6);

/// 浅色底语义色变体：亮色在白底对比度不足 AA，统一压暗后再用。
const Color kcDangerOnLight = Color(0xFFC2334F);
const Color kcWarningOnLight = Color(0xFF8A5A00);
const Color kcSuccessOnLight = Color(0xFF0B7A6C);

const double kcCardRadius = 16;
const double kcRadiusSm = 8;
const double kcRadiusMd = 12;
const double kcRadiusLg = 16;
const double kcRadiusXl = 24;
const double kcHeaderHeight = 56;
const double kcPageMaxWidth = 440;

/// 预设主色板。索引与 [AppPreferences.presetIndex] 对应。
const List<Color> kcAccentPresets = <Color>[
  kcAccent,
  Color(0xFF0E8C8C),
  Color(0xFF1F9D55),
  Color(0xFFD97706),
  Color(0xFFDB2777),
];

const List<String> kcAccentPresetNames = <String>['蓝', '青', '绿', '琥珀', '玫红'];

Color kcContentSurfaceColor(Brightness brightness) =>
    brightness == Brightness.dark ? kcCardSurfaceDark : kcSurfaceLight;

Color kcElevatedSurfaceColor(Brightness brightness) =>
    brightness == Brightness.dark ? kcSurfaceRaisedDark : kcSurfaceLight;

/// 语义色在当前明暗下的实际取值。
Color kcSemantic(BuildContext context, Color color) =>
    kcSemanticFor(Theme.of(context).brightness, color);

Color kcSemanticFor(Brightness brightness, Color color) {
  if (brightness == Brightness.dark) return color;
  return switch (color) {
    kcDanger => kcDangerOnLight,
    kcWarning => kcWarningOnLight,
    kcSuccess => kcSuccessOnLight,
    _ => color,
  };
}

/// 由用户偏好解析出主色。
Color kcPrimaryFor(AppPreferences preferences, Brightness brightness) {
  return switch (preferences.colorMode) {
    ThemeColorMode.system =>
      brightness == Brightness.dark ? const Color(0xFF8AB4F8) : kcAccent,
    ThemeColorMode.preset =>
      kcAccentPresets[preferences.presetIndex.clamp(
        0,
        kcAccentPresets.length - 1,
      )],
    ThemeColorMode.custom => Color(preferences.customColorValue),
  };
}

Color _onColor(Color color) =>
    ThemeData.estimateBrightnessForColor(color) == Brightness.light
    ? Colors.black
    : Colors.white;

ThemeData buildKeyCaseTheme({
  required Brightness brightness,
  required AppPreferences preferences,
}) {
  final isDark = brightness == Brightness.dark;
  final useSystemColors = preferences.colorMode == ThemeColorMode.system;
  final primary = kcPrimaryFor(preferences, brightness);
  final seedScheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: brightness,
    primary: useSystemColors ? null : primary,
    onPrimary: useSystemColors ? null : _onColor(primary),
  );
  final canvas = isDark ? kcCanvasDark : kcCanvasLight;
  final colorScheme = seedScheme.copyWith(
    surface: canvas,
    onSurface: isDark ? const Color(0xFFF0F3F8) : kcInk,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: canvas,
    useSystemColors: useSystemColors,
    visualDensity: VisualDensity.compact,
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: DividerThemeData(
      color: isDark ? Colors.white10 : kcLine,
      thickness: 0.8,
      space: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(40, 40),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: seedScheme.primary,
        foregroundColor: seedScheme.onPrimary,
        minimumSize: const Size(44, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kcRadiusMd),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(48, 44),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: seedScheme.primary,
      foregroundColor: seedScheme.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kcRadiusLg),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? seedScheme.onPrimary : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? seedScheme.primary : null,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? kcCardSurfaceDark : kcSurfaceLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kcRadiusMd),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kcRadiusMd),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kcRadiusMd),
        borderSide: BorderSide(color: seedScheme.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kcRadiusMd),
        borderSide: BorderSide(color: kcSemanticFor(brightness, kcDanger)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kcRadiusMd),
        borderSide: BorderSide(
          color: kcSemanticFor(brightness, kcDanger),
          width: 1.4,
        ),
      ),
    ),
  );

  final textTheme = base.textTheme.copyWith(
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      height: 1.2,
    ),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(
      fontSize: 19,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(fontSize: 17, height: 1.25),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontSize: 15,
      height: 1.25,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: base.textTheme.titleSmall?.copyWith(fontSize: 13, height: 1.25),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 14, height: 1.4),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 13, height: 1.4),
    bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 12, height: 1.35),
    labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 12, height: 1.25),
    labelMedium: base.textTheme.labelMedium?.copyWith(
      fontSize: 11,
      height: 1.25,
    ),
    labelSmall: base.textTheme.labelSmall?.copyWith(fontSize: 10, height: 1.2),
  );

  return base.copyWith(
    textTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[
      AnchoredMenuThemeData(
        surfaceColor: kcElevatedSurfaceColor(brightness),
        borderColor: isDark ? Colors.white.withValues(alpha: 0.12) : kcLine,
        foregroundColor: colorScheme.onSurface,
        selectedColor: colorScheme.primary,
        panelBorderRadius: BorderRadius.circular(kcRadiusXl),
        itemBorderRadius: BorderRadius.circular(kcRadiusLg),
        minWidth: 168,
      ),
    ],
  );
}
