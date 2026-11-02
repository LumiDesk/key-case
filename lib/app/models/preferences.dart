/// 设备偏好。
///
/// 全部是「这台设备怎么显示/怎么锁」这类设置，与保险库内容无关：
/// 导入别人的备份不会覆盖它们，它们也不会进入加密备份。
library;

enum ThemeModePreference { system, light, dark }

/// 主题色来源。system = 跟随 Android 动态色；preset = 内置色板；custom = 用户调色。
enum ThemeColorMode { system, preset, custom }

/// 验证码分组方式：自动按位数、固定 3 位/4 位、不分组。
enum CodeGrouping { auto, three, four, none }

class AppPreferences {
  const AppPreferences({
    this.themeMode = ThemeModePreference.system,
    this.colorMode = ThemeColorMode.preset,
    this.presetIndex = 0,
    this.customColorValue = 0xFF2563EB,
    this.showTokenCodes = true,
    this.showNextToken = false,
    this.secureScreen = false,
    this.autoLockSeconds = 0,
    this.codeGrouping = CodeGrouping.auto,
    this.languageCode = '',
    this.biometricEnabled = false,
    this.autoSnapshot = true,
  });

  final ThemeModePreference themeMode;
  final ThemeColorMode colorMode;
  final int presetIndex;

  /// ARGB 整数；只在 colorMode == custom 时生效。
  final int customColorValue;
  final bool showTokenCodes;
  final bool showNextToken;

  /// 防止截屏/录屏（FLAG_SECURE）。
  final bool secureScreen;

  /// 进入后台后多久锁定：0 = 立即，负数 = 从不。
  final int autoLockSeconds;
  final CodeGrouping codeGrouping;

  /// 空串 = 跟随系统语言；否则是 zh / en。
  final String languageCode;

  /// 仅表示用户是否启用过生物识别解锁；真正的密钥在 Android Keystore。
  final bool biometricEnabled;

  /// 每次保存后写一份加密快照到应用私有目录（保留最近 10 份）。
  final bool autoSnapshot;

  AppPreferences copyWith({
    ThemeModePreference? themeMode,
    ThemeColorMode? colorMode,
    int? presetIndex,
    int? customColorValue,
    bool? showTokenCodes,
    bool? showNextToken,
    bool? secureScreen,
    int? autoLockSeconds,
    CodeGrouping? codeGrouping,
    String? languageCode,
    bool? biometricEnabled,
    bool? autoSnapshot,
  }) {
    return AppPreferences(
      themeMode: themeMode ?? this.themeMode,
      colorMode: colorMode ?? this.colorMode,
      presetIndex: presetIndex ?? this.presetIndex,
      customColorValue: customColorValue ?? this.customColorValue,
      showTokenCodes: showTokenCodes ?? this.showTokenCodes,
      showNextToken: showNextToken ?? this.showNextToken,
      secureScreen: secureScreen ?? this.secureScreen,
      autoLockSeconds: autoLockSeconds ?? this.autoLockSeconds,
      codeGrouping: codeGrouping ?? this.codeGrouping,
      languageCode: languageCode ?? this.languageCode,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      autoSnapshot: autoSnapshot ?? this.autoSnapshot,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'themeMode': themeMode.name,
    'colorMode': colorMode.name,
    'presetIndex': presetIndex,
    'customColorValue': customColorValue,
    'showTokenCodes': showTokenCodes,
    'showNextToken': showNextToken,
    'secureScreen': secureScreen,
    'autoLockSeconds': autoLockSeconds,
    'codeGrouping': codeGrouping.name,
    'languageCode': languageCode,
    'biometricEnabled': biometricEnabled,
    'autoSnapshot': autoSnapshot,
  };

  factory AppPreferences.fromJson(Map<String, Object?> json) {
    return AppPreferences(
      themeMode: ThemeModePreference.values.firstWhere(
        (value) => value.name == json['themeMode'],
        orElse: () => ThemeModePreference.system,
      ),
      colorMode: ThemeColorMode.values.firstWhere(
        (value) => value.name == json['colorMode'],
        orElse: () => ThemeColorMode.preset,
      ),
      presetIndex: (json['presetIndex'] as num?)?.toInt() ?? 0,
      customColorValue:
          (json['customColorValue'] as num?)?.toInt() ?? 0xFF2563EB,
      showTokenCodes: json['showTokenCodes'] as bool? ?? true,
      showNextToken: json['showNextToken'] as bool? ?? false,
      secureScreen: json['secureScreen'] as bool? ?? false,
      autoLockSeconds: (json['autoLockSeconds'] as num?)?.toInt() ?? 0,
      codeGrouping: CodeGrouping.values.firstWhere(
        (value) => value.name == json['codeGrouping'],
        orElse: () => CodeGrouping.auto,
      ),
      languageCode: json['languageCode'] as String? ?? '',
      biometricEnabled: json['biometricEnabled'] as bool? ?? false,
      autoSnapshot: json['autoSnapshot'] as bool? ?? true,
    );
  }
}
