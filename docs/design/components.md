# 组件与纯函数注册表

新增 Widget / 弹层 / 纯函数前先查这里；命中就复用或参数化扩展，不再造同构变体。
新增、改名或删除可复用件时同步本文件。

## 1. 页面骨架（`lib/app/common_widgets_scaffold.dart`）

| 组件 | 用途 |
|---|---|
| `KcPage` | 页面容器：背景色、左右 2dp 补偿、最大宽度 440dp |
| `KcCard` | 内容卡片：16 圆角、细描边、默认内边距 14×12、可选 `onTap` |
| `KcHeader` | 根页面头：标题 + 副标题 + 右侧动作，固定 56dp |
| `KcSubHeader` | 二级页头：返回按钮 + 标题 + 动作 |
| `KcSectionLabel` | 卡片外的分组标签 |
| `KcEmptyState` | 空态：圆形图标 + 标题 + 说明 + 可选主操作 |
| `KcTopProgress` | 顶部不定长进度条 |

## 2. 展示（`lib/app/common_widgets_display.dart`）

| 组件 | 用途 |
|---|---|
| `LetterAvatar` | 首字母头像，颜色按内容哈希稳定 |
| `KcItemIcon` | 条目图标：品牌图标优先，回落到头像 |
| `KcCodeCapsule` | 验证码胶囊（可隐藏、点击复制） |
| `KcCountdownRing` | 倒计时环，最后 5 秒转警示色 |
| `KcDetailRow` | 详情行：标签 + 值 + 复制/尾随操作 |

## 3. 表单（`lib/app/common_widgets_forms.dart`）

| 组件 | 用途 |
|---|---|
| `KcSettingsRow` | 设置行：图标 + 标题/副标题 + 尾随控件或 chevron |
| `KcSwitchRow` | 开关行（整行可点） |
| `KcRowDivider` | 卡片内分隔线（缩进到图标下方） |
| `KcSegmentedControl<T>` | 2–4 项分段控件 |
| `KcLabeledField` | 带外置标签的输入框 |

## 4. 弹层（`lib/pages/sheets.dart`）

| 入口 | 用途 |
|---|---|
| `showKcSheet<T>` | 统一底部弹层（圆角、拖拽把手、安全区、最大宽度） |
| `showKcConfirm` | 二次确认，`destructive: true` 用于危险操作 |
| `showKcTextInput` | 单行/多行文本输入，取消返回 `null` |
| `showKcOptionSheet<T>` | 短单选列表（标题 + 选项 + 当前值标记） |
| `copyToClipboard` | 复制 + 轻反馈，全应用统一入口 |

排序等 2–8 项静态单选直接使用外部库 `package:anchored_menu` 的
`AnchoredMenuButton` / `AnchoredMenuChoice<T>`；视觉令牌在 `buildKeyCaseTheme()` 里通过
`AnchoredMenuThemeData` 桥接，页面不覆写颜色与圆角。

## 5. 领域组件

| 组件 | 位置 | 用途 |
|---|---|---|
| `KcLoginTile` | `lib/pages/item_tiles.dart` | 登录项行 |
| `KcTokenTile` | `lib/pages/item_tiles.dart` | 令牌行（验证码 + 倒计时） |
| `KcLetterHeader` | `lib/pages/item_tiles.dart` | 字母分组头 |
| `AegisIcon` | `lib/app/icons/aegis_icon.dart` | 品牌 SVG 渲染 |
| `KcFeedbackHost` | `lib/app/feedback.dart` | 根级轻反馈宿主 |

## 6. 纯函数

| 函数 | 位置 | 说明 |
|---|---|---|
| `generateOtpCode` / `otpCounterAt` / `otpSecondsRemaining` | `lib/app/otp/otp.dart` | RFC 6238 / 4226 / Steam |
| `formatOtpCode` / `hiddenOtpCode` | `lib/app/otp/otp.dart` | 分组与隐藏态排版 |
| `parseOtpauthUri` / `buildOtpauthUri` | `lib/app/import/otpauth_parser.dart` | 链接解析与生成 |
| `auditVault` / `isWeakPassword` / `masterPasswordScore` | `lib/app/security/security_audit.dart` | 安全中心 |
| `sortItems` / `groupByInitial` / `searchItems` | `lib/app/vault/vault_query.dart` | 列表排序/分组/搜索 |
| `normalizeUrl` / `displayUrl` | `lib/app/util/url_tools.dart` | 网址校验 |
| `generatePassword` | `lib/app/util/password_generator.dart` | 随机密码 |
| `formatDateTime` / `formatDate` / `formatRelative` | `lib/app/util/date_format.dart` | 日期格式化 |
| `normalizeIconKey` | `lib/app/icons/aegis_icon_pack.dart` | 图标匹配规范化 |
