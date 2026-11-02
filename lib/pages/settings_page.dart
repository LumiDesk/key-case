import 'package:anchored_menu/anchored_menu.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_theme.dart';
import '../app/app_version.dart';
import '../app/feedback.dart';
import '../app/keycase_controller.dart';
import '../app/keycase_scope.dart';
import '../app/messages.dart';
import '../app/models/models.dart';
import '../app/password_strength.dart';
import '../app/security/security_audit.dart';
import '../app/util/date_format.dart';
import '../common_widgets.dart';
import '../l10n/app_localizations.dart';
import 'color_picker_sheet.dart';
import 'sheets.dart';

/// 设置页：外观 / 安全 / 令牌 / 数据 / 备份 / 关于 / 危险操作。
///
/// 短单选（显示模式、主题色、语言、自动锁定、验证码分组）一律用
/// `anchored_menu` 的锚点菜单，不再弹底部选择器；只有需要输入的对话框
/// 与取色器使用弹层。
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.onLock,
    required this.onOpenTrash,
    required this.onOpenSecurity,
  });

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
                    _MenuRow<ThemeModePreference>(
                      icon: Icons.dark_mode_outlined,
                      title: l10n.settingsTheme,
                      value: _themeLabel(preferences.themeMode, l10n),
                      values: ThemeModePreference.values,
                      selected: preferences.themeMode,
                      idOf: (value) => value.name,
                      labelOf: (value) => _themeLabel(value, l10n),
                      onSelected: (value) => controller.updatePreferences(
                        preferences.copyWith(themeMode: value),
                      ),
                    ),
                    const KcRowDivider(),
                    _MenuRow<String>(
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
                    _MenuRow<String>(
                      icon: Icons.translate_rounded,
                      title: l10n.settingsLanguage,
                      value: _languageLabel(preferences.languageCode),
                      values: const <String>['', 'zh', 'en'],
                      selected: preferences.languageCode,
                      idOf: (value) => value.isEmpty ? 'system' : value,
                      labelOf: (value) => _languageLabel(value),
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
                    _MenuRow<int>(
                      icon: Icons.timer_outlined,
                      title: l10n.settingsAutoLock,
                      value: _autoLockLabel(preferences.autoLockSeconds, l10n),
                      values: const <int>[0, 30, 60, 300, -1],
                      selected: preferences.autoLockSeconds,
                      idOf: (value) => 'lock_$value',
                      labelOf: (value) => _autoLockLabel(value, l10n),
                      onSelected: (value) => controller.updatePreferences(
                        preferences.copyWith(autoLockSeconds: value),
                      ),
                    ),
                    const KcRowDivider(),
                    KcSwitchRow(
                      icon: Icons.fingerprint_rounded,
                      title: l10n.settingsBiometric,
                      subtitle: state.biometricEnrolled
                          ? l10n.settingsBiometricOn
                          : l10n.settingsBiometricOff,
                      value: state.biometricEnrolled,
                      onChanged: (value) async {
                        if (value) {
                          await controller.enableBiometrics(
                            reason: l10n.biometricEnableReason,
                          );
                        } else {
                          await controller.disableBiometrics();
                        }
                      },
                    ),
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
                    _MenuRow<CodeGrouping>(
                      icon: Icons.short_text_rounded,
                      title: l10n.settingsGrouping,
                      value: _groupingLabel(preferences.codeGrouping, l10n),
                      values: CodeGrouping.values,
                      selected: preferences.codeGrouping,
                      idOf: (value) => value.name,
                      labelOf: (value) => _groupingLabel(value, l10n),
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
                      subtitle: '${state.trashedItems.length}',
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
                    KcSettingsRow(
                      icon: Icons.system_update_outlined,
                      title: l10n.settingsCheckUpdate,
                      subtitle: l10n.settingsCheckUpdateDesc,
                      onTap: () => _checkUpdates(context),
                    ),
                    const KcRowDivider(),
                    KcSettingsRow(
                      icon: Icons.privacy_tip_outlined,
                      title: l10n.settingsPrivacy,
                      onTap: () => _showPrivacy(context),
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

  String _languageLabel(String code) => switch (code) {
    'zh' => '中文',
    'en' => 'English',
    _ => 'System / 跟随系统',
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (ok != true || !context.mounted) return;
    KcFeedbackScope.maybeOf(context)
        ?.show(AppLocalizations.of(context).noticePasswordChanged);
  }

  Future<void> _importBackup(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final controller = KeyCaseScope.read(context);
    final bytes = await controller.pickBackupFile();
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
    final bytes = await controller.pickAegisFile();
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
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsPrivacy),
        content: Text(l10n.settingsPrivacyBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.actionClose),
          ),
        ],
      ),
    );
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

/// 设置行 + 锚点菜单：点行弹出菜单，选中后回到页面状态。
class _MenuRow<T> extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.values,
    required this.selected,
    required this.idOf,
    required this.labelOf,
    required this.onSelected,
    this.trailingColor,
  });

  final IconData icon;
  final String title;
  final String value;
  final List<T> values;
  final T selected;
  final String Function(T value) idOf;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnchoredMenuAnchor(
      entries: <AnchoredMenuEntry>[
        for (final option in values)
          AnchoredMenuItem(
            id: idOf(option),
            title: labelOf(option),
            selected: option == selected,
            onPressed: () => onSelected(option),
          ),
      ],
      semanticLabel: title,
      builder: (context, openMenu, menuOpen) => KcSettingsRow(
        icon: icon,
        title: title,
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
      ),
    );
  }
}

/// 修改主密码对话框：三字段 + 强度条，与创建页保持同一套视觉。
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final controller = KeyCaseScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await controller.changeMasterPassword(
      currentPassword: _current.text,
      newPassword: _next.text,
      confirmPassword: _confirm.text,
    );
    if (!mounted) return;
    if (!ok) {
      final error = controller.state.error;
      setState(() {
        _busy = false;
        _error = error == null
            ? l10n.errorPasswordIncorrect
            : errorText(l10n, error);
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.changePasswordTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            KcLabeledField(
              label: l10n.currentPassword,
              controller: _current,
              obscure: true,
            ),
            const SizedBox(height: 12),
            KcLabeledField(
              label: l10n.newPassword,
              controller: _next,
              obscure: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            KcPasswordStrengthBar(score: masterPasswordScore(_next.text)),
            const SizedBox(height: 12),
            KcLabeledField(
              label: l10n.confirmNewPassword,
              controller: _confirm,
              obscure: true,
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(
                  color: kcSemantic(context, kcDanger),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.actionSave),
        ),
      ],
    );
  }
}
