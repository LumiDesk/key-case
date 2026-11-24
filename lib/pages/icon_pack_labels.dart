import '../app/icons/icon_packs.dart';
import '../l10n/app_localizations.dart';

/// 图标包在界面上的名称。
///
/// 包标识是代码常量，展示名必须走 l10n，不在注册表里存中文。
String packLabel(AppLocalizations l10n, IconPackId pack) => switch (pack) {
  IconPackId.simple => l10n.iconPackSimple,
  IconPackId.dashboard => l10n.iconPackDashboard,
  IconPackId.aegis => l10n.iconPackAegis,
};

/// 图标格的提示文案：默认包只显示名称，其余包补上风格标签。
String iconTooltip(AppLocalizations l10n, IconPackIcon icon) {
  if (icon.pack == IconPackId.simple) return icon.name;
  return '${icon.name} · ${packLabel(l10n, icon.pack)}';
}
