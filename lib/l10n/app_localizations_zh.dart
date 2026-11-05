// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get navHome => '首页';

  @override
  String get navLogins => '登录项';

  @override
  String get navTokens => '令牌';

  @override
  String get navSettings => '设置';

  @override
  String get actionSave => '保存';

  @override
  String get actionCancel => '取消';

  @override
  String get actionDelete => '删除';

  @override
  String get actionEdit => '编辑';

  @override
  String get actionMore => '更多';

  @override
  String get actionClose => '关闭';

  @override
  String get actionCopy => '复制';

  @override
  String get actionBack => '返回';

  @override
  String get actionNext => '下一个';

  @override
  String get actionAdd => '添加';

  @override
  String get actionSearch => '搜索';

  @override
  String get actionSort => '排序';

  @override
  String get actionRestore => '恢复';

  @override
  String get pressBackAgainToExit => '再次返回退出软件';

  @override
  String get copied => '已复制';

  @override
  String get loading => '处理中…';

  @override
  String get createTitle => '创建你的保险库';

  @override
  String get createSubtitle => '主密码只保存在你的脑子里。忘记它，没人能帮你恢复。';

  @override
  String get masterPassword => '主密码';

  @override
  String get confirmPassword => '确认主密码';

  @override
  String get passwordHint => '至少 8 位';

  @override
  String get createVault => '创建保险库';

  @override
  String get unlockTitle => '解锁 KeyCase';

  @override
  String get unlockSubtitle => '输入主密码继续';

  @override
  String get unlock => '解锁';

  @override
  String get useBiometric => '使用指纹解锁';

  @override
  String get strengthWeak => '弱';

  @override
  String get strengthFair => '一般';

  @override
  String get strengthGood => '较强';

  @override
  String get strengthStrong => '很强';

  @override
  String get homeTitle => '首页';

  @override
  String get homeSubtitle => '本地保险库 · 仅存于本机';

  @override
  String get homeOverview => '保险库概览';

  @override
  String get statLogins => '登录项';

  @override
  String get statTokens => '令牌';

  @override
  String get statSecurity => '待处理';

  @override
  String get homeFavorites => '收藏';

  @override
  String get homeRecent => '最近更新';

  @override
  String homeSecurityAlert(int count) {
    return '有 $count 个条目需要处理';
  }

  @override
  String get homeAllGood => '安全检查全部通过';

  @override
  String get homeEmptyTitle => '还没有条目';

  @override
  String get homeEmptyDesc => '添加第一个登录项，或扫描二维码导入令牌。';

  @override
  String get loginsTitle => '登录项';

  @override
  String get loginsEmpty => '还没有登录项';

  @override
  String get loginsEmptyDesc => '点击右下角加号添加账号密码。';

  @override
  String get tokensTitle => '令牌';

  @override
  String get tokensEmpty => '还没有令牌';

  @override
  String get tokensEmptyDesc => '扫描二维码或手动填写密钥来添加。';

  @override
  String get searchTitle => '搜索';

  @override
  String get searchHint => '搜索名称、账号、网址';

  @override
  String get searchNoResults => '没有匹配的条目';

  @override
  String get searchNoResultsDesc => '换个关键词试试。';

  @override
  String get sortByName => '按名称';

  @override
  String get sortByRecent => '按最近更新';

  @override
  String get sortByFavorites => '收藏优先';

  @override
  String get detailUsername => '账号';

  @override
  String get detailPassword => '密码';

  @override
  String get detailUrl => '网址';

  @override
  String get detailNotes => '备注';

  @override
  String get detailCreated => '创建时间';

  @override
  String get detailUpdated => '更新时间';

  @override
  String get detailTokenType => '类型';

  @override
  String get detailTokenAlgorithm => '算法';

  @override
  String get detailTokenDigits => '位数';

  @override
  String get detailTokenPeriod => '周期';

  @override
  String get detailTokenCounter => '计数器';

  @override
  String get detailShowCode => '显示验证码';

  @override
  String get detailHideCode => '隐藏验证码';

  @override
  String get detailDelete => '移到回收站';

  @override
  String get detailDeleteMessage => '该条目会进入回收站，可随时恢复。';

  @override
  String get detailFavorite => '收藏';

  @override
  String get detailUnfavorite => '取消收藏';

  @override
  String get editorNewLogin => '新建登录项';

  @override
  String get editorNewToken => '新建令牌';

  @override
  String get editorEditLogin => '编辑登录项';

  @override
  String get editorEditToken => '编辑令牌';

  @override
  String get editorTitle => '名称';

  @override
  String get editorTitleHint => '例如 GitHub';

  @override
  String get editorUsername => '账号';

  @override
  String get editorPassword => '密码';

  @override
  String get editorUrl => '网址';

  @override
  String get editorUrls => '网址（每行一个）';

  @override
  String get editorNotes => '备注';

  @override
  String get editorGenerate => '生成随机密码';

  @override
  String get editorTokenIssuer => '服务名';

  @override
  String get editorTokenAccount => '账号';

  @override
  String get editorTokenSecret => '密钥（Base32）';

  @override
  String get editorTokenType => '令牌类型';

  @override
  String get editorAdvanced => '高级设置';

  @override
  String get editorAlgorithm => '算法';

  @override
  String get editorDigits => '位数';

  @override
  String get editorPeriod => '周期（秒）';

  @override
  String get editorCounter => '计数器';

  @override
  String get editorScanQr => '扫描二维码';

  @override
  String get scanCameraUnavailable => '相机不可用，请检查权限后重试';

  @override
  String get editorDiscardTitle => '放弃修改？';

  @override
  String get editorDiscardMessage => '当前填写的内容还没有保存。';

  @override
  String get editorDiscard => '放弃';

  @override
  String get editorUrlInvalid => '网址格式不正确';

  @override
  String get editorSecretInvalid => '密钥不是合法的 Base32';

  @override
  String get editorTitleRequired => '请填写名称';

  @override
  String get tokenTypeTotp => 'TOTP';

  @override
  String get tokenTypeHotp => 'HOTP';

  @override
  String get tokenTypeSteam => 'Steam';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsTheme => '显示模式';

  @override
  String get settingsLanguage => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get settingsAccent => '主题色';

  @override
  String get accentSystem => '跟随系统';

  @override
  String get accentCustom => '自定义';

  @override
  String get accentBlue => '蓝';

  @override
  String get accentTeal => '青';

  @override
  String get accentGreen => '绿';

  @override
  String get accentAmber => '琥珀';

  @override
  String get accentRose => '玫红';

  @override
  String get settingsSecurity => '安全';

  @override
  String get settingsSecureScreen => '防止截屏';

  @override
  String get settingsSecureScreenDesc => '禁止系统截图与录屏';

  @override
  String get settingsClipboardClear => '复制后自动清除';

  @override
  String get settingsClipboardClearDesc => '60 秒后清除密码与验证码';

  @override
  String get settingsAutoLock => '自动锁定';

  @override
  String get autoLockImmediate => '立即';

  @override
  String get autoLock30 => '30 秒';

  @override
  String get autoLock60 => '1 分钟';

  @override
  String get autoLock300 => '5 分钟';

  @override
  String get autoLockNever => '从不';

  @override
  String get settingsBiometric => '指纹解锁';

  @override
  String get settingsBiometricOn => '已启用';

  @override
  String get settingsBiometricOff => '未启用';

  @override
  String get settingsChangePassword => '修改主密码';

  @override
  String get settingsLockNow => '立即锁定';

  @override
  String get settingsTokens => '令牌';

  @override
  String get settingsShowCodes => '显示验证码';

  @override
  String get settingsShowCodesDesc => '关闭后数字显示为圆点，点击查看';

  @override
  String get settingsShowNext => '提前显示下一组';

  @override
  String get settingsShowNextDesc => '在当前验证码下方显示下一组';

  @override
  String get settingsGrouping => '验证码分组';

  @override
  String get groupingAuto => '自动';

  @override
  String get groupingThree => '3 位';

  @override
  String get groupingFour => '4 位';

  @override
  String get groupingNone => '不分组';

  @override
  String get settingsData => '数据';

  @override
  String get settingsExport => '导出加密备份';

  @override
  String get settingsExportDesc => '使用当前主密码加密的 .kcbak 文件';

  @override
  String get settingsImport => '导入加密备份';

  @override
  String get settingsImportDesc => '替换当前保险库';

  @override
  String get settingsAutoSnapshot => '自动快照';

  @override
  String get settingsAutoSnapshotDesc => '每次保存后保留最近 10 份加密快照';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsVersion => '版本';

  @override
  String get settingsPrivacy => '隐私说明';

  @override
  String get settingsLicenses => '开源许可证';

  @override
  String get settingsLicensesDesc => 'Flutter 与第三方组件';

  @override
  String get settingsPrivacyBody =>
      'KeyCase 不上传任何数据：没有账号、没有云同步、没有统计。所有内容都保存在本机的加密容器里。';

  @override
  String get settingsGithub => 'GitHub';

  @override
  String get settingsGithubDesc => 'github.com/LumiDesk/key-case';

  @override
  String get settingsDanger => '危险操作';

  @override
  String get settingsDeleteVault => '删除保险库';

  @override
  String get settingsDeleteVaultDesc => '永久删除本机所有密码和令牌';

  @override
  String get settingsDeleteVaultMessage => '此操作不可撤销，且没有云端副本。建议先导出一份备份。';

  @override
  String get securityTitle => '安全中心';

  @override
  String get securityWeak => '弱密码';

  @override
  String get securityReused => '重复使用的密码';

  @override
  String get securityStale => '长期未更新';

  @override
  String get securityWeakDesc => '长度不足或过于简单，容易被猜到。';

  @override
  String get securityReusedDesc => '同一个密码用在多个账号上，一处泄露会波及全部。';

  @override
  String get securityStaleDesc => '超过一年没有更新过。';

  @override
  String get securityAllGood => '没有发现问题';

  @override
  String get securityAllGoodDesc => '当前登录项的口令都很干净。';

  @override
  String get trashTitle => '回收站';

  @override
  String get trashEmptyCount => '暂无';

  @override
  String get trashEmpty => '回收站是空的';

  @override
  String get trashEmptyDesc => '删除的条目会先放在这里。';

  @override
  String get trashPurge => '永久删除';

  @override
  String get trashPurgeMessage => '永久删除后无法恢复。';

  @override
  String get trashEmptyAll => '清空回收站';

  @override
  String get trashEmptyAllMessage => '回收站里的所有条目都会被永久删除。';

  @override
  String get changePasswordTitle => '修改主密码';

  @override
  String get currentPassword => '当前主密码';

  @override
  String get newPassword => '新主密码';

  @override
  String get confirmNewPassword => '确认新主密码';

  @override
  String get importBackupTitle => '导入加密备份';

  @override
  String get importBackupPassword => '备份的主密码';

  @override
  String get restoreFromBackup => '从加密备份恢复';

  @override
  String get restoreBackupMessage => '将用备份替换当前保险库，并关闭指纹解锁。继续？';

  @override
  String get settingsImportAegis => '从 Aegis 导入';

  @override
  String get settingsImportAegisDesc => '合并 Aegis 导出的动态令牌';

  @override
  String get settingsImportGoogle => '从 Google Authenticator 导入';

  @override
  String get settingsImportGoogleDesc => '粘贴迁移链接，或扫描迁移二维码';

  @override
  String get aegisPasswordTitle => 'Aegis 备份密码';

  @override
  String get aegisPasswordHint => '未加密的备份可留空';

  @override
  String get googleMigrationTitle => 'Google 迁移链接';

  @override
  String get googleMigrationHint => 'otpauth-migration://…';

  @override
  String noticeImported(int count) {
    return '已导入 $count 个条目';
  }

  @override
  String noticeMigrationImported(int count) {
    return '已迁移 $count 个令牌';
  }

  @override
  String get errorAegisPasswordRequired => '这个 Aegis 备份已加密，请输入备份密码';

  @override
  String get errorAegisWrongPassword => 'Aegis 备份密码不正确';

  @override
  String get errorAegisInvalid => '不是有效的 Aegis 导出文件';

  @override
  String get aegisUnnamed => '未命名条目';

  @override
  String get errorMigrationInvalid => '不是有效的 Google 迁移链接';

  @override
  String get editorIcon => '图标';

  @override
  String get iconPickerTitle => '选择图标';

  @override
  String get iconSearchHint => '搜索品牌';

  @override
  String get iconCustom => '使用自定义图片';

  @override
  String get errorImagePickFailed => '无法读取图片';

  @override
  String get iconRemove => '恢复自动匹配';

  @override
  String get noticeVaultCreated => '保险库已创建';

  @override
  String get noticeItemSaved => '已保存';

  @override
  String get noticeItemDeleted => '已移到回收站';

  @override
  String get noticeItemRestored => '已恢复';

  @override
  String get noticeItemPurged => '已永久删除';

  @override
  String get noticeTrashEmptied => '回收站已清空';

  @override
  String get noticePasswordChanged => '主密码已更新';

  @override
  String get noticeBackupExported => '备份已导出';

  @override
  String get noticeBackupImported => '备份已导入';

  @override
  String get noticeSnapshotSaved => '快照已保存';

  @override
  String get noticeFavoriteUpdated => '收藏已更新';

  @override
  String get noticeBiometricEnabled => '已启用指纹解锁';

  @override
  String get noticeBiometricDisabled => '已关闭指纹解锁';

  @override
  String get errorPasswordTooShort => '主密码至少 8 位';

  @override
  String get errorPasswordMismatch => '两次输入的主密码不一致';

  @override
  String get errorPasswordIncorrect => '主密码不正确';

  @override
  String get errorVaultCorrupted => '保险库已损坏或版本不兼容';

  @override
  String get errorVaultLocked => '保险库未解锁';

  @override
  String get errorVaultNotReadable => '无法读取保险库文件';

  @override
  String get errorSaveFailed => '保存失败，请重试';

  @override
  String get errorBackupFailed => '备份操作失败';

  @override
  String get errorBackupUnreadable => '无法读取备份文件';

  @override
  String get errorBackupWrongPassword => '备份的主密码不正确';

  @override
  String get errorBiometricUnavailable => '本机没有可用的生物识别';

  @override
  String get errorBiometricFailed => '指纹验证未通过';

  @override
  String get errorBiometricEnrolledMissing => '指纹解锁失效，请用主密码解锁';

  @override
  String get errorImportFailed => '导入失败';

  @override
  String get errorDeleteFailed => '删除失败';

  @override
  String get errorOpenLinkFailed => '无法打开链接';

  @override
  String get biometricUnlockReason => '验证指纹以解锁 KeyCase';

  @override
  String get biometricEnableReason => '验证指纹以启用快捷解锁';

  @override
  String get deleteVaultAction => '删除保险库';

  @override
  String get errorBackupFolderMissing => '还没有选择备份目录';

  @override
  String get noticeBackupFolderSelected => '备份目录已设置';

  @override
  String get settingsBackupFolder => '备份目录';

  @override
  String get settingsBackupFolderNone => '未选择';

  @override
  String get settingsLastBackup => '上次备份';

  @override
  String get settingsBackupNever => '从未备份';

  @override
  String get settingsBackupNow => '立即备份';

  @override
  String get settingsBackupNowDesc => '生成一份加密快照，保留最近 10 份';

  @override
  String get settingsCheckUpdate => '检查更新';

  @override
  String get updateAvailableTitle => '发现新版本';

  @override
  String get updateCurrentVersion => '当前版本';

  @override
  String get updateLatestVersion => '最新版本';

  @override
  String get updateOpenRelease => '前往下载';

  @override
  String get updateUpToDate => '已是最新版本';

  @override
  String get updateCheckFailed => '检查更新失败';

  @override
  String get themeColorTitle => '自定义主题色';

  @override
  String get themeColorHue => '色相';

  @override
  String get themeColorSaturation => '饱和度';

  @override
  String get themeColorBrightness => '亮度';

  @override
  String get themeColorPreview => '效果预览';

  @override
  String get settingsBackup => '备份';

  @override
  String get tokenAddScan => '扫码添加';

  @override
  String get tokenAddManual => '手动添加';

  @override
  String get timeJustNow => '刚刚';

  @override
  String timeMinutesAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count 小时前';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count 天前';
  }

  @override
  String itemsCount(int count) {
    return '共 $count 条';
  }
}
