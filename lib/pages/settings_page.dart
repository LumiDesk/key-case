import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_theme.dart';
import '../app/app_version.dart';
import '../app/feedback.dart';
import '../app/keycase_controller.dart';
import '../app/keycase_scope.dart';
import '../app/logging/app_logger.dart';
import '../app/models/models.dart';
import '../app/util/date_format.dart';
import '../common_widgets.dart';
import '../l10n/app_localizations.dart';
import 'change_password_dialog.dart';
import 'color_picker_sheet.dart';
import 'sheets.dart';

/// 设置页：外观 / 安全 / 令牌 / 数据 / 备份 / 关于 / 危险操作。
///
/// 短单选（显示模式、主题色、语言、自动锁定、验证码分组）一律用
/// `anchored_menu` 的锚点菜单；只有需要输入的对话框与取色器使用弹层。
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.onLock,
    required this.onOpenTrash,
    required this.onOpenSecurity,
  });

  static const String _githubUrl = 'https://github.com/LumiDesk/key-case';

  final VoidCallback onLock;
  final VoidCallback onOpenTrash;
  final VoidCallback onOpenSecurity;

  @override
  Widget build(BuildContext context) {
    final controller = KeyCaseScope.of(context);
    final preferences = controller.preferences;
    final state = controller.state;
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      bottom: false,
      child: KcPage(
        child: Column(
          children: <Widget>[
            KcHeader(title: l10n.settingsTitle),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: <Widget>[
                  KcSectionLabel(l10n.settingsAppearance),
                  _card(<Widget>[
                    KcMenuRow<ThemeModePreference>(
                      icon: Icons.dark_mode_outlined,
                      title: l10n.settingsTheme,
                      value: _themeLabel(preferences.themeMode, l10n),
                      values: ThemeModePreference.values,
                      selected: preferences.themeMode,
                      idOf: (value) => value.name,
                      labelOf: (value) => _themeLabel(value, l10n),
                      keyPrefix: 'settings_theme',
                      onSelected: (value) => controller.updatePreferences(
                        preferences.copyWith(themeMode: value),
                      ),
                    ),
                    const KcRowDivider(),
                    KcMenuRow<String>(
                      icon: Icons.palette_outlined,
                      title: l10n.settingsAccent,
                      value: _accentLabel(preferences, l10n),
                      values: const <String>[
                        'system',
                        'preset0',
                        'preset1',
                        'preset2',
                        'preset3',
                        'preset4',
                        'custom',
                      ],
                      selected: _accentValue(preferences),
                      idOf: (value) => value,
                      labelOf: (value) => _accentValueLabel(value, l10n),
                      keyPrefix: 'settings_accent',
                      trailingColor: kcPrimaryFor(
                        preferences,
                        Theme.of(context).brightness,
                      ),
                      onSelected: (value) => _onAccentSelected(
                        context,
                        controller,
                        preferences,
                        value,
                      ),
                    ),
                    const KcRowDivider(),
                    KcMenuRow<String>(
                      icon: Icons.translate_rounded,
                      title: l10n.settingsLanguage,
                      value: _languageLabel(preferences.languageCode, l10n),
                      values: const <String>['', 'zh', 'en'],
                      selected: preferences.languageCode,
                      idOf: (value) => value.isEmpty ? 'system' : value,
                      labelOf: (value) => _languageLabel(value, l10n),
                      keyPrefix: 'settings_language',
                      onSelected: (value) => controller.updatePreferences(
                        preferences.copyWith(languageCode: value),
                      ),
                    ),
                  ]),
                  KcSectionLabel(l10n.settingsSecurity),
                  _card(<Widget>[
                    KcSwitchRow(
                      icon: Icons.screenshot_monitor_outlined,
                      title: l10n.settingsSecureScreen,
                      subtitle: l10n.settingsSecureScreenDesc,
                      value: preferences.secureScreen,
                      onChanged: (value) => controller.updatePreferences(
                        preferences.copyWith(secureScreen: value),
                      ),
                    ),
                    const KcRowDivider(),
                    KcSwitchRow(
                      icon: Icons.content_paste_off_outlined,
                      title: l10n.settingsClipboardClear,
                      subtitle: l10n.settingsClipboardClearDesc,
                      value: preferences.clipboardAutoClear,
                      onChanged: (value) => controller.updatePreferences(
                        preferences.copyWith(clipboardAutoClear: value),
                      ),
                    ),
                    const KcRowDivider(),
                    KcMenuRow<int>(
                      icon: Icons.timer_outlined,
                      title: l10n.settingsAutoLock,
                      value: _autoLockLabel(preferences.autoLockSeconds, l10n),
                      values: const <int>[0, 30, 60, 300, -1],
                      selected: preferences.autoLockSeconds,
                      idOf: (value) => 'lock_$value',
                      labelOf: (value) => _autoLockLabel(value, l10n),
                      keyPrefix: 'settings_autolock',
                      onSelected: (value) => controller.updatePreferences(
                        preferences.copyWith(autoLockSeconds: value),
                      ),
                    ),
                    const KcRowDivider(),
                    _BiometricRow(controller: controller),
                    const KcRowDivider(),
                    KcSettingsRow(
                      icon: Icons.shield_outlined,
                      title: l10n.securityTitle,
                      onTap: onOpenSecurity,
                    ),
                    const KcRowDivider(),
                    KcSettingsRow(
                      icon: Icons.password_rounded,
                      title: l10n.settingsChangePassword,
                      onTap: () => _changePassword(context),
                    ),
                    const KcRowDivider(),
                    KcSettingsRow(
                      icon: Icons.lock_outline_rounded,
                      title: l10n.settingsLockNow,
                      onTap: onLock,
                    ),
                  ]),
                  KcSectionLabel(l10n.settingsTokens),
                  _card(<Widget>[
                    KcSwitchRow(
                      icon: Icons.visibility_outlined,
                      title: l10n.settingsShowCodes,
                      subtitle: l10n.settingsShowCodesDesc,
                      value: preferences.showTokenCodes,
                      onChanged: (value) => controller.updatePreferences(
                        preferences.copyWith(showTokenCodes: value),
                      ),
                    ),
                    const KcRowDivider(),
                    KcSwitchRow(
                      icon: Icons.skip_next_rounded,
                      title: l10n.settingsShowNext,
                      subtitle: l10n.settingsShowNextDesc,
                      value: preferences.showNextToken,
                      onChanged: (value) => controller.updatePreferences(
                        preferences.copyWith(showNextToken: value),
                      ),
                    ),
                    const KcRowDivider(),
                    KcMenuRow<CodeGrouping>(
                      icon: Icons.short_text_rounded,
                      title: l10n.settingsGrouping,
                      value: _groupingLabel(preferences.codeGrouping, l10n),
                      values: CodeGrouping.values,
                      selected: preferences.codeGrouping,
                      idOf: (value) => value.name,
                      labelOf: (value) => _groupingLabel(value, l10n),
                      keyPrefix: 'settings_grouping',
                      onSelected: (value) => controller.updatePreferences(
                        preferences.copyWith(codeGrouping: value),
                      ),
                    ),
                  ]),
                  KcSectionLabel(l10n.settingsData),
                  _card(<Widget>[
                    KcSettingsRow(
                      icon: Icons.upload_file_outlined,
                      title: l10n.settingsExport,
                      subtitle: l10n.settingsExportDesc,
                      onTap: controller.exportBackup,
                    ),
                    const KcRowDivider(),
                    KcSettingsRow(
                      icon: Icons.download_outlined,
                      title: l10n.settingsImport,
                      subtitle: l10n.settingsImportDesc,
                      onTap: () => _importBackup(context),
                    ),
                    const KcRowDivider(),
                    KcSettingsRow(
                      icon: Icons.inventory_2_outlined,
                      title: l10n.settingsImportAegis,
                      subtitle: l10n.settingsImportAegisDesc,
                      onTap: () => _importAegis(context),
                    ),
                    const KcRowDivider(),
                    KcSettingsRow(
                      icon: Icons.qr_code_2_rounded,
                      title: l10n.settingsImportGoogle,
                      subtitle: l10n.settingsImportGoogleDesc,
                      onTap: () => _importGoogle(context),
                    ),
                  ]),
                  KcSectionLabel(l10n.settingsBackup),
                  _card(<Widget>[
                    KcSettingsRow(
                      icon: Icons.folder_outlined,
                      title: l10n.settingsBackupFolder,
                      subtitle: preferences.backupFolderName.isEmpty
                          ? l10n.settingsBackupFolderNone
                          : preferences.backupFolderName,
                      onTap: controller.pickBackupFolder,
                    ),
                    const KcRowDivider(),
                    KcSwitchRow(
                      icon: Icons.history_rounded,
                      title: l10n.settingsAutoSnapshot,
                      subtitle: l10n.settingsAutoSnapshotDesc,
                      value: preferences.autoSnapshot,
                      // 没选目录时点开关直接去选目录，避免出现「开了但没地方写」。
                      onChanged: preferences.backupTreeUri.isEmpty
                          ? (value) => controller.pickBackupFolder()
                          : (value) => controller.updatePreferences(
                              preferences.copyWith(autoSnapshot: value),
                            ),
                    ),
                    const KcRowDivider(),
                    KcSettingsRow(
                      icon: Icons.schedule_outlined,
                      title: l10n.settingsLastBackup,
                      subtitle: preferences.lastBackupAt == 0
                          ? l10n.settingsBackupNever
                          : formatDateTime(
                              context,
                              DateTime.fromMillisecondsSinceEpoch(
                                preferences.lastBackupAt,
                              ),
                            ),
                    ),
                    const KcRowDivider(),
                    KcSettingsRow(
                      icon: Icons.save_outlined,
                      title: l10n.settingsBackupNow,
                      subtitle: l10n.settingsBackupNowDesc,
                      onTap: controller.backupNow,
                    ),
                    const KcRowDivider(),
                    KcSettingsRow(
                      icon: Icons.delete_outline_rounded,
                      title: l10n.trashTitle,
                      subtitle: state.trashedItems.isEmpty
                          ? l10n.trashEmptyCount
                          : l10n.itemsCount(state.trashedItems.length),
                      onTap: onOpenTrash,
                    ),
                  ]),
                  KcSectionLabel(l10n.settingsAbout),
                  _card(<Widget>[
                    KcSettingsRow(
                      icon: Icons.info_outline_rounded,
                      title: l10n.settingsVersion,
                      subtitle: '$kAppVersion+$kAppBuildNumber',
                    ),
                    const KcRowDivider(),
                    ValueListenableBuilder<bool>(
                      valueListenable: KeyCaseScope.of(context)
                          .updateCheckInProgress,
                      builder: (context, checking, _) => KcSettingsRow(
                        icon: Icons.system_update_outlined,
                        title: l10n.settingsCheckUpdate,
                        trailing: checking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                        onTap: checking ? null : () => _checkUpdates(context),
                      ),
                    ),
                    const KcRowDivider(),
                    KcSettingsRow(
                      icon: Icons.article_outlined,
                      title: l10n.settingsLicenses,
                      subtitle: l10n.settingsLicensesDesc,
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'KeyCase',
                        applicationVersion: '$kAppVersion+$kAppBuildNumber',
                      ),
                    ),
                    const KcRowDivider(),
                    KcSettingsRow(
                      icon: Icons.privacy_tip_outlined,
                      title: l10n.settingsPrivacy,
                      onTap: () => _showPrivacy(context),
                    ),
                    const KcRowDivider(),
                    KcSettingsRow(
                      icon: Icons.code_rounded,
                      title: l10n.settingsGithub,
                      subtitle: l10n.settingsGithubDesc,
                      onTap: () => _openGithub(context),
                    ),
                  ]),
                  KcSectionLabel(l10n.settingsDanger),
                  _card(<Widget>[
                    KcSettingsRow(
                      icon: Icons.delete_forever_outlined,
                      title: l10n.settingsDeleteVault,
                      subtitle: l10n.settingsDeleteVaultDesc,
                      destructive: true,
                      onTap: () => _deleteVault(context),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return KcCard(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: EdgeInsets.zero,
      child: Column(children: children),
    );
  }

  // --- 文案 ---------------------------------------------------------------

  String _themeLabel(ThemeModePreference mode, AppLocalizations l10n) =>
      switch (mode) {
        ThemeModePreference.system => l10n.themeSystem,
        ThemeModePreference.light => l10n.themeLight,
        ThemeModePreference.dark => l10n.themeDark,
      };

  String _accentValue(AppPreferences preferences) {
    return switch (preferences.colorMode) {
      ThemeColorMode.system => 'system',
      ThemeColorMode.custom => 'custom',
      ThemeColorMode.preset => 'preset${preferences.presetIndex}',
    };
  }

  String _accentLabel(AppPreferences preferences, AppLocalizations l10n) =>
      _accentValueLabel(_accentValue(preferences), l10n);

  String _accentValueLabel(String value, AppLocalizations l10n) {
    return switch (value) {
      'system' => l10n.accentSystem,
      'custom' => l10n.accentCustom,
      'preset0' => l10n.accentBlue,
      'preset1' => l10n.accentTeal,
      'preset2' => l10n.accentGreen,
      'preset3' => l10n.accentAmber,
      _ => l10n.accentRose,
    };
  }

  String _languageLabel(String code, AppLocalizations l10n) => switch (code) {
    'zh' => l10n.languageChinese,
    'en' => l10n.languageEnglish,
    _ => l10n.languageSystem,
  };

  String _autoLockLabel(int seconds, AppLocalizations l10n) =>
      switch (seconds) {
        < 0 => l10n.autoLockNever,
        0 => l10n.autoLockImmediate,
        <= 30 => l10n.autoLock30,
        <= 60 => l10n.autoLock60,
        _ => l10n.autoLock300,
      };

  String _groupingLabel(CodeGrouping grouping, AppLocalizations l10n) =>
      switch (grouping) {
        CodeGrouping.auto => l10n.groupingAuto,
        CodeGrouping.three => l10n.groupingThree,
        CodeGrouping.four => l10n.groupingFour,
        CodeGrouping.none => l10n.groupingNone,
      };

  // --- 动作 ---------------------------------------------------------------

  Future<void> _onAccentSelected(
    BuildContext context,
    KeyCaseController controller,
    AppPreferences preferences,
    String value,
  ) async {
    if (value == 'system') {
      await controller.updatePreferences(
        preferences.copyWith(colorMode: ThemeColorMode.system),
      );
      return;
    }
    if (value == 'custom') {
      if (!context.mounted) return;
      final color = await showThemeColorPickerSheet(
        context: context,
        initialColor: kcPrimaryFor(preferences, Theme.of(context).brightness),
      );
      if (color == null) return;
      await controller.updatePreferences(
        preferences.copyWith(
          colorMode: ThemeColorMode.custom,
          customColorValue: color.toARGB32(),
        ),
      );
      return;
    }
    final index = int.tryParse(value.replaceFirst('preset', '')) ?? 0;
    await controller.updatePreferences(
      preferences.copyWith(
        colorMode: ThemeColorMode.preset,
        presetIndex: index,
      ),
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => const ChangePasswordDialog(),
    );
  }

  Future<void> _importBackup(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final controller = KeyCaseScope.read(context);
    final bytes = await controller.pickBackupFile(
      label: l10n.importBackupTitle,
    );
    if (bytes == null || !context.mounted) return;
    final password = await showKcTextInput(
      context: context,
      title: l10n.importBackupTitle,
      hint: l10n.importBackupPassword,
      obscure: true,
    );
    if (password == null || password.isEmpty || !context.mounted) return;
    await controller.importBackup(bytes: bytes, password: password);
  }

  /// Aegis：先选文件，再按需问备份密码（明文导出可以直接留空）。
  Future<void> _importAegis(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final controller = KeyCaseScope.read(context);
    final bytes = await controller.pickAegisFile(
      label: l10n.settingsImportAegis,
    );
    if (bytes == null || !context.mounted) return;
    final password = await showKcTextInput(
      context: context,
      title: l10n.aegisPasswordTitle,
      hint: l10n.aegisPasswordHint,
      obscure: true,
    );
    if (!context.mounted) return;
    await controller.importAegisBytes(
      bytes: bytes,
      password: (password ?? '').isEmpty ? null : password,
      fallbackTitle: l10n.aegisUnnamed,
    );
  }

  /// Google Authenticator：粘贴迁移链接（也可以直接扫迁移二维码）。
  Future<void> _importGoogle(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final controller = KeyCaseScope.read(context);
    final link = await showKcTextInput(
      context: context,
      title: l10n.googleMigrationTitle,
      hint: l10n.googleMigrationHint,
      maxLines: 2,
    );
    if (link == null || link.trim().isEmpty) return;
    await controller.importGoogleMigrationLink(link.trim());
  }

  Future<void> _checkUpdates(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final controller = KeyCaseScope.read(context);
    final result = await controller.checkUpdates();
    if (!context.mounted) return;
    if (result.failed) {
      KcFeedbackScope.maybeOf(context)?.show(l10n.updateCheckFailed);
      return;
    }
    if (result.info == null) {
      KcFeedbackScope.maybeOf(context)?.show(l10n.updateUpToDate);
      return;
    }
    final info = result.info!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.updateAvailableTitle),
        content: Text(
          '${l10n.updateCurrentVersion}: $kAppVersion\n'
          '${l10n.updateLatestVersion}: ${info.version}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.actionClose),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final uri = Uri.tryParse(info.releaseUrl);
              if (uri == null) return;
              try {
                final launched = await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
                if (!launched && context.mounted) {
                  KcFeedbackScope.maybeOf(context)
                      ?.show(l10n.errorOpenLinkFailed);
                }
              } catch (error) {
                AppLogger.warn('open release failed: $error');
                if (context.mounted) {
                  KcFeedbackScope.maybeOf(context)
                      ?.show(l10n.errorOpenLinkFailed);
                }
              }
            },
            child: Text(l10n.updateOpenRelease),
          ),
        ],
      ),
    );
  }

  void _showPrivacy(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showKcInfo(
      context: context,
      title: l10n.settingsPrivacy,
      message: l10n.settingsPrivacyBody,
    );
  }

  Future<void> _openGithub(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    try {
      final launched = await launchUrl(
        Uri.parse(_githubUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!context.mounted) return;
      if (!launched) {
        KcFeedbackScope.maybeOf(context)?.show(l10n.errorOpenLinkFailed);
      }
    } catch (error) {
      AppLogger.warn('open github failed: $error');
      if (context.mounted) {
        KcFeedbackScope.maybeOf(context)?.show(l10n.errorOpenLinkFailed);
      }
    }
  }

  Future<void> _deleteVault(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final controller = KeyCaseScope.read(context);
    final confirmed = await showKcConfirm(
      context: context,
      title: l10n.settingsDeleteVault,
      message: l10n.settingsDeleteVaultMessage,
      confirmLabel: l10n.deleteVaultAction,
      destructive: true,
    );
    if (confirmed) {
      await controller.deleteVault();
    }
  }
}

/// 指纹开关：设备不支持/未录入时禁用，避免用户点开一个必然失败的系统弹窗。
class _BiometricRow extends StatefulWidget {
  const _BiometricRow({required this.controller});

  final KeyCaseController controller;

  @override
  State<_BiometricRow> createState() => _BiometricRowState();
}

class _BiometricRowState extends State<_BiometricRow> {
  late final Future<bool> _available = widget.controller.canUseBiometrics();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enrolled = KeyCaseScope.of(context).state.biometricEnrolled;
    return FutureBuilder<bool>(
      future: _available,
      builder: (context, snapshot) {
        final checking = snapshot.connectionState != ConnectionState.done;
        final available = snapshot.data ?? false;
        final unavailable = !checking && !available;
        final subtitle = checking
            ? l10n.settingsBiometricOff
            : unavailable
            ? l10n.errorBiometricUnavailable
            : enrolled
            ? l10n.settingsBiometricOn
            : l10n.settingsBiometricOff;
        return KcSwitchRow(
          icon: Icons.fingerprint_rounded,
          title: l10n.settingsBiometric,
          subtitle: subtitle,
          value: enrolled,
          // 已登记但硬件后来不可用时，仍允许关闭，避免留下无法撤销的开关。
          onChanged: checking
              ? null
              : available
              ? (value) async {
                  if (value) {
                    await widget.controller.enableBiometrics(
                      reason: l10n.biometricEnableReason,
                      cancelLabel: l10n.actionCancel,
                    );
                  } else {
                    await widget.controller.disableBiometrics();
                  }
                }
              : enrolled
              ? (_) => widget.controller.disableBiometrics()
              : null,
        );
      },
    );
  }
}
