# AGENTS.md

- 本项目为 **Flutter + Dart** 的 Android 本地密码管理器 + TOTP 验证器（KeyCase）。Dart 包名 `keycase`，Android applicationId `top.talyra42.keycase`。
- 包管理器：**pub**（`flutter pub get` / `flutter pub add`）；不引入 npm/yarn 等前端工具链。
- 样式方案：Flutter Material 3 + 项目自有设计令牌（`kc*` 颜色、`kcRadius*` 圆角、`KcPage` / `KcCard` / `KcHeader` 页面骨架）；业务代码不硬编码颜色与圆角。
- UI 组件库：Material 3 + `flutter_svg`（品牌图标）+ `anchored_menu`（锚点菜单）+ `mobile_scanner`（扫码）。
- 工具链：Flutter 3.47.2（与 CI 固定版本一致）、Java 17、Android SDK；正式 APK 由 CI 构建。

## 产品原则

- **本地优先、静态加密**：没有账号、没有云同步、没有统计上传。所有条目只存在于本机一个加密容器 `vault.kcv` 里，口令派生用 Argon2id，正文用 AES-256-GCM。
- **明文不落盘**：主密码、vault key、TOTP secret、条目内容不得写入日志、偏好、缓存或临时文件。备份是同一个加密容器的副本，不是明文导出。
- **只做 Android**：`android/` 是唯一交付目标；不维护 Web/桌面预览，不引入仅在其它平台可用的实现。
- **能力必须真实可用**：Keystore 包裹密钥、相机扫码、系统文档选择器、截屏保护都要在真机/模拟器上核对，不能靠 stub 冒充。

## 目录结构

```text
lib/
├── main.dart                  # 入口：初始化 Controller、图标包预热、根路由
├── app/
│   ├── models/                # 领域模型与 JSON 映射（models.dart 是稳定 barrel）
│   ├── vault/                 # 容器编解码、文件仓库、备份、查询与排序
│   ├── crypto/                # Argon2id、AES-GCM、Base32、随机数
│   ├── otp/                   # TOTP/HOTP/Steam 计算与全应用唯一 ticker
│   ├── import/                # otpauth、Aegis、Google 迁移与合并去重
│   ├── icons/                 # Aegis 图标包解析与 SVG 渲染
│   ├── security/              # 弱口令/复用/过期审计
│   ├── platform/              # 原生桥（Keystore、FLAG_SECURE、SAF）与生物识别
│   ├── data/                  # 设备偏好 KV
│   ├── update/                # 手动检查 GitHub Release
│   ├── util/                  # 日期、网址、密码生成等纯函数
│   ├── logging/               # AppLogger
│   ├── keycase_controller*.dart / keycase_scope.dart
│   ├── app_theme.dart         # 设计令牌与 ThemeData
│   ├── feedback.dart          # 轻反馈宿主
│   └── messages.dart          # 错误码/提示码 → 文案
├── pages/                     # 页面；共用弹层入口在 sheets.dart
├── common_widgets.dart        # 通用组件稳定入口，实现按 part 拆分在 app/
└── l10n/                      # 中英文 ARB 与已提交的 gen-l10n 产物

android/                       # 原生桥、Manifest、签名配置
assets/iconpacks/              # Aegis Simple Icons（SVG + pack.json）
test/                          # 单元与 widget 测试
docs/                          # 设计与技术文档
scripts/                       # Dart 任务脚本
tool/                          # 本地基准等非产品入口
```

### 状态与数据流

- 权威状态集中在 `KeyCaseController`（`ChangeNotifier`），经 `KeyCaseScope`（`InheritedNotifier`）注入；不使用 Provider / Riverpod / Bloc。
- `VaultRepository` 独占「解锁会话 + vault key + 写互斥」，Controller 只调它的方法；UI 只调 Controller。
- 条目数据只存在于内存与 `vault.kcv`；设备偏好（主题、语言、自动锁定、显示选项）走 `PreferencesStore`，绝不进容器。
- Argon2id 与容器解密在后台 isolate 里完成；AES 正文加密在主 isolate（几十 KB 级，毫秒完成）。

## 文档地图

判断“当前实现事实”的顺序：源码/测试/工作流 → `AGENTS.md` → `README.md` → `docs/design/` → `docs/dev/`。

- `README.md`：项目门面，技术栈、功能、架构、安全模型、构建与发版。
- `SECURITY.md`：威胁模型、容器密码学与漏洞报告方式。
- `CHANGELOG.md`：用户可见变更；内部重构、测试与文档整理不写入。
- `docs/design/design-system.md`：颜色、排版、表面材质与验收约定。
- `docs/design/components.md`：组件、弹层 helper 与纯函数注册表；写新 Widget 前先查。
- `docs/dev/architecture.md`：源码导航与分层。
- `docs/dev/testing.md`：自动化测试分层、覆盖率口径与模拟器验收清单。
- `docs/dev/tech-decisions.md`：KDF 参数、Keystore 取舍、格式与备份口径。

## 文档同步

文档与注释只描述**当前实现和当前产品状态**。仓库里不得保留：

- 旧版本、旧实现、旧格式的说明，以及“迁移前/迁移后”的叙事；
- 已删除的功能、旧名称、旧路径、旧依赖的残留引用；
- 方案草稿、实施计划、评审记录、被否决的选项、与其它项目的对比；
- “曾经/原来/不再/重写/兼容旧版”这类历史叙述。

本仓库已按此口径完成一次全量整理；后续变更按本节持续同步。

具体规则：

- 行为、容器格式、依赖、目录、构建或发版流程变化时，在**同一个提交**内更新受影响的 `README.md`、`AGENTS.md`、`docs/` 与代码注释。
- 删除功能时，直接从文档、注释和注册表里删掉，不写“已移除/旧版兼容”说明；只有用户可见的功能变化才进 `CHANGELOG.md`。
- 新增或改名可复用组件、纯函数时同步 `docs/design/components.md`；新增用户可见能力时同步 `README.md`。
- 完成前搜索一遍旧名称、旧路径、旧术语，确认仓库里没有残留；这一步属于“完成前检查”的固定项。
- `README.md` 必须保持项目门面标准：徽章、技术栈、功能、架构、安全模型、构建、发版六部分与当前代码一致。

## Coding Style

### Dart 与依赖

- 遵循 `dart format` 与 `analysis_options.yaml` 的 flutter_lints + 正确性规则；两个空格缩进。
- 文件名 `snake_case.dart`，类型 `UpperCamelCase`，成员 `lowerCamelCase`，私有加 `_`。
- 不为简单需求新增依赖；新增前评估 APK 体积、隐私与维护成本。
- 不修改生成文件（`lib/l10n/app_localizations*.dart`、`build/`、`.dart_tool/`）。

### 组件与设计令牌

- 写任何 Widget / 弹层前先查 `docs/design/components.md`，命中就复用或参数化扩展；禁止为同一交互另写一套同构组件。
- 2–8 项静态受控单选（设置、排序、令牌参数等）统一使用 `KcMenuRow<T>` / `AnchoredMenuChoice<T>`；禁止引入分段控件、底部单选列表等第二套单选组件。
- 页面骨架固定 `Scaffold > SafeArea > KcPage`，头部用 `KcHeader` / `KcSubHeader`。
- 颜色只用 `kc*` 令牌与 `Theme.of(context).colorScheme`；语义色经 `kcSemantic(context, kcDanger)` 取用。
- 表面一律不透明实色：禁止背景模糊、渐变、片元滤镜。

### 弹窗与输入

- 页面不得裸写 `showModalBottomSheet`：自定义内容用 `showKcSheet`；确认用 `showKcConfirm`；文本输入用 `showKcTextInput`。
- 单选统一使用锚点菜单：`KcMenuRow<T>`（设置/表单行）或外部库的 `AnchoredMenuChoice<T>` / `AnchoredMenuButton`；禁止重新引入底部单选弹层。
- 图标搜索画廊、取色器这类搜索/调参型面板可以继续用 `showKcSheet`，但它们不是静态单选列表。
- 取消/未选统一返回 `null`。

### 国际化

- 新增用户可见文案必须同时写 `lib/l10n/app_zh.arb`（模板）与 `app_en.arb`，经 `AppLocalizations.of(context)` 使用。
- 不手改生成的 `app_localizations*.dart`。
- `contentDescription` / tooltip 同样需要本地化。

### 异步、错误与日志

- `await` 之后再用 `BuildContext` 必须先判断 `mounted` / `context.mounted`。
- Controller 只暴露 `KeyCaseError` / `KeyCaseNotice` 枚举，文案由 `messages.dart` 翻译；不要把技术异常字符串直接显示给用户。
- 捕获异常后必须 `AppLogger` 记录或明确注释这是可接受降级；禁止空 `catch`。
- 落盘失败必须让用户知道，不能假装成功。

### 数据与备份

- 容器格式变更：提升 `VaultData.currentSchemaVersion`，在 `VaultMigrations` 追加“升到 N+1”的段，永不回改历史段，并补迁移测试。
- 模型字段变更同步 `toJson` / `fromJson` 与往返测试。
- 备份只有一种形态：同一加密容器的副本（`.kcbak`）。自动快照保留最近 10 份，只写用户选定的 SAF 目录。

## Build Commands

```bash
flutter pub get
dart format .
flutter analyze
flutter test
flutter run -d emulator-5554
flutter build apk --debug
flutter build apk --release
```

- 开发验收只在模拟器 `emulator-5554` 上进行；不安装、不测试物理机。
- 演示数据：`--dart-define=SEED_DEMO=true` 会创建示例库并自动解锁，仅用于本地截图与点按验收。

## CI 与发版

- `.github/workflows/ci.yaml`：push 到 `main` 时跑格式检查、analyze、全量测试与 debug APK 编译。
- `.github/workflows/release.yml`：推送 `vX.Y.Z` 标签时用 `signing/` 里的 keystore 构建签名 APK 并发布 GitHub Release（预发布，真机验收后手动提升）。
- 发版必须得到用户明确授权；脚本 `dart run scripts/publish.dart patch|minor|major`。
- 签名材料是已确认的仓库例外，不要替换或额外扩散。

## Never 规则

- Never 把主密码、vault key、TOTP secret 或条目明文写进日志、偏好、文件名或临时文件。
- Never 在渲染路径做文件 IO、Argon2、SVG/图片解码或全量排序；这些放到 isolate / 缓存 / 构建期。
- Never 给令牌行各起一个 Timer；全应用只有一个 `OtpClock`。
- Never 在 Flutter 列表中省略稳定 key。
- Never 让 UI 直接读写文件或 Keystore；只经 Controller 与 Repository。
- Never 修改已发布的迁移段或回改容器格式而不升版本。
- Never 硬编码 `Color(0x...)`、魔法圆角或中文文案到新组件。
- Never 手改 `pubspec.lock`、生成的 l10n 文件或构建产物。
- Never 未经授权 push、打标签或发版；Never 替换签名材料。
- Never 在仓库里写本机绝对路径、用户名、设备序列号或 SDK/JDK 路径（用 `<android-sdk>` 等占位符）。
- Never 在文档或注释里保留旧实现、旧版本、迁移过程或已删除功能的说明。

## Commit 规范

- 格式：`type: summary`，类型 `feat` / `fix` / `docs` / `style` / `refactor` / `perf` / `test` / `chore`。
- 不写 `Generated by` / `Co-authored-by` 等 AI 署名。
- 独立功能完成并通过验证后及时提交，不积压工作区；代码与对应文档、注释放在同一个提交。
- 用户可见的功能与修复写入 `CHANGELOG.md` 顶部 `## [Unreleased]`。

## 完成前检查

- 改动是否严格落在请求范围内，工作树是否干净？
- 新文案是否中英文都进了 ARB？新 UI 是否只用令牌？
- 错误是否有日志与用户反馈？异步后是否检查了 `mounted`？
- 是否跑了 `dart format`、`flutter analyze`、`flutter test`，UI 改动是否在模拟器上看过并留存截图？
- 安全相关改动是否确认了“明文不落盘”？
- 文档与注释是否同步？是否残留旧名称、旧路径、旧实现或旧版本说明？
