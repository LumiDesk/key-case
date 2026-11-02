import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/app_version.dart';
import '../app/feedback.dart';
import '../app/keycase_controller.dart';
import '../app/keycase_scope.dart';
import '../app/messages.dart';
import '../app/models/models.dart';
import '../common_widgets.dart';
import '../l10n/app_localizations.dart';
import 'sheets.dart';

/// 设置页：外观 / 安全 / 令牌 / 数据 / 关于 / 危险操作。
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
    final trashCount = state.trashedItems.length;

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
                    _SettingsValueRow(
                      icon: Icons.dark_mode_outlined,
                      title: l10n.settingsTheme,
                      value: switch (preferences.themeMode) {
                        ThemeModePreference.system => l10n.themeSystem,
                        ThemeModePreference.light => l10n.themeLight,
                        ThemeModePreference.dark => l10n.themeDark,
                      },
                      onTap: () => _pickTheme(context, preferences),
                    ),
                    const KcRowDivider(),
                    _SettingsValueRow(
                      icon: Icons.palette_outlined,
                      title: l10n.settingsAccent,
                      value: _accentLabel(preferences, l10n),
                      trailingColor: kcPrimaryFor(
                        preferences,
                        Theme.of(context).brightness,
                      ),
                      onTap: () => _pickAccent(context, preferences),
                    ),
                    const KcRowDivider(),
                    _SettingsValueRow(
                      icon: Icons.translate_rounded,
                      title: l10n.settingsLanguage,
                      value: _languageLabel(preferences, l10n),
                      onTap: () => _pickLanguage(context, preferences),
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
                    _SettingsValueRow(
                      icon: Icons.timer_outlined,
                      title: l10n.settingsAutoLock,
                      value: _autoLockLabel(preferences.autoLockSeconds, l10n),
                      onTap: () => _pickAutoLock(context, preferences),
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
                    _SettingsValueRow(
                      icon: Icons.short_text_rounded,
                      title: l10n.settingsGrouping,
                      value: _groupingLabel(preferences.codeGrouping, l10n),
                      onTap: () => _pickGrouping(context, preferences),
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
                    const KcRowDivider(),
                    KcSwitchRow(
                      icon: Icons.history_rounded,
                      title: l10n.settingsAutoSnapshot,
                      subtitle: l10n.settingsAutoSnapshotDesc,
                      value: preferences.autoSnapshot,
                      onChanged: (value) => controller.updatePreferences(
                        preferences.copyWith(autoSnapshot: value),
                      ),
                    ),
                    const KcRowDivider(),
                    KcSettingsRow(
                      icon: Icons.delete_outline_rounded,
                      title: l10n.trashTitle,
                      subtitle: '$trashCount',
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

  String _accentLabel(AppPreferences preferences, AppLocalizations l10n) {
    return switch (preferences.colorMode) {
      ThemeColorMode.system => l10n.accentSystem,
      ThemeColorMode.custom => l10n.accentCustom,
      ThemeColorMode.preset => switch (preferences.presetIndex.clamp(0, 4)) {
        0 => l10n.accentBlue,
        1 => l10n.accentTeal,
        2 => l10n.accentGreen,
        3 => l10n.accentAmber,
        _ => l10n.accentRose,
      },
    };
  }

  String _autoLockLabel(int seconds, AppLocalizations l10n) {
    return switch (seconds) {
      < 0 => l10n.autoLockNever,
      0 => l10n.autoLockImmediate,
      <= 30 => l10n.autoLock30,
      <= 60 => l10n.autoLock60,
      _ => l10n.autoLock300,
    };
  }

  String _groupingLabel(CodeGrouping grouping, AppLocalizations l10n) {
    return switch (grouping) {
      CodeGrouping.auto => l10n.groupingAuto,
      CodeGrouping.three => l10n.groupingThree,
      CodeGrouping.four => l10n.groupingFour,
      CodeGrouping.none => l10n.groupingNone,
    };
  }

  String _languageLabel(AppPreferences preferences, AppLocalizations l10n) {
    return switch (preferences.languageCode) {
      'zh' => '中文',
      'en' => 'English',
      _ => l10n.themeSystem,
    };
  }

  Future<void> _pickTheme(
    BuildContext context,
    AppPreferences preferences,
  ) async {
    final l10n = AppLocalizations.of(context);
    final controller = KeyCaseScope.read(context);
    final value = await showKcOptionSheet<ThemeModePreference>(
      context: context,
      title: l10n.settingsTheme,
      selected: preferences.themeMode,
      options: <({ThemeModePreference value, String label})>[
        (value: ThemeModePreference.system, label: l10n.themeSystem),
        (value: ThemeModePreference.light, label: l10n.themeLight),
        (value: ThemeModePreference.dark, label: l10n.themeDark),
      ],
    );
    if (value != null) {
      await controller.updatePreferences(
        preferences.copyWith(themeMode: value),
      );
    }
  }

  Future<void> _pickAccent(
    BuildContext context,
    AppPreferences preferences,
  ) async {
    final l10n = AppLocalizations.of(context);
    final controller = KeyCaseScope.read(context);
    final value = await showKcOptionSheet<String>(
      context: context,
      title: l10n.settingsAccent,
      selected: switch (preferences.colorMode) {
        ThemeColorMode.system => 'system',
        ThemeColorMode.custom => 'custom',
        ThemeColorMode.preset => 'preset${preferences.presetIndex}',
      },
      options: <({String value, String label})>[
        (value: 'system', label: l10n.accentSystem),
        for (var i = 0; i < 5; i++)
          (
            value: 'preset$i',
            label: <String>[
              l10n.accentBlue,
              l10n.accentTeal,
              l10n.accentGreen,
              l10n.accentAmber,
              l10n.accentRose,
            ][i],
          ),
        (value: 'custom', label: l10n.accentCustom),
      ],
    );
    if (value == null || !context.mounted) return;
    if (value == 'system') {
      await controller.updatePreferences(
        preferences.copyWith(colorMode: ThemeColorMode.system),
      );
    } else if (value == 'custom') {
      final color = await _pickCustomColor(context, preferences);
      if (color != null) {
        await controller.updatePreferences(
          preferences.copyWith(
            colorMode: ThemeColorMode.custom,
            customColorValue: color,
          ),
        );
      }
    } else {
      final index = int.tryParse(value.replaceFirst('preset', '')) ?? 0;
      await controller.updatePreferences(
        preferences.copyWith(
          colorMode: ThemeColorMode.preset,
          presetIndex: index,
        ),
      );
    }
  }

  Future<int?> _pickCustomColor(
    BuildContext context,
    AppPreferences preferences,
  ) {
    const palette = <int>[
      0xFF2563EB,
      0xFF0EA5E9,
      0xFF0E8C8C,
      0xFF10B981,
      0xFF65A30D,
      0xFFD97706,
      0xFFEA580C,
      0xFFDC2626,
      0xFFDB2777,
      0xFF7C3AED,
      0xFF4F46E5,
      0xFF475569,
    ];
    return showKcSheet<int>(
      context: context,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  AppLocalizations.of(sheetContext).accentCustom,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    for (final color in palette)
                      GestureDetector(
                        onTap: () => Navigator.of(sheetContext).pop(color),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Color(color),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == preferences.customColorValue
                                  ? theme.colorScheme.onSurface
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickLanguage(
    BuildContext context,
    AppPreferences preferences,
  ) async {
    final controller = KeyCaseScope.read(context);
    final value = await showKcOptionSheet<String>(
      context: context,
      title: 'Language',
      selected: preferences.languageCode,
      options: const <({String value, String label})>[
        (value: '', label: '跟随系统 / System'),
        (value: 'zh', label: '中文'),
        (value: 'en', label: 'English'),
      ],
    );
    if (value != null) {
      await controller.updatePreferences(
        preferences.copyWith(languageCode: value),
      );
    }
  }

  Future<void> _pickAutoLock(
    BuildContext context,
    AppPreferences preferences,
  ) async {
    final l10n = AppLocalizations.of(context);
    final controller = KeyCaseScope.read(context);
    final value = await showKcOptionSheet<int>(
      context: context,
      title: l10n.settingsAutoLock,
      selected: preferences.autoLockSeconds,
      options: <({int value, String label})>[
        (value: 0, label: l10n.autoLockImmediate),
        (value: 30, label: l10n.autoLock30),
        (value: 60, label: l10n.autoLock60),
        (value: 300, label: l10n.autoLock300),
        (value: -1, label: l10n.autoLockNever),
      ],
    );
    if (value != null) {
      await controller.updatePreferences(
        preferences.copyWith(autoLockSeconds: value),
      );
    }
  }

  Future<void> _pickGrouping(
    BuildContext context,
    AppPreferences preferences,
  ) async {
    final l10n = AppLocalizations.of(context);
    final controller = KeyCaseScope.read(context);
    final value = await showKcOptionSheet<CodeGrouping>(
      context: context,
      title: l10n.settingsGrouping,
      selected: preferences.codeGrouping,
      options: <({CodeGrouping value, String label})>[
        (value: CodeGrouping.auto, label: l10n.groupingAuto),
        (value: CodeGrouping.three, label: l10n.groupingThree),
        (value: CodeGrouping.four, label: l10n.groupingFour),
        (value: CodeGrouping.none, label: l10n.groupingNone),
      ],
    );
    if (value != null) {
      await controller.updatePreferences(
        preferences.copyWith(codeGrouping: value),
      );
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final result = await showKcSheet<bool>(
      context: context,
      builder: (_) => const _ChangePasswordSheet(),
    );
    if (result != true || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    KcFeedbackScope.maybeOf(context)?.show(l10n.noticePasswordChanged);
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

/// 左侧图标 + 标题 + 右侧当前值 + chevron。
class _SettingsValueRow extends StatelessWidget {
  const _SettingsValueRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.trailingColor,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KcSettingsRow(
      icon: icon,
      title: title,
      onTap: onTap,
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
            Icons.chevron_right_rounded,
            size: 20,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}

/// 修改主密码：三字段 + 保存。成功返回 true。
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
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
    // 表单校验与落盘都在 Controller 里，这里只把结果翻成文案。
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.changePasswordTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
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
          ),
          const SizedBox(height: 12),
          KcLabeledField(
            label: l10n.confirmNewPassword,
            controller: _confirm,
            obscure: true,
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: kcSemantic(context, kcDanger)),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.actionCancel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.actionSave),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
