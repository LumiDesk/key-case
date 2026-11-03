import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'KeyCase'**
  String get appName;

  /// No description provided for @navHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get navHome;

  /// No description provided for @navLogins.
  ///
  /// In zh, this message translates to:
  /// **'登录项'**
  String get navLogins;

  /// No description provided for @navTokens.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get navTokens;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navSettings;

  /// No description provided for @actionSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get actionEdit;

  /// No description provided for @actionClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get actionClose;

  /// No description provided for @actionCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get actionCopy;

  /// No description provided for @actionBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get actionBack;

  /// No description provided for @actionRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get actionRetry;

  /// No description provided for @actionNext.
  ///
  /// In zh, this message translates to:
  /// **'下一个'**
  String get actionNext;

  /// No description provided for @actionAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get actionAdd;

  /// No description provided for @actionConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get actionConfirm;

  /// No description provided for @actionSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get actionSearch;

  /// No description provided for @actionSort.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get actionSort;

  /// No description provided for @actionDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get actionDone;

  /// No description provided for @actionRestore.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get actionRestore;

  /// No description provided for @pressBackAgainToExit.
  ///
  /// In zh, this message translates to:
  /// **'再次返回退出软件'**
  String get pressBackAgainToExit;

  /// No description provided for @copied.
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get copied;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'处理中…'**
  String get loading;

  /// No description provided for @createTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建你的保险库'**
  String get createTitle;

  /// No description provided for @createSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'主密码只保存在你的脑子里。忘记它，没人能帮你恢复。'**
  String get createSubtitle;

  /// No description provided for @masterPassword.
  ///
  /// In zh, this message translates to:
  /// **'主密码'**
  String get masterPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In zh, this message translates to:
  /// **'确认主密码'**
  String get confirmPassword;

  /// No description provided for @passwordHint.
  ///
  /// In zh, this message translates to:
  /// **'至少 8 位'**
  String get passwordHint;

  /// No description provided for @createVault.
  ///
  /// In zh, this message translates to:
  /// **'创建保险库'**
  String get createVault;

  /// No description provided for @unlockTitle.
  ///
  /// In zh, this message translates to:
  /// **'解锁 KeyCase'**
  String get unlockTitle;

  /// No description provided for @unlockSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'输入主密码继续'**
  String get unlockSubtitle;

  /// No description provided for @unlock.
  ///
  /// In zh, this message translates to:
  /// **'解锁'**
  String get unlock;

  /// No description provided for @useBiometric.
  ///
  /// In zh, this message translates to:
  /// **'使用指纹解锁'**
  String get useBiometric;

  /// No description provided for @strengthWeak.
  ///
  /// In zh, this message translates to:
  /// **'弱'**
  String get strengthWeak;

  /// No description provided for @strengthFair.
  ///
  /// In zh, this message translates to:
  /// **'一般'**
  String get strengthFair;

  /// No description provided for @strengthGood.
  ///
  /// In zh, this message translates to:
  /// **'较强'**
  String get strengthGood;

  /// No description provided for @strengthStrong.
  ///
  /// In zh, this message translates to:
  /// **'很强'**
  String get strengthStrong;

  /// No description provided for @homeTitle.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get homeTitle;

  /// No description provided for @homeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'本地保险库 · 仅存于本机'**
  String get homeSubtitle;

  /// No description provided for @homeOverview.
  ///
  /// In zh, this message translates to:
  /// **'保险库概览'**
  String get homeOverview;

  /// No description provided for @statLogins.
  ///
  /// In zh, this message translates to:
  /// **'登录项'**
  String get statLogins;

  /// No description provided for @statTokens.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get statTokens;

  /// No description provided for @statSecurity.
  ///
  /// In zh, this message translates to:
  /// **'待处理'**
  String get statSecurity;

  /// No description provided for @homeFavorites.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get homeFavorites;

  /// No description provided for @homeRecent.
  ///
  /// In zh, this message translates to:
  /// **'最近更新'**
  String get homeRecent;

  /// No description provided for @homeSecurityAlert.
  ///
  /// In zh, this message translates to:
  /// **'有 {count} 个条目需要处理'**
  String homeSecurityAlert(int count);

  /// No description provided for @homeAllGood.
  ///
  /// In zh, this message translates to:
  /// **'安全检查全部通过'**
  String get homeAllGood;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有条目'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyDesc.
  ///
  /// In zh, this message translates to:
  /// **'添加第一个登录项，或扫描二维码导入令牌。'**
  String get homeEmptyDesc;

  /// No description provided for @loginsTitle.
  ///
  /// In zh, this message translates to:
  /// **'登录项'**
  String get loginsTitle;

  /// No description provided for @loginsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有登录项'**
  String get loginsEmpty;

  /// No description provided for @loginsEmptyDesc.
  ///
  /// In zh, this message translates to:
  /// **'点击右下角加号添加账号密码。'**
  String get loginsEmptyDesc;

  /// No description provided for @tokensTitle.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get tokensTitle;

  /// No description provided for @tokensEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有令牌'**
  String get tokensEmpty;

  /// No description provided for @tokensEmptyDesc.
  ///
  /// In zh, this message translates to:
  /// **'扫描二维码或手动填写密钥来添加。'**
  String get tokensEmptyDesc;

  /// No description provided for @searchTitle.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索名称、账号、网址'**
  String get searchHint;

  /// No description provided for @searchNoResults.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的条目'**
  String get searchNoResults;

  /// No description provided for @searchNoResultsDesc.
  ///
  /// In zh, this message translates to:
  /// **'换个关键词试试。'**
  String get searchNoResultsDesc;

  /// No description provided for @sortByName.
  ///
  /// In zh, this message translates to:
  /// **'按名称'**
  String get sortByName;

  /// No description provided for @sortByRecent.
  ///
  /// In zh, this message translates to:
  /// **'按最近更新'**
  String get sortByRecent;

  /// No description provided for @sortByFavorites.
  ///
  /// In zh, this message translates to:
  /// **'收藏优先'**
  String get sortByFavorites;

  /// No description provided for @detailUsername.
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get detailUsername;

  /// No description provided for @detailPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get detailPassword;

  /// No description provided for @detailUrl.
  ///
  /// In zh, this message translates to:
  /// **'网址'**
  String get detailUrl;

  /// No description provided for @detailNotes.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get detailNotes;

  /// No description provided for @detailCreated.
  ///
  /// In zh, this message translates to:
  /// **'创建时间'**
  String get detailCreated;

  /// No description provided for @detailUpdated.
  ///
  /// In zh, this message translates to:
  /// **'更新时间'**
  String get detailUpdated;

  /// No description provided for @detailTokenType.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get detailTokenType;

  /// No description provided for @detailTokenAlgorithm.
  ///
  /// In zh, this message translates to:
  /// **'算法'**
  String get detailTokenAlgorithm;

  /// No description provided for @detailTokenDigits.
  ///
  /// In zh, this message translates to:
  /// **'位数'**
  String get detailTokenDigits;

  /// No description provided for @detailTokenPeriod.
  ///
  /// In zh, this message translates to:
  /// **'周期'**
  String get detailTokenPeriod;

  /// No description provided for @detailTokenCounter.
  ///
  /// In zh, this message translates to:
  /// **'计数器'**
  String get detailTokenCounter;

  /// No description provided for @detailShowCode.
  ///
  /// In zh, this message translates to:
  /// **'显示验证码'**
  String get detailShowCode;

  /// No description provided for @detailHideCode.
  ///
  /// In zh, this message translates to:
  /// **'隐藏验证码'**
  String get detailHideCode;

  /// No description provided for @detailDelete.
  ///
  /// In zh, this message translates to:
  /// **'移到回收站'**
  String get detailDelete;

  /// No description provided for @detailDeleteMessage.
  ///
  /// In zh, this message translates to:
  /// **'该条目会进入回收站，可随时恢复。'**
  String get detailDeleteMessage;

  /// No description provided for @detailFavorite.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get detailFavorite;

  /// No description provided for @detailUnfavorite.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get detailUnfavorite;

  /// No description provided for @editorNewLogin.
  ///
  /// In zh, this message translates to:
  /// **'新建登录项'**
  String get editorNewLogin;

  /// No description provided for @editorNewToken.
  ///
  /// In zh, this message translates to:
  /// **'新建令牌'**
  String get editorNewToken;

  /// No description provided for @editorEditLogin.
  ///
  /// In zh, this message translates to:
  /// **'编辑登录项'**
  String get editorEditLogin;

  /// No description provided for @editorEditToken.
  ///
  /// In zh, this message translates to:
  /// **'编辑令牌'**
  String get editorEditToken;

  /// No description provided for @editorTitle.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get editorTitle;

  /// No description provided for @editorTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 GitHub'**
  String get editorTitleHint;

  /// No description provided for @editorUsername.
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get editorUsername;

  /// No description provided for @editorPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get editorPassword;

  /// No description provided for @editorUrl.
  ///
  /// In zh, this message translates to:
  /// **'网址'**
  String get editorUrl;

  /// No description provided for @editorNotes.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get editorNotes;

  /// No description provided for @editorGenerate.
  ///
  /// In zh, this message translates to:
  /// **'生成随机密码'**
  String get editorGenerate;

  /// No description provided for @editorTokenIssuer.
  ///
  /// In zh, this message translates to:
  /// **'服务名'**
  String get editorTokenIssuer;

  /// No description provided for @editorTokenAccount.
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get editorTokenAccount;

  /// No description provided for @editorTokenSecret.
  ///
  /// In zh, this message translates to:
  /// **'密钥（Base32）'**
  String get editorTokenSecret;

  /// No description provided for @editorTokenType.
  ///
  /// In zh, this message translates to:
  /// **'令牌类型'**
  String get editorTokenType;

  /// No description provided for @editorAdvanced.
  ///
  /// In zh, this message translates to:
  /// **'高级设置'**
  String get editorAdvanced;

  /// No description provided for @editorAlgorithm.
  ///
  /// In zh, this message translates to:
  /// **'算法'**
  String get editorAlgorithm;

  /// No description provided for @editorDigits.
  ///
  /// In zh, this message translates to:
  /// **'位数'**
  String get editorDigits;

  /// No description provided for @editorPeriod.
  ///
  /// In zh, this message translates to:
  /// **'周期（秒）'**
  String get editorPeriod;

  /// No description provided for @editorCounter.
  ///
  /// In zh, this message translates to:
  /// **'计数器'**
  String get editorCounter;

  /// No description provided for @editorScanQr.
  ///
  /// In zh, this message translates to:
  /// **'扫描二维码'**
  String get editorScanQr;

  /// No description provided for @scanCameraUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'相机不可用，请检查权限后重试'**
  String get scanCameraUnavailable;

  /// No description provided for @editorDiscardTitle.
  ///
  /// In zh, this message translates to:
  /// **'放弃修改？'**
  String get editorDiscardTitle;

  /// No description provided for @editorDiscardMessage.
  ///
  /// In zh, this message translates to:
  /// **'当前填写的内容还没有保存。'**
  String get editorDiscardMessage;

  /// No description provided for @editorDiscard.
  ///
  /// In zh, this message translates to:
  /// **'放弃'**
  String get editorDiscard;

  /// No description provided for @editorUrlInvalid.
  ///
  /// In zh, this message translates to:
  /// **'网址格式不正确'**
  String get editorUrlInvalid;

  /// No description provided for @editorSecretInvalid.
  ///
  /// In zh, this message translates to:
  /// **'密钥不是合法的 Base32'**
  String get editorSecretInvalid;

  /// No description provided for @editorTitleRequired.
  ///
  /// In zh, this message translates to:
  /// **'请填写名称'**
  String get editorTitleRequired;

  /// No description provided for @tokenTypeTotp.
  ///
  /// In zh, this message translates to:
  /// **'TOTP'**
  String get tokenTypeTotp;

  /// No description provided for @tokenTypeHotp.
  ///
  /// In zh, this message translates to:
  /// **'HOTP'**
  String get tokenTypeHotp;

  /// No description provided for @tokenTypeSteam.
  ///
  /// In zh, this message translates to:
  /// **'Steam'**
  String get tokenTypeSteam;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In zh, this message translates to:
  /// **'显示模式'**
  String get settingsTheme;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguage;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @settingsAccent.
  ///
  /// In zh, this message translates to:
  /// **'主题色'**
  String get settingsAccent;

  /// No description provided for @accentSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get accentSystem;

  /// No description provided for @accentCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get accentCustom;

  /// No description provided for @accentBlue.
  ///
  /// In zh, this message translates to:
  /// **'蓝'**
  String get accentBlue;

  /// No description provided for @accentTeal.
  ///
  /// In zh, this message translates to:
  /// **'青'**
  String get accentTeal;

  /// No description provided for @accentGreen.
  ///
  /// In zh, this message translates to:
  /// **'绿'**
  String get accentGreen;

  /// No description provided for @accentAmber.
  ///
  /// In zh, this message translates to:
  /// **'琥珀'**
  String get accentAmber;

  /// No description provided for @accentRose.
  ///
  /// In zh, this message translates to:
  /// **'玫红'**
  String get accentRose;

  /// No description provided for @settingsSecurity.
  ///
  /// In zh, this message translates to:
  /// **'安全'**
  String get settingsSecurity;

  /// No description provided for @settingsSecureScreen.
  ///
  /// In zh, this message translates to:
  /// **'防止截屏'**
  String get settingsSecureScreen;

  /// No description provided for @settingsSecureScreenDesc.
  ///
  /// In zh, this message translates to:
  /// **'禁止系统截图与录屏'**
  String get settingsSecureScreenDesc;

  /// No description provided for @settingsClipboardClear.
  ///
  /// In zh, this message translates to:
  /// **'复制后自动清除'**
  String get settingsClipboardClear;

  /// No description provided for @settingsClipboardClearDesc.
  ///
  /// In zh, this message translates to:
  /// **'60 秒后清除密码与验证码'**
  String get settingsClipboardClearDesc;

  /// No description provided for @settingsAutoLock.
  ///
  /// In zh, this message translates to:
  /// **'自动锁定'**
  String get settingsAutoLock;

  /// No description provided for @autoLockImmediate.
  ///
  /// In zh, this message translates to:
  /// **'立即'**
  String get autoLockImmediate;

  /// No description provided for @autoLock30.
  ///
  /// In zh, this message translates to:
  /// **'30 秒'**
  String get autoLock30;

  /// No description provided for @autoLock60.
  ///
  /// In zh, this message translates to:
  /// **'1 分钟'**
  String get autoLock60;

  /// No description provided for @autoLock300.
  ///
  /// In zh, this message translates to:
  /// **'5 分钟'**
  String get autoLock300;

  /// No description provided for @autoLockNever.
  ///
  /// In zh, this message translates to:
  /// **'从不'**
  String get autoLockNever;

  /// No description provided for @settingsBiometric.
  ///
  /// In zh, this message translates to:
  /// **'指纹解锁'**
  String get settingsBiometric;

  /// No description provided for @settingsBiometricOn.
  ///
  /// In zh, this message translates to:
  /// **'已启用'**
  String get settingsBiometricOn;

  /// No description provided for @settingsBiometricOff.
  ///
  /// In zh, this message translates to:
  /// **'未启用'**
  String get settingsBiometricOff;

  /// No description provided for @settingsChangePassword.
  ///
  /// In zh, this message translates to:
  /// **'修改主密码'**
  String get settingsChangePassword;

  /// No description provided for @settingsLockNow.
  ///
  /// In zh, this message translates to:
  /// **'立即锁定'**
  String get settingsLockNow;

  /// No description provided for @settingsTokens.
  ///
  /// In zh, this message translates to:
  /// **'令牌'**
  String get settingsTokens;

  /// No description provided for @settingsShowCodes.
  ///
  /// In zh, this message translates to:
  /// **'显示验证码'**
  String get settingsShowCodes;

  /// No description provided for @settingsShowCodesDesc.
  ///
  /// In zh, this message translates to:
  /// **'关闭后数字显示为圆点，点击查看'**
  String get settingsShowCodesDesc;

  /// No description provided for @settingsShowNext.
  ///
  /// In zh, this message translates to:
  /// **'提前显示下一组'**
  String get settingsShowNext;

  /// No description provided for @settingsShowNextDesc.
  ///
  /// In zh, this message translates to:
  /// **'在当前验证码下方显示下一组'**
  String get settingsShowNextDesc;

  /// No description provided for @settingsGrouping.
  ///
  /// In zh, this message translates to:
  /// **'验证码分组'**
  String get settingsGrouping;

  /// No description provided for @groupingAuto.
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get groupingAuto;

  /// No description provided for @groupingThree.
  ///
  /// In zh, this message translates to:
  /// **'3 位'**
  String get groupingThree;

  /// No description provided for @groupingFour.
  ///
  /// In zh, this message translates to:
  /// **'4 位'**
  String get groupingFour;

  /// No description provided for @groupingNone.
  ///
  /// In zh, this message translates to:
  /// **'不分组'**
  String get groupingNone;

  /// No description provided for @settingsData.
  ///
  /// In zh, this message translates to:
  /// **'数据'**
  String get settingsData;

  /// No description provided for @settingsExport.
  ///
  /// In zh, this message translates to:
  /// **'导出加密备份'**
  String get settingsExport;

  /// No description provided for @settingsExportDesc.
  ///
  /// In zh, this message translates to:
  /// **'使用当前主密码加密的 .kcbak 文件'**
  String get settingsExportDesc;

  /// No description provided for @settingsImport.
  ///
  /// In zh, this message translates to:
  /// **'导入加密备份'**
  String get settingsImport;

  /// No description provided for @settingsImportDesc.
  ///
  /// In zh, this message translates to:
  /// **'替换当前保险库'**
  String get settingsImportDesc;

  /// No description provided for @settingsAutoSnapshot.
  ///
  /// In zh, this message translates to:
  /// **'自动快照'**
  String get settingsAutoSnapshot;

  /// No description provided for @settingsAutoSnapshotDesc.
  ///
  /// In zh, this message translates to:
  /// **'每次保存后保留最近 10 份加密快照'**
  String get settingsAutoSnapshotDesc;

  /// No description provided for @settingsAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get settingsVersion;

  /// No description provided for @settingsPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'隐私说明'**
  String get settingsPrivacy;

  /// No description provided for @settingsPrivacyBody.
  ///
  /// In zh, this message translates to:
  /// **'KeyCase 不上传任何数据：没有账号、没有云同步、没有统计。所有内容都保存在本机的加密容器里。'**
  String get settingsPrivacyBody;

  /// No description provided for @settingsGithub.
  ///
  /// In zh, this message translates to:
  /// **'GitHub'**
  String get settingsGithub;

  /// No description provided for @settingsGithubDesc.
  ///
  /// In zh, this message translates to:
  /// **'github.com/LumiDesk/key-case'**
  String get settingsGithubDesc;

  /// No description provided for @settingsDanger.
  ///
  /// In zh, this message translates to:
  /// **'危险操作'**
  String get settingsDanger;

  /// No description provided for @settingsDeleteVault.
  ///
  /// In zh, this message translates to:
  /// **'删除保险库'**
  String get settingsDeleteVault;

  /// No description provided for @settingsDeleteVaultDesc.
  ///
  /// In zh, this message translates to:
  /// **'永久删除本机所有密码和令牌'**
  String get settingsDeleteVaultDesc;

  /// No description provided for @settingsDeleteVaultMessage.
  ///
  /// In zh, this message translates to:
  /// **'此操作不可撤销，且没有云端副本。建议先导出一份备份。'**
  String get settingsDeleteVaultMessage;

  /// No description provided for @securityTitle.
  ///
  /// In zh, this message translates to:
  /// **'安全中心'**
  String get securityTitle;

  /// No description provided for @securityWeak.
  ///
  /// In zh, this message translates to:
  /// **'弱密码'**
  String get securityWeak;

  /// No description provided for @securityReused.
  ///
  /// In zh, this message translates to:
  /// **'重复使用的密码'**
  String get securityReused;

  /// No description provided for @securityStale.
  ///
  /// In zh, this message translates to:
  /// **'长期未更新'**
  String get securityStale;

  /// No description provided for @securityWeakDesc.
  ///
  /// In zh, this message translates to:
  /// **'长度不足或过于简单，容易被猜到。'**
  String get securityWeakDesc;

  /// No description provided for @securityReusedDesc.
  ///
  /// In zh, this message translates to:
  /// **'同一个密码用在多个账号上，一处泄露会波及全部。'**
  String get securityReusedDesc;

  /// No description provided for @securityStaleDesc.
  ///
  /// In zh, this message translates to:
  /// **'超过一年没有更新过。'**
  String get securityStaleDesc;

  /// No description provided for @securityAllGood.
  ///
  /// In zh, this message translates to:
  /// **'没有发现问题'**
  String get securityAllGood;

  /// No description provided for @securityAllGoodDesc.
  ///
  /// In zh, this message translates to:
  /// **'当前登录项的口令都很干净。'**
  String get securityAllGoodDesc;

  /// No description provided for @trashTitle.
  ///
  /// In zh, this message translates to:
  /// **'回收站'**
  String get trashTitle;

  /// No description provided for @trashEmptyCount.
  ///
  /// In zh, this message translates to:
  /// **'暂无'**
  String get trashEmptyCount;

  /// No description provided for @trashEmpty.
  ///
  /// In zh, this message translates to:
  /// **'回收站是空的'**
  String get trashEmpty;

  /// No description provided for @trashEmptyDesc.
  ///
  /// In zh, this message translates to:
  /// **'删除的条目会先放在这里。'**
  String get trashEmptyDesc;

  /// No description provided for @trashPurge.
  ///
  /// In zh, this message translates to:
  /// **'永久删除'**
  String get trashPurge;

  /// No description provided for @trashPurgeMessage.
  ///
  /// In zh, this message translates to:
  /// **'永久删除后无法恢复。'**
  String get trashPurgeMessage;

  /// No description provided for @trashEmptyAll.
  ///
  /// In zh, this message translates to:
  /// **'清空回收站'**
  String get trashEmptyAll;

  /// No description provided for @trashEmptyAllMessage.
  ///
  /// In zh, this message translates to:
  /// **'回收站里的所有条目都会被永久删除。'**
  String get trashEmptyAllMessage;

  /// No description provided for @changePasswordTitle.
  ///
  /// In zh, this message translates to:
  /// **'修改主密码'**
  String get changePasswordTitle;

  /// No description provided for @currentPassword.
  ///
  /// In zh, this message translates to:
  /// **'当前主密码'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In zh, this message translates to:
  /// **'新主密码'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In zh, this message translates to:
  /// **'确认新主密码'**
  String get confirmNewPassword;

  /// No description provided for @importBackupTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入加密备份'**
  String get importBackupTitle;

  /// No description provided for @importBackupPassword.
  ///
  /// In zh, this message translates to:
  /// **'备份的主密码'**
  String get importBackupPassword;

  /// No description provided for @importBackupAction.
  ///
  /// In zh, this message translates to:
  /// **'导入并替换'**
  String get importBackupAction;

  /// No description provided for @settingsImportAegis.
  ///
  /// In zh, this message translates to:
  /// **'从 Aegis 导入'**
  String get settingsImportAegis;

  /// No description provided for @settingsImportAegisDesc.
  ///
  /// In zh, this message translates to:
  /// **'合并 Aegis 导出的动态令牌'**
  String get settingsImportAegisDesc;

  /// No description provided for @settingsImportGoogle.
  ///
  /// In zh, this message translates to:
  /// **'从 Google Authenticator 导入'**
  String get settingsImportGoogle;

  /// No description provided for @settingsImportGoogleDesc.
  ///
  /// In zh, this message translates to:
  /// **'粘贴迁移链接，或扫描迁移二维码'**
  String get settingsImportGoogleDesc;

  /// No description provided for @aegisPasswordTitle.
  ///
  /// In zh, this message translates to:
  /// **'Aegis 备份密码'**
  String get aegisPasswordTitle;

  /// No description provided for @aegisPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'未加密的备份可留空'**
  String get aegisPasswordHint;

  /// No description provided for @googleMigrationTitle.
  ///
  /// In zh, this message translates to:
  /// **'Google 迁移链接'**
  String get googleMigrationTitle;

  /// No description provided for @googleMigrationHint.
  ///
  /// In zh, this message translates to:
  /// **'otpauth-migration://…'**
  String get googleMigrationHint;

  /// No description provided for @noticeImported.
  ///
  /// In zh, this message translates to:
  /// **'已导入 {count} 个条目'**
  String noticeImported(int count);

  /// No description provided for @noticeMigrationImported.
  ///
  /// In zh, this message translates to:
  /// **'已迁移 {count} 个令牌'**
  String noticeMigrationImported(int count);

  /// No description provided for @errorAegisPasswordRequired.
  ///
  /// In zh, this message translates to:
  /// **'这个 Aegis 备份已加密，请输入备份密码'**
  String get errorAegisPasswordRequired;

  /// No description provided for @errorAegisWrongPassword.
  ///
  /// In zh, this message translates to:
  /// **'Aegis 备份密码不正确'**
  String get errorAegisWrongPassword;

  /// No description provided for @errorAegisInvalid.
  ///
  /// In zh, this message translates to:
  /// **'不是有效的 Aegis 导出文件'**
  String get errorAegisInvalid;

  /// No description provided for @errorMigrationInvalid.
  ///
  /// In zh, this message translates to:
  /// **'不是有效的 Google 迁移链接'**
  String get errorMigrationInvalid;

  /// No description provided for @editorIcon.
  ///
  /// In zh, this message translates to:
  /// **'图标'**
  String get editorIcon;

  /// No description provided for @iconPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择图标'**
  String get iconPickerTitle;

  /// No description provided for @iconSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索品牌'**
  String get iconSearchHint;

  /// No description provided for @iconCustom.
  ///
  /// In zh, this message translates to:
  /// **'使用自定义图片'**
  String get iconCustom;

  /// No description provided for @iconRemove.
  ///
  /// In zh, this message translates to:
  /// **'恢复自动匹配'**
  String get iconRemove;

  /// No description provided for @noticeVaultCreated.
  ///
  /// In zh, this message translates to:
  /// **'保险库已创建'**
  String get noticeVaultCreated;

  /// No description provided for @noticeItemSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get noticeItemSaved;

  /// No description provided for @noticeItemDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已移到回收站'**
  String get noticeItemDeleted;

  /// No description provided for @noticeItemRestored.
  ///
  /// In zh, this message translates to:
  /// **'已恢复'**
  String get noticeItemRestored;

  /// No description provided for @noticeItemPurged.
  ///
  /// In zh, this message translates to:
  /// **'已永久删除'**
  String get noticeItemPurged;

  /// No description provided for @noticeTrashEmptied.
  ///
  /// In zh, this message translates to:
  /// **'回收站已清空'**
  String get noticeTrashEmptied;

  /// No description provided for @noticePasswordChanged.
  ///
  /// In zh, this message translates to:
  /// **'主密码已更新'**
  String get noticePasswordChanged;

  /// No description provided for @noticeBackupExported.
  ///
  /// In zh, this message translates to:
  /// **'备份已导出'**
  String get noticeBackupExported;

  /// No description provided for @noticeBackupImported.
  ///
  /// In zh, this message translates to:
  /// **'备份已导入'**
  String get noticeBackupImported;

  /// No description provided for @noticeSnapshotSaved.
  ///
  /// In zh, this message translates to:
  /// **'快照已保存'**
  String get noticeSnapshotSaved;

  /// No description provided for @noticeFavoriteUpdated.
  ///
  /// In zh, this message translates to:
  /// **'收藏已更新'**
  String get noticeFavoriteUpdated;

  /// No description provided for @noticeBiometricEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已启用指纹解锁'**
  String get noticeBiometricEnabled;

  /// No description provided for @noticeBiometricDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已关闭指纹解锁'**
  String get noticeBiometricDisabled;

  /// No description provided for @errorPasswordTooShort.
  ///
  /// In zh, this message translates to:
  /// **'主密码至少 8 位'**
  String get errorPasswordTooShort;

  /// No description provided for @errorPasswordMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的主密码不一致'**
  String get errorPasswordMismatch;

  /// No description provided for @errorPasswordIncorrect.
  ///
  /// In zh, this message translates to:
  /// **'主密码不正确'**
  String get errorPasswordIncorrect;

  /// No description provided for @errorVaultCorrupted.
  ///
  /// In zh, this message translates to:
  /// **'保险库已损坏或版本不兼容'**
  String get errorVaultCorrupted;

  /// No description provided for @errorVaultLocked.
  ///
  /// In zh, this message translates to:
  /// **'保险库未解锁'**
  String get errorVaultLocked;

  /// No description provided for @errorVaultNotReadable.
  ///
  /// In zh, this message translates to:
  /// **'无法读取保险库文件'**
  String get errorVaultNotReadable;

  /// No description provided for @errorSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败，请重试'**
  String get errorSaveFailed;

  /// No description provided for @errorBackupFailed.
  ///
  /// In zh, this message translates to:
  /// **'备份操作失败'**
  String get errorBackupFailed;

  /// No description provided for @errorBackupUnreadable.
  ///
  /// In zh, this message translates to:
  /// **'无法读取备份文件'**
  String get errorBackupUnreadable;

  /// No description provided for @errorBackupWrongPassword.
  ///
  /// In zh, this message translates to:
  /// **'备份的主密码不正确'**
  String get errorBackupWrongPassword;

  /// No description provided for @errorBiometricUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'本机没有可用的生物识别'**
  String get errorBiometricUnavailable;

  /// No description provided for @errorBiometricFailed.
  ///
  /// In zh, this message translates to:
  /// **'指纹验证未通过'**
  String get errorBiometricFailed;

  /// No description provided for @errorBiometricEnrolledMissing.
  ///
  /// In zh, this message translates to:
  /// **'指纹解锁失效，请用主密码解锁'**
  String get errorBiometricEnrolledMissing;

  /// No description provided for @errorImportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败'**
  String get errorImportFailed;

  /// No description provided for @errorDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败'**
  String get errorDeleteFailed;

  /// No description provided for @errorOpenLinkFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接'**
  String get errorOpenLinkFailed;

  /// No description provided for @biometricUnlockReason.
  ///
  /// In zh, this message translates to:
  /// **'验证指纹以解锁 KeyCase'**
  String get biometricUnlockReason;

  /// No description provided for @biometricEnableReason.
  ///
  /// In zh, this message translates to:
  /// **'验证指纹以启用快捷解锁'**
  String get biometricEnableReason;

  /// No description provided for @deleteVaultAction.
  ///
  /// In zh, this message translates to:
  /// **'删除保险库'**
  String get deleteVaultAction;

  /// No description provided for @errorBackupFolderMissing.
  ///
  /// In zh, this message translates to:
  /// **'还没有选择备份目录'**
  String get errorBackupFolderMissing;

  /// No description provided for @noticeBackupFolderSelected.
  ///
  /// In zh, this message translates to:
  /// **'备份目录已设置'**
  String get noticeBackupFolderSelected;

  /// No description provided for @settingsBackupFolder.
  ///
  /// In zh, this message translates to:
  /// **'备份目录'**
  String get settingsBackupFolder;

  /// No description provided for @settingsBackupFolderNone.
  ///
  /// In zh, this message translates to:
  /// **'未选择'**
  String get settingsBackupFolderNone;

  /// No description provided for @settingsLastBackup.
  ///
  /// In zh, this message translates to:
  /// **'上次备份'**
  String get settingsLastBackup;

  /// No description provided for @settingsBackupNever.
  ///
  /// In zh, this message translates to:
  /// **'从未备份'**
  String get settingsBackupNever;

  /// No description provided for @settingsBackupNow.
  ///
  /// In zh, this message translates to:
  /// **'立即备份'**
  String get settingsBackupNow;

  /// No description provided for @settingsBackupNowDesc.
  ///
  /// In zh, this message translates to:
  /// **'生成一份加密快照，保留最近 10 份'**
  String get settingsBackupNowDesc;

  /// No description provided for @settingsCheckUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get settingsCheckUpdate;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本'**
  String get updateAvailableTitle;

  /// No description provided for @updateCurrentVersion.
  ///
  /// In zh, this message translates to:
  /// **'当前版本'**
  String get updateCurrentVersion;

  /// No description provided for @updateLatestVersion.
  ///
  /// In zh, this message translates to:
  /// **'最新版本'**
  String get updateLatestVersion;

  /// No description provided for @updateOpenRelease.
  ///
  /// In zh, this message translates to:
  /// **'前往下载'**
  String get updateOpenRelease;

  /// No description provided for @updateUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get updateUpToDate;

  /// No description provided for @updateCheckFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败'**
  String get updateCheckFailed;

  /// No description provided for @themeColorTitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义主题色'**
  String get themeColorTitle;

  /// No description provided for @themeColorHue.
  ///
  /// In zh, this message translates to:
  /// **'色相'**
  String get themeColorHue;

  /// No description provided for @themeColorSaturation.
  ///
  /// In zh, this message translates to:
  /// **'饱和度'**
  String get themeColorSaturation;

  /// No description provided for @themeColorBrightness.
  ///
  /// In zh, this message translates to:
  /// **'亮度'**
  String get themeColorBrightness;

  /// No description provided for @themeColorPreview.
  ///
  /// In zh, this message translates to:
  /// **'效果预览'**
  String get themeColorPreview;

  /// No description provided for @settingsBackup.
  ///
  /// In zh, this message translates to:
  /// **'备份'**
  String get settingsBackup;

  /// No description provided for @tokenAddScan.
  ///
  /// In zh, this message translates to:
  /// **'扫码添加'**
  String get tokenAddScan;

  /// No description provided for @tokenAddManual.
  ///
  /// In zh, this message translates to:
  /// **'手动添加'**
  String get tokenAddManual;

  /// No description provided for @timeJustNow.
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count} 分钟前'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count} 小时前'**
  String timeHoursAgo(int count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count} 天前'**
  String timeDaysAgo(int count);

  /// No description provided for @itemsCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 条'**
  String itemsCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
