# 组件与纯函数注册表

新增 Widget / 弹层 / 纯函数前先查这里；命中就复用或参数化扩展，禁止为同一
交互再写一套同构组件。新增、改名或删除可复用件时同步本文件，并在测试中覆盖
它的关键路径。

## 0. 选择规则

| 需求 | 唯一入口 |
|---|---|---|
| 2–8 项静态受控单选（设置、排序、令牌参数等） | `KcMenuRow<T>`（基于 `anchored_menu`） |
| 页面头部的「更多」动作 | `AnchoredMenuButton` / `AnchoredMenuAnchor` |
| 单行/多行文本输入 | `showKcTextInput` |
| 危险或不可撤销操作确认 | `showKcConfirm` |
| 搜索、网格、滑条等自定义面板 | `showKcSheet` |
| 页面内复杂表单（如修改主密码） | 页面自有 `AlertDialog` 或整页，不套单选弹层 |
| 复制到剪贴板 | `copyToClipboard` |

- **单选没有底部弹层入口**：2–8 项静态选项必须走 `KcMenuRow<T>` /
  `AnchoredMenuChoice<T>`，不要新增第二套单选控件。
- **禁止裸写 `showModalBottomSheet`**：只在 `lib/pages/sheets.dart` 内实现统一
  圆角、拖拽把手、安全区与最大宽度。
- **禁止自造同构组件**：需要变体时先给现有组件加参数；只有交互本质不同才新增，
  并同步本文件与测试。
- **不要用分段控件承载表单单选**：分段控件不属于本项目的组件集。

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
| `KcCodeCapsule` | 验证码胶囊（可隐藏；点击由令牌行决定揭开/复制） |
| `KcCountdownRing` | 倒计时环，最后 5 秒转警示色 |
| `KcDetailRow` | 详情行：标签 + 值 + 复制/尾随操作 |

## 3. 表单与动作（`lib/app/common_widgets_forms.dart`、`common_widgets_navigation.dart`）

| 组件 | 用途 |
|---|---|
| `KcSettingsRow` | 设置行：图标 + 标题/副标题 + 尾随控件或 chevron |
| `KcSwitchRow` | 开关行（整行可点） |
| `KcRowDivider` | 卡片内分隔线（缩进到图标下方） |
| `KcMenuRow<T>` | 静态单选行：设置页样式或 `dense` 紧凑样式，内部统一锚点菜单 |
| `KcLabeledField` | 带外置标签的输入框 |
| `KcPasswordStrengthBar` | 主密码强度条（`lib/app/password_strength.dart`） |
| `KcSpeedDial` / `KcSpeedDialAction` | 主 FAB + 向上展开的动作组；每个动作有独立 heroTag |

`KcMenuRow<T>` 的 `keyPrefix` 用于锚点菜单项的稳定 key，页面传入
`settings_language`、`editor_token_type` 这类前缀；不要在页面里自己拼
`AnchoredMenuItem` 列表。

## 4. 弹层（`lib/pages/sheets.dart`）

| 入口 | 用途 |
|---|---|
| `showKcSheet<T>` | 统一底部弹层（圆角、拖拽把手、安全区、最大宽度） |
| `showKcConfirm` | 二次确认，`destructive: true` 用于危险操作 |
| `showKcTextInput` | 单行/多行文本输入，取消返回 `null` |
| `copyToClipboard` | 复制 + 轻反馈，全应用统一入口 |

排序、设置项、令牌参数等 2–8 项静态单选直接使用 `KcMenuRow<T>`；视觉令牌在
`buildKeyCaseTheme()` 里通过 `AnchoredMenuThemeData` 桥接，页面不覆写颜色与圆角。
`showKcSheet` 只用于自定义内容（图标搜索画廊、取色器、文本输入），不能拿它承载
简单的选项列表。

## 5. 领域组件

| 组件 | 位置 | 用途 |
|---|---|---|
| `KcLoginTile` | `lib/pages/item_tiles.dart` | 登录项行 |
| `KcTokenTile` | `lib/pages/item_tiles.dart` | 令牌行（验证码 + 倒计时；揭开/复制/点外部隐藏） |
| `KcLetterHeader` | `lib/pages/item_tiles.dart` | 字母分组头 |
| `AegisIcon` | `lib/app/icons/aegis_icon.dart` | 品牌 SVG 渲染 |
| `KcFeedbackHost` | `lib/app/feedback.dart` | 根级轻反馈宿主 |

## 6. 纯函数

| 函数 | 位置 | 说明 |
|---|---|---|
| `generateOtpCode` / `otpCounterAt` / `otpSecondsRemaining` / `nextOtpCode` | `lib/app/otp/otp.dart` | RFC 6238 / 4226 / Steam |
| `formatOtpCode` / `hiddenOtpCode` | `lib/app/otp/otp.dart` | 分组与隐藏态排版；隐藏态保留分组空格 |
| `parseOtpauthUri` / `buildOtpauthUri` | `lib/app/import/otpauth_parser.dart` | 链接解析与生成 |
| `parseGoogleMigration` | `lib/app/import/google_migration.dart` | Google Authenticator 迁移链接 |
| `auditVault` / `isWeakPassword` / `masterPasswordScore` | `lib/app/security/security_audit.dart` | 安全中心与主密码强度 |
| `sortItems` / `groupByInitial` / `searchItems` | `lib/app/vault/vault_query.dart` | 列表排序/分组/搜索 |
| `normalizeUrl` / `displayUrl` | `lib/app/util/url_tools.dart` | 网址校验 |
| `generatePassword` | `lib/app/util/password_generator.dart` | 随机密码 |
| `formatDateTime` / `formatDate` / `formatRelative` | `lib/app/util/date_format.dart` | 日期与相对时间格式化，全部走 l10n |
| `normalizeIconKey` | `lib/app/icons/aegis_icon_pack.dart` | 图标匹配规范化 |
| `compareVersions` | `lib/app/update/update_checker.dart` | 语义化版本比较 |
