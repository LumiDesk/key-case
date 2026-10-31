# AGENTS.md

- 本项目为 **Android 原生应用**（Kotlin + Jetpack Compose），不是 Web 前端
- 包管理器：Gradle（Kotlin DSL，version catalog 在 `gradle/libs.versions.toml`）
- UI：Jetpack Compose + Material 3；JSON：kotlinx.serialization；二维码：ZXing Android Embedded
- 最低 SDK：26；目标/编译 SDK：37；JDK：Android Studio 自带 JBR

## 仓库结构

```text
app/                 # Android UI、Activity、Android Keystore、文件/备份
core/                # 纯 JVM：加密容器、TOTP、Aegis/Google 导入
signing/             # 项目所有者要求入库的 release keystore + properties
scripts/             # release.ps1 等发布工具
.github/workflows/   # GitHub Actions：tag -> 签名构建 -> Release
docs/design/         # 设计决策、格式说明、UI 规范
docs/screenshots/    # 验收截图
docs/icon-options/   # 图标方案
gradle/libs.versions.toml
```

app 内主要目录：

```text
app/src/main/java/top/talyra42/keycase/
├── data/            # AndroidVaultStore、BiometricVault、AutoBackup、UpdateChecker
├── ui/              # Compose 页面与通用组件
│   ├── theme/       # 颜色、字体、Theme
│   └── icons/       # Aegis 图标包、图标缓存
└── MainActivity.kt
```

## Coding Style

**Kotlin / Compose**
- 页面使用 `@Composable fun XxxScreen(...)`；通用 UI 放 `ui/Components.kt` 或独立文件
- 状态优先 `rememberSaveable` / `remember`；跨页面状态放 `MainViewModel`
- 列表必须提供稳定 `key`
- 渲染路径中禁止 IO；SVG/图片解码、Argon2、文件读写放 `Dispatchers.IO`
- 不硬编码颜色；使用 `MaterialTheme.colorScheme`
- 文案通过 `LocalizedText.kt` 或 `strings.xml` 支持中英文

**安全**
- 不在日志/UI 中输出主密码、保险库密钥、TOTP secret
- 生物识别密钥必须由 Android Keystore 保护
- 网络仅允许用户主动触发的 GitHub Release 更新检查；不得加入遥测、同步或后台上传
- Release 签名文件按项目所有者要求放在 `signing/` 并入库；这是公开项目的明确取舍，不要把密码/密钥复制到日志或 CI 输出

## Build Commands

```bash
./gradlew :app:assembleDebug          # 开发包
./gradlew :app:assembleRelease        # 签名包（R8 压缩/优化，-dontobfuscate）
./gradlew :core:test :app:testDebugUnitTest
ANDROID_SERIAL=emulator-5554 ./gradlew :app:connectedDebugAndroidTest
```

Windows 使用 `gradlew.bat`，并设置 `JAVA_HOME` 为 Android Studio JBR。

## Testing Environment

- All development verification uses the Android emulator (`emulator-5554`).
- Never install, uninstall, or run instrumentation on the physical phone (`838918a6` / 25102RKBEC).
- The user updates the physical phone manually from GitHub Releases, outside this agent workflow.
- Connected tests must always set `ANDROID_SERIAL=emulator-5554`.

## Release Commands

```powershell
.\scripts\release.ps1 patch   # 0.1.1 -> 0.1.2
.\scripts\release.ps1 minor   # 0.1.x -> 0.2.0
.\scripts\release.ps1 major   # 0.x -> 1.0.0
```

脚本会更新 `app/build.gradle.kts` 的 `versionCode`/`versionName`、提交、打 tag、推送；`.github/workflows/release.yml` 负责签名构建并发布 GitHub Release。Release notes 只写上一 tag 到当前 tag 的 compare 链接。

## Never 规则

- Never 修改 `app/build/`、`core/build/` 等构建产物
- Never 在渲染路径执行 Argon2、文件读写、SVG/Bitmap 解码
- Never 在 Compose 列表省略 key
- Never 把保险库密钥/主密码写进日志或明文件
- Never 给 Token/密码行加每行独立计时器；使用单个 ticker / 顶部进度条
- Never 直接改 core 数据格式而不写迁移/兼容逻辑
- Never 使用 `Set-Content` 等会改变编码的方式修改含中文源码

## Commit 规范

- 格式：`type(scope): description`
- 类型：`feat` / `fix` / `docs` / `style` / `refactor` / `perf` / `test` / `chore`
- UI 改动附模拟器/真机截图到 `docs/screenshots/`（除安全页外）
