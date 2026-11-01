# KeyCase 系统 Code Review 报告

> 日期：2026-10-31  
> 分支：`review/systematic-review`（基于 `main` @ `c1246a7`）  
> 审查对象：`app/` + `core/` + Gradle / CI / 文档  
> 审查方式：全量静态阅读、构建与测试、Android Lint、模拟器功能与视觉抽查  
> 状态：**历史审查报告**。P0/P1 与选定的 P2 已在 v0.1.3 完成，本文保留作为审查记录；修复过程文档不再随仓库维护

---

## 1. 结论摘要

KeyCase 已经是一个功能完整度相当高的本地密码管理器 + TOTP 验证器：核心加密边界清晰，Compose UI 有统一的视觉语言，导入、备份、图标包、搜索、回收站等主流程都能跑通。但当前版本存在 **1 个已复现的致命数据丢失缺陷**，以及若干会直接影响安全承诺、国际化和日常使用的问题。**在修复 P0 之前，不建议发布下一个版本。**

### 最需要先处理的 5 件事

| 优先级 | 问题 | 影响 |
|---|---|---|
| P0 | 修改主密码后，第一次保存会把保险库用全零密钥重新加密 | 保险库永久无法打开，数据丢失 |
| P0 | 主密码、条目密码、TOTP 密钥等敏感值使用 `rememberSaveable` | 敏感值进入 Activity 保存状态，可能被系统持久化 |
| P0 | 图标选择 / 图标包导入绕过“外部 Activity 保持解锁”保护 | 默认自动锁定下，打开系统选择器会直接锁库并丢失编辑内容 |
| P0 | Aegis 导入的 scrypt 参数上限可触发约 4 GiB 内存分配 | 恶意或异常 Aegis 文件可让 App OOM |
| P0 | 生物识别密钥未与 `vaultId` 绑定，导入备份后不清理 | 换库后生物识别持续失败，UI 仍显示已启用 |

### 总体评估

| 维度 | 评价 | 说明 |
|---|---|---|
| 数据完整性 | **高风险** | P0-1 是真实存在的数据丢失路径 |
| 安全 / 隐私 | **中等风险** | 加密设计合理；保存态、导入边界、剪贴板仍有改进空间 |
| 功能正确性 | **中等偏上** | 主流程完整；HOTP/Steam、TOTP 刷新、搜索关闭、URL 输入有明确缺陷 |
| UI / 视觉 | **良好** | 设计语言统一、空状态和列表质感不错；存在文案、对比度和布局细节问题 |
| 国际化 | **弱** | 中英混排，部分页面整页中文；动态字符串和错误消息覆盖不足 |
| 无障碍 | **弱** | 触控目标偏小、大量 `contentDescription` 为中文、A–Z 索引不可被 TalkBack 使用 |
| 架构 / 可维护性 | **中等** | `:core` 边界好；`MainViewModel` 和 UI 文件偏大，本地化字典脆弱 |
| 测试 / CI | **弱** | 无 PR CI、无 Lint 门禁，缺少生命周期 / 迁移 / 导入回归测试 |
| 文档 | **中等** | 设计文档质量高，但截图和部分实现已经脱节 |

---

## 2. 审查范围与验证基线

### 2.1 代码规模

| 范围 | 文件数 | 行数 |
|---|---:|---:|
| `app/src/main` Kotlin | 28 | 8,043 |
| `core/src/main` Kotlin | 6 | 1,263 |
| 单元测试（app + core） | 10 | 531 |
| Android 仪器测试 | 4 | 138 |

### 2.2 已执行的验证

| 验证 | 结果 |
|---|---|
| `:core:test :app:testDebugUnitTest :app:assembleDebug` | **通过**（约 11s） |
| `:app:lintDebug` | **通过**，无 error；有依赖版本、Manifest、资源等 warning |
| 模拟器 `emulator-5554` 手动验收 | 创建/解锁、密码 CRUD、令牌、搜索、设置、删除确认等主流程可跑通 |
| 临时探针测试：改主密码 → 关闭旧会话 → 保存 → 重新打开 | **失败**：`VaultFormatException` / `AEADBadTagException`，证明 P0-1 |
| `:app:connectedDebugAndroidTest` | **通过**（`test-result-exit-code.txt` = 0） |
| `:app:assembleRelease` | **通过**；release APK 约 7.55 MB（R8 压缩 + 签名配置生效） |

> 临时探针测试只用于验证，已删除，不进入提交。

### 2.3 审查限制

- 只在模拟器上验证，未在物理设备上做 OLED / 指纹 / 3-button navigation 的完整回归（符合项目约定）。
- 未做完整的 TalkBack、字体缩放 200%、横屏、平板、RTL 人工回归；相关结论来自代码和默认字号截图。
- 未做 Jacoco 覆盖率统计；测试数量不等同于覆盖率。
- 没有对 release APK 做渗透测试；威胁模型以“本地、无云、Android Keystore”为前提。

### 2.4 按项目既有决策，不视为缺陷

以下事项是项目已经明确的产品取舍，本报告不作为问题提出，也不会建议回退：

- 分组 UI 已移除；旧的 `groupIds` 继续保留以兼容导入/导出，但不再展示编辑。
- 剪贴板 60 秒自动清除已按产品决策移除；本报告只建议“标记敏感剪贴板”，不要求强行恢复自动清除。
- release keystore 入库是项目所有者的明确取舍；本报告只提示这是已知风险，不要求改回。
- 开发验证只用 `emulator-5554`，不碰物理手机。
- 无云同步、无账号、无遥测；网络仅用于用户主动检查更新。
- 不做“默认解锁方式”选择；生物识别与主密码并存即可。
- release 使用 R8 压缩但 `-dontobfuscate`，保留可读类名。

---

## 3. P0：阻断发布的问题

### P0-1 修改主密码后，下一次保存会使保险库永久无法打开

**证据**

- [`VaultContainer.changePasswordSession()`](../../core/src/main/kotlin/top/talyra42/keycase/core/vault/VaultContainer.kt#L274) 返回的新会话复用了旧会话的 `vaultKey` 数组，没有复制：
  ```kotlin
  session = UnlockedVault(header, session.vaultKey, session.data)  // line 306
  ```
- [`UnlockedVault.close()`](../../core/src/main/kotlin/top/talyra42/keycase/core/vault/VaultContainer.kt#L55) 会把该数组清零：
  ```kotlin
  fun close() { vaultKey.fill(0) }
  ```
- [`MainViewModel.changeMasterPassword()`](../../app/src/main/java/top/talyra42/keycase/ui/MainViewModel.kt#L281) 先关闭旧会话，再使用新会话：
  ```kotlin
  val rotated = VaultContainer.changePasswordSession(unlocked, newChars, KdfParams())
  store.write(rotated.bytes)
  session?.close()          // line 304：把共享的 vaultKey 清零
  session = rotated.session  // line 305：新会话的 key 已经是全零
  ```

**已复现**

临时测试“改密码 → close 旧会话 → 用新会话 seal → 用新密码 open”稳定失败：

```text
VaultFormatException: Wrong vault key or corrupted payload
Caused by: javax.crypto.AEADBadTagException
```

**影响**

- 用户改完主密码后，只要再新增/编辑/删除任意条目，磁盘上的 payload 就会用全零密钥加密。
- 文件头的 password slot 仍然包裹真实 vault key，所以下次输入新密码能解开 slot，但 payload 解密失败，保险库无法打开。
- 这是**不可恢复的数据丢失**，也是当前最严重的问题。

**修复建议**

1. 在 `changePasswordSession()` 中让返回值拥有独立的 key：
   ```kotlin
   session = UnlockedVault(header, session.vaultKey.copyOf(), session.data)
   ```
2. 同时明确 `UnlockedVault` 的所有权语义：`withData()` / `changePasswordSession()` 不得让两个可关闭的会话共享同一个 key 数组；或者提供 `transferKey()` 之类显式 API。
3. 在 `MainViewModel` 中增加“先保存、后关闭旧会话”的顺序保护（即使 key 已复制，也建议这样写，避免未来回归）。
4. 增加回归测试：
   - 改密码 → close 旧会话 → seal → 用新密码 open 成功；
   - 改密码 → 保存 → 立即锁定 → 解锁 → 数据完整；
   - 旧密码仍然失败。

**验收**：模拟器上完整走一遍“改主密码 → 编辑条目 → 锁定 → 新密码解锁 → 再编辑 → 再解锁”，数据均不丢失。

---

### P0-2 敏感字段被写入 `rememberSaveable`

**证据**

| 位置 | 敏感内容 |
|---|---|
| [`AuthScreens.kt#L59`](../../app/src/main/java/top/talyra42/keycase/ui/AuthScreens.kt#L59) | 创建保险库的主密码、确认密码 |
| [`AuthScreens.kt#L132`](../../app/src/main/java/top/talyra42/keycase/ui/AuthScreens.kt#L132) | 解锁主密码 |
| [`SettingsDialogs.kt#L56`](../../app/src/main/java/top/talyra42/keycase/ui/SettingsDialogs.kt#L56) | 改密码：当前密码 / 新密码 / 确认密码 |
| [`SettingsDialogs.kt#L127`](../../app/src/main/java/top/talyra42/keycase/ui/SettingsDialogs.kt#L127) | Aegis 备份密码 |
| [`SettingsDialogs.kt#L171`](../../app/src/main/java/top/talyra42/keycase/ui/SettingsDialogs.kt#L171) | Google Authenticator 迁移链接（含 TOTP 密钥） |
| [`SettingsDialogs.kt#L226`](../../app/src/main/java/top/talyra42/keycase/ui/SettingsDialogs.kt#L226) | 备份主密码 |
| [`PasswordScreens.kt#L615`](../../app/src/main/java/top/talyra42/keycase/ui/PasswordScreens.kt#L615) | 条目密码、备注 |
| [`TokenScreens.kt#L397`](../../app/src/main/java/top/talyra42/keycase/ui/TokenScreens.kt#L397) | TOTP secret |
| [`TokenScreens.kt#L642`](../../app/src/main/java/top/talyra42/keycase/ui/TokenScreens.kt#L642) | `otpauth://` 链接（含 secret） |

**影响**

- `rememberSaveable` 会把状态写入 Activity 的 saved state `Bundle`；该状态由系统进程持有，并可能被持久化，不是“只在内存里”。
- 主密码和 TOTP secret 一旦进入 saved state，App 无法保证它们被清零；这和安全页“主密码只用于本机加密、不会上传”的承诺不匹配。
- 即使 `allowBackup=false`，这仍然违反密码管理器的最小暴露原则。

**修复建议**

- 敏感字段统一改为 `remember`，不要使用 `rememberSaveable`。
- 只把非敏感字段（标题、账号、URL、备注的展示状态、排序、Tab、搜索词等）放入 `rememberSaveable`。
- 如果担心旋转丢失输入：对主密码/secret 宁可在旋转后清空并要求重输，也不要持久化。
- 在代码规范/CI 中增加静态检查：禁止对包含 `password`、`secret`、`token`、`link` 的字段使用 `rememberSaveable`，或至少要求 review。
- 注意：即使改为 `remember`，`String` 仍然不可清零；这是 Kotlin/Compose 的固有限制。目标是避免“持久化”，不是保证内存绝对安全。

**验收**：旋转或进程重建后，上述字段为空；`dumpsys` / saved state 中不出现主密码或 secret。

---

### P0-3 图标选择与图标包导入绕过自动锁定保护

**证据**

- 外部 Activity 保护逻辑存在于 [`MainViewModel.prepareExternalActivity()`](../../app/src/main/java/top/talyra42/keycase/ui/MainViewModel.kt#L193) 和 [`MainActivity.onStop()`](../../app/src/main/java/top/talyra42/keycase/MainActivity.kt#L70)。
- 扫描二维码、导出备份、导入备份、Aegis 导入、选择备份目录都调用了 `prepareExternalActivity()`。
- 但以下入口没有调用：
  - [`SettingsScreen.kt#L220`](../../app/src/main/java/top/talyra42/keycase/ui/SettingsScreen.kt#L220)：导入图标包；
  - [`IconPickerDialog.kt#L144`](../../app/src/main/java/top/talyra42/keycase/ui/IconPickerDialog.kt#L144)：从相册选择自定义图标；
  - [`IconPickerDialog.kt#L153`](../../app/src/main/java/top/talyra42/keycase/ui/IconPickerDialog.kt#L153)：在图标选择器里导入图标包。

**影响**

默认 `autoLockSeconds = 0`（退到后台立即锁定）。打开系统文件/图片选择器时：

1. `MainActivity.onStop()` → `shouldKeepUnlockedForExternal()` 返回 false；
2. `viewModel.onHostStopped()` → `lock()`；
3. 用户返回时看到解锁页，编辑器/图标选择器已被销毁；
4. 选中的图标或图标包结果可能仍然写入，但用户上下文丢失。

这是 **100% 可复现的日常路径**，不是边缘场景。

**修复建议**

- 把 `onPrepareExternal` 回调传入 `IconPickerDialog`，在三个 `launch()` 前调用。
- 更好的做法：封装一个 `rememberExternalLauncher` / `ExternalActivityGuard`，所有外部 Activity 启动统一走它，避免以后新增入口再次遗漏。
- 增加 UI 测试或手工验收项：默认自动锁定下，从编辑器打开图片选择器，返回后编辑器仍在。

**验收**：`autoLockSeconds=0` 时，从密码/令牌编辑器打开图片选择器、图标包导入，返回后仍在原编辑器，数据不丢。

---

### P0-4 Aegis 导入的 scrypt 参数可导致约 4 GiB 内存分配

**证据**

- [`AegisImporter.kt#L46`](../../core/src/main/kotlin/top/talyra42/keycase/core/importing/AegisImporter.kt#L46)：
  ```kotlin
  private const val MAX_SCRYPT_N = 1 shl 20   // 1,048,576
  private const val MAX_SCRYPT_R = 32
  private const val MAX_SCRYPT_P = 16
  ```
- [`AegisImporter.kt#L138`](../../core/src/main/kotlin/top/talyra42/keycase/core/importing/AegisImporter.kt#L138) 直接执行 `SCrypt.generate(password, salt, n, r, p, 32)`。
- scrypt 内存约为 `128 × N × r` 字节；`N=2^20, r=32` 时约 **4 GiB**，足以在低内存设备上直接 OOM。
- `AegisImporter.import()` 还会把整个文件一次性读成 `ByteArray` 并转成 `String`；VM 侧通过 `readBytes()` 读取，也没有文件大小上限。

**影响**

- 恶意构造的 Aegis 文件可以让 App 在导入时 OOM 崩溃。
- 即使是合法但参数异常的备份，也会造成长时间卡顿/崩溃。
- 这是“本地文件导入”边界上的拒绝服务问题，不需要网络。

**修复建议**

- 以总内存上限校验，而不是分别限制 N/R：
  ```kotlin
  require(128L * n * r <= 256L * 1024 * 1024)  // 例如 256 MiB
  ```
  并限制 `p` 和 `N*R*P` 的总工作量。
- 在 VM 读取文件前检查大小（例如 64 MiB），Aegis / 备份 / 图标包统一走 `readLimitedBytes()`。
- 对 `SCrypt.generate` 做异常包装，把错误转换成用户可读的“备份参数不支持”，不要直接暴露 OOM。
- 增加 fuzz / 参数边界测试：N=2^20/r=32、超大文件、截断文件。

**验收**：构造 N=2^20/r=32 的 Aegis 文件，App 返回错误而不是 OOM；内存曲线有上限。

---

### P0-5 生物识别密钥未绑定 vaultId，导入备份后不会清理

**证据**

- [`BiometricVault.kt#L25`](../../app/src/main/java/top/talyra42/keycase/data/BiometricVault.kt#L25) 只在 SharedPreferences 中保存 `iv` 和 `wrapped`，没有保存它属于哪个保险库。
- [`BiometricVault.kt#L33`](../../app/src/main/java/top/talyra42/keycase/data/BiometricVault.kt#L33) 的 `isEnrolled()` 只检查 prefs + Keystore alias。
- [`MainViewModel.importBackup()`](../../app/src/main/java/top/talyra42/keycase/ui/MainViewModel.kt#L488) 直接覆盖 `vault.tkv` 并替换 session，没有通知 `BiometricVault.clear()`。
- `KeyCaseApp` 中 `biometricEnrolled` 是 `remember { ... }`（[`KeyCaseApp.kt#L92`](../../app/src/main/java/top/talyra42/keycase/ui/KeyCaseApp.kt#L92)），导入后不会刷新。

**影响**

- 导入另一个保险库后，生物识别仍然用旧 vault key 解密新文件 → `Wrong vault key or corrupted payload`。
- `BiometricVault.clear()` 在解密失败时可能会被调用，但 UI 仍显示“已启用”，用户会反复触发失败。
- 如果用户曾导出/导入自己的备份，vault key 相同则没事；但只要换过库就会遇到。
- 更严重的是：没有 vaultId 绑定，未来若支持多保险库或外部替换文件，错误会更隐蔽。

**修复建议**

- 在启用生物识别时读取当前 `VaultContainer.inspect(bytes).vaultId`，与 wrapped key 一起保存。
- 解锁前先比较存储的 vaultId 与磁盘 header 的 vaultId；不匹配则清除并提示“生物识别已失效，请输入主密码”。
- 在导入备份、创建新库、删除库等会替换 vault 的操作中，显式清理生物识别状态。
- UI 端把 `biometricEnrolled` 改成可观察状态（例如 `StateFlow` 或回调），不要让它在 `remember` 中一直为 true。
- 可考虑把 vaultId 作为 AES-GCM 的 AAD 之一；或至少在 prefs 中做绑定校验。

**验收**：导入一个不同 vaultId 的备份后，生物识别行变为“未启用”或提示重新启用；不会再次用旧 key 尝试。

---

## 4. P1：本周期建议修复

### P1-1 TOTP 列表可能显示过期验证码，且全局进度条只取第一条的 period

**证据**

- [`TokenScreens.kt#L155`](../../app/src/main/java/top/talyra42/keycase/ui/TokenScreens.kt#L155) 的 ticker 每秒更新 `barNow`，但只有当 `(barNow / 1000) % 30 == 0` 时才更新 `codeNow`（[#L160](../../app/src/main/java/top/talyra42/keycase/ui/TokenScreens.kt#L160)）。
- 如果循环因主线程忙、协程调度延迟、页面恢复等原因错过“整 30 秒”的那一次采样，`codeNow` 会继续停留在旧值，直到下一个 30 秒边界；最坏可显示过期码近 30 秒。
- 从令牌 Tab 切走再切回时，`LaunchedEffect(active)` 重启，但 `codeNow` 可能仍是离开时的值，返回瞬间会显示旧码。
- [`TokenScreens.kt#L207`](../../app/src/main/java/top/talyra42/keycase/ui/TokenScreens.kt#L207) 的顶部进度条使用 `items.first().totp?.period`；如果列表里混有 30s/60s 令牌，进度条对后面的条目没有意义。

**建议**

- 每秒都更新同一个时钟，例如 `now = System.currentTimeMillis()`；验证码和进度条都从这个时钟派生，不再维护两个时间源。
- 进度条按“当前可见条目的 period”或“最小 period”计算；如果保留单条全局进度条，需在 UI 上说明它代表什么。
- 加可注入 clock 的单元测试，覆盖 29.9s / 30.1s / 页面恢复。

### P1-2 HOTP / Steam 处于“半支持”状态，编辑会破坏类型

**证据**

- 扫描结果只在 TOTP 时进入编辑器：[`TokenScreens.kt#L389`](../../app/src/main/java/top/talyra42/keycase/ui/TokenScreens.kt#L389)；非 TOTP 会显示“二维码不是有效的 otpauth 链接”，即使 `OtpauthParser` 支持 HOTP/Steam。
- 手动粘贴导入只允许 TOTP：[`TokenScreens.kt#L676`](../../app/src/main/java/top/talyra42/keycase/ui/TokenScreens.kt#L676)。
- 但 `AegisImporter` / `GoogleMigrationParser` 可以导入 HOTP/Steam。
- 编辑任意已有令牌时，保存逻辑强制：
  ```kotlin
  type = OtpType.TOTP  // TokenScreens.kt:442
  ```
  HOTP 条目被编辑一次就会变成 TOTP，计数器丢失。
- HOTP 在列表/详情中仍显示倒计时环，但没有“生成下一个码”的入口，计数器不会前进。

**建议（需要产品决策）**

- 方案 A：完整支持 HOTP/Steam：保留类型、HOTP 提供“生成下一个码”、Steam 使用 5 位字母表且不显示倒计时；扫描/粘贴都放开。
- 方案 B：明确 TOTP-only：导入时拒绝 HOTP/Steam，或在导入结果里标记“不支持，已跳过”，编辑时保留原类型并只读展示，绝不静默改写。
- 不建议继续维持“内部支持、UI 只支持 TOTP、编辑时强制转换”的现状。

### P1-3 OTP 解析器不校验 digits / period，可能保存永远显示 `—` 的令牌

**证据**

- [`Otp.kt#L196`](../../core/src/main/kotlin/top/talyra42/keycase/core/otp/Otp.kt#L196) 直接接受任意 `digits` / `period`，没有范围校验。
- [`AegisImporter.kt#L195`](../../core/src/main/kotlin/top/talyra42/keycase/core/importing/AegisImporter.kt#L195) 允许 `digits` 到 10。
- `Otp.hotp()` 要求 digits 1..8；超出后 UI 用 `runCatching` 显示 `—`，所以不会崩溃，但用户得到一个永远无码的条目。

**建议**

- 解析阶段校验 `digits in 1..8`、`period in 1..300`（或产品支持集合），非法值直接报错。
- Aegis 导入同样收窄并报告 skipped。
- 对已有的坏数据提供显示提示/修复入口，而不是静默 `—`。

### P1-4 列表搜索关闭后查询仍然生效（已复现）

**证据**

- [`PasswordScreens.kt#L116`](../../app/src/main/java/top/talyra42/keycase/ui/PasswordScreens.kt#L116) 的 `query` 独立于 `searchOpen`。
- [`PasswordScreens.kt#L156`](../../app/src/main/java/top/talyra42/keycase/ui/PasswordScreens.kt#L156) 只切换 `searchOpen`，不清空 `query`。
- 实测：输入 `zz` → 关闭搜索框 → 列表仍显示“No matching entries”，且界面上看不到搜索框或查询词。

**影响**：用户会以为条目丢失，且无法在不重新打开搜索的情况下清除过滤条件。

**建议**

- 关闭搜索时清空 `query`（并让列表恢复），或保留搜索框可见但折叠状态；至少要在标题旁显示一个“筛选中”标识和清除按钮。
- 同样的逻辑检查 TokenListScreen。

### P1-5 网址输入被键盘自动首字母大写（已复现）

**证据**

- [`PasswordScreens.kt#L738`](../../app/src/main/java/top/talyra42/keycase/ui/PasswordScreens.kt#L738) 只设置了 `KeyboardType.Uri`，没有关闭自动大写/自动纠正。
- 实测输入 `https://github.com`，保存后详情显示 `https://GitHub.com`。

**建议**

- URL 字段增加 `KeyboardCapitalization.None`、`autoCorrectEnabled = false`；账号/密钥字段同样关闭自动纠正。
- 保存时对 URL 做 trim / 规范化，但不要擅自改变路径大小写。
- 加一个纯函数测试：输入大写 host 时保持用户输入，或只对 scheme/host 规范化。

### P1-6 删除语义错误：提示“无法恢复”，实际进回收站；永久删除又没有确认

**证据**

- [`PasswordScreens.kt#L394`](../../app/src/main/java/top/talyra42/keycase/ui/PasswordScreens.kt#L394) 的确认框文案是“删除后无法恢复”，而 `onDelete` 调用的是 `deleteItem()`，只设置 `deletedAt`，进入回收站。
- [`TrashScreen.kt#L250`](../../app/src/main/java/top/talyra42/keycase/ui/TrashScreen.kt#L250) 的永久删除按钮直接调用 `onPurge`，没有二次确认。

**建议**

- 普通删除文案改为“移到回收站？可在回收站恢复。”
- 单个永久删除加确认框（或长按菜单 + 确认）；清空回收站已经有确认，保持。
- 删除后显示 Snackbar，带“撤销/去回收站”。

### P1-7 详情/回收站时间显示的是 UTC 原始字符串，不是本地时间

**证据**

- [`PasswordScreens.kt#L366`](../../app/src/main/java/top/talyra42/keycase/ui/PasswordScreens.kt#L366)：`item.updatedAt.take(16).replace('T', ' ')`。
- [`TrashScreen.kt#L238`](../../app/src/main/java/top/talyra42/keycase/ui/TrashScreen.kt#L238)：`item.deletedAt.orEmpty().take(10)`。
- 存储值是 `Instant.now().toString()`，即 UTC ISO-8601；在 UTC+8 等时区会显示错误的时间/日期。

**建议**

- 用 `DateTimeFormatter.ofPattern(...).withZone(ZoneId.systemDefault())` 或 `Instant.parse(...).atZone(...)` 格式化。
- 文案跟随语言（中文“更新于/删除于”，英文“Updated/Deleted”）。
- 为 +08、UTC、跨日边界加单元测试。

### P1-8 旋转/进程重建会丢失当前页面和编辑器状态；关闭编辑器没有未保存提示

**证据**

- [`KeyCaseApp.kt#L156`](../../app/src/main/java/top/talyra42/keycase/ui/KeyCaseApp.kt#L156) 起，`route`、`detailReturn`、`passwordEditor`、`tokenEditor` 都使用 `remember`，不是 `rememberSaveable`。
- 只有 `tab` 是 `rememberSaveable`。
- 编辑器关闭按钮直接 `onBack()`，没有 dirty 检查；ModalBottomSheet 的关闭/返回也会丢弃输入。

**影响**

- 旋转屏幕、系统回收 Activity、切到后台后返回时，用户可能从详情页回到主页，或正在编辑的密码消失。
- 误触返回/关闭会无提示丢失输入。

**建议**

- 至少把 route / editor target 做成 `rememberSaveable` 可保存对象（`Saver` 或 `Parcelable`），或引入 Navigation Compose 的 `SavedStateHandle`。
- 编辑器维护 `dirty` 状态，关闭时弹“放弃修改？”。
- 将编辑目标改成 `itemId` 等轻量标识，避免把敏感内容放进 route。

### P1-9 国际化不完整：部分页面绕过本地化、内容描述全中文、错误消息中英混杂

**已复现**

- [`SearchScreen.kt#L24`](../../app/src/main/java/top/talyra42/keycase/ui/SearchScreen.kt#L24) 直接 import `androidx.compose.material3.Text`，导致整页标题、占位符、分组标题不翻译；但 EmptyState 使用了本地化 Text，出现同一页面“搜索 / Search the vault / 密码 · 1”的混排。
  见 [`evidence/search-mixed-language.png`](evidence/search-mixed-language.png)。
- [`EditorIconRow.kt#L15`](../../app/src/main/java/top/talyra42/keycase/ui/EditorIconRow.kt#L15) 同样绕过了本地化，英文界面里的“图标 / 点击更换图标”仍为中文。
  见 [`evidence/editor-icon-row-untranslated.png`](evidence/editor-icon-row-untranslated.png)。

**代码层面确认**

- 17 处 `contentDescription = "中文"` 直接写死（返回、编辑、删除、复制、关闭、收藏、恢复、永久删除、显示/隐藏密码等）；TalkBack 在英文设备上会读中文。
- 动态字符串未覆盖：`密钥`、`"$digits 位"`、`"$period 秒"`、`otpauth-migration:// 链接` 等。
- 错误消息来自 core/VM 的英文异常（`Vault is locked`、`GitHub returned 404`）或中文异常（`备份目录不可用`），直接通过 `localized(error)`/Toast 展示，词典无法完整翻译。
- 词典里还有重复键、过期条目（例如“版本 0.1.0”）和单复数问题（“1 items”）；同一个中文词无法按语境翻译，例如“更新”作为详情行应译为 “Updated”，作为按钮应译为 “Update”，当前统一成了 “Updated”（[`SettingsDialogs.kt#L97`](../../app/src/main/java/top/talyra42/keycase/ui/SettingsDialogs.kt#L97)）。

**建议**

- 首选：迁移到 Android 资源（`values/strings.xml` + `values-zh/strings.xml`），用 `stringResource()`；一次性解决复数、上下文和翻译缺失。
- 如果暂时不迁移：至少
  - 禁止在 `ui/` 下直接 import `material3.Text`（可以用 lint/detekt 规则或 code review）；
  - 所有 `contentDescription` 走同一个本地化函数；
  - 错误改成错误码，由 UI 层映射为文案；
  - 移除重复/过期词典条目，补复数逻辑。
- 补一个静态检查或测试，扫描未本地化的中文字面量。

### P1-10 强调色对比度不足，琥珀/绿色白字不达标，自定义浅色可能不可读

**证据**

- [`Theme.kt#L23`](../../app/src/main/java/top/talyra42/keycase/ui/theme/Theme.kt#L23) 的 `onAccent` 使用 `luminance() > 0.30f` 决定深/浅文字。
- 计算对比度：绿色 `#059669` 对白色约 **3.77:1**，琥珀 `#D97706` 对白色约 **3.19:1**，都低于普通文本 4.5:1；而这两种颜色本应使用深色文字（对黑色 5.57 / 6.59）。
- [`Theme.kt#L48`](../../app/src/main/java/top/talyra42/keycase/ui/theme/Theme.kt#L48) 在浅色主题把 `onPrimaryContainer` 设为强调色本身；用户选很浅的自定义颜色时，强调色文字落在接近白色的容器上，可能几乎不可见。
- 自定义取色器没有亮度/对比度约束，也没有“恢复默认预设”的直接入口。

**建议**

- 用对比度计算选择 ink：分别计算黑/白对比度，取更优；而不是固定阈值。
- 对 `primaryContainer` 的 `onPrimaryContainer` 做派生，不要直接使用原 accent。
- 在取色器预览中显示对比度提示，或限制过亮/过暗颜色。
- 增加一组颜色单测：5 个预设 + 纯白/纯黄/纯黑自定义色。

### P1-11 无障碍支持不足

**证据**

- 强调色色板 28dp、自定义取色按钮 32dp，低于 48dp 触控目标；色块没有语义标签（只有选中勾有描述）。
- [`AlphabetIndex.kt#L98`](../../app/src/main/java/top/talyra42/keycase/ui/AlphabetIndex.kt#L98) 的 A–Z 索引完全依赖 `pointerInput`，TalkBack 无法使用，也没有 `semantics` 操作。
- TOTP 验证码胶囊只显示文本，没有“当前验证码/复制”的语义和状态描述。
- `SwitchRow` 用 `Row.clickable` + 内部 `Switch`，没有 `toggleable` role，TalkBack 可能重复播报或缺少开关状态。
- 固定 72dp StatCard、56dp InfoRow 标签、64dp 安全原因宽度，在英文或大字号下容易截断。

**建议**

- 触控目标至少 48dp；色块加 `contentDescription` 和 `Role.RadioButton` / `selectable`。
- 为 A–Z 索引提供可聚焦的 `semantics` 动作（或至少提供列表快速跳转的替代入口）。
- TOTP 胶囊加 `contentDescription`（隐藏时不要读出真实码）、复制动作和状态。
- 用 `toggleable` 改造 SwitchRow；补 TalkBack 验收清单。
- 做一次 fontScale 1.3 / 2.0 截图回归；把固定高度改为 `heightIn(min = ...)`。

### P1-12 图片解码可能 OOM，详情页图标分辨率不足

**证据**

- [`IconPickerDialog.kt#L380`](../../app/src/main/java/top/talyra42/keycase/ui/IconPickerDialog.kt#L380) 用 `BitmapFactory.decodeStream` 全尺寸解码相册图片，之后才缩放。
- [`ImportedIconPack.kt#L105`](../../app/src/main/java/top/talyra42/keycase/ui/icons/ImportedIconPack.kt#L105) 全尺寸 `decodeFile` 后再缩放。
- [`ImportedIconPack.kt#L89`](../../app/src/main/java/top/talyra42/keycase/ui/icons/ImportedIconPack.kt#L89) 对每个图标做完整 decode 来验证。
- [`AegisIconPack.kt#L333`](../../app/src/main/java/top/talyra42/keycase/ui/icons/AegisIconPack.kt#L333) 固定用 112px 位图；详情页图标是 82dp，在高密度屏上约 215–246px，会放大发虚。自定义图标解码也默认 96px。

**建议**

- 用 bounds + `inSampleSize` / `ImageDecoder` 解码到目标像素尺寸，绝不先全尺寸 decode。
- 按 `size` 和 `LocalDensity` 计算像素桶（如 48/96/192/256），缓存键包含尺寸。
- 限制输入图片的像素/字节数，超过则拒绝并提示。
- 详情页头像至少 256px 桶。

### P1-13 主线程 ZIP 读取与解锁阻塞

**证据**

- [`AegisIconPack.kt#L315`](../../app/src/main/java/top/talyra42/keycase/ui/icons/AegisIconPack.kt#L315) 在 `remember` 中同步调用 `AegisIconPack.findFilename()`；首次调用会加载并解析内置 ZIP/manifest，属于渲染路径 IO。
- `prefetch()` 在线程池中执行，通常能提前预热；但代码路径仍然允许在主线程做 ZIP 读取，违反 AGENTS 的“渲染路径禁止 IO”。
- [`MainViewModel.kt#L124`](../../app/src/main/java/top/talyra42/keycase/ui/MainViewModel.kt#L124) / [`#L168`](../../app/src/main/java/top/talyra42/keycase/ui/MainViewModel.kt#L168) 在更新 `_state` 前同步执行 16 个图标的 `prefetch`，会延长解锁转圈时间。

**建议**

- 启动时在 IO 线程预热索引（不渲染位图），渲染只读内存映射；`BrandAvatar` 不在 `remember` 中做任何 IO。
- 解锁流程先 `_state.update` 显示主界面，再异步 `prefetch`；或把 prefetch 放到 `lifecycleScope`/后台。
- 对内置 ZIP 建 offset 索引，避免每个图标都从头扫描 ZIP。

### P1-14 不可信输入缺少统一大小上限（备份 / 图标包 / gzip）

**证据**

- `MainViewModel.importBackup()` 使用 `readBytes()`（[#L498](../../app/src/main/java/top/talyra42/keycase/ui/MainViewModel.kt#L498)）；`importAegis()` 同样（[#L529](../../app/src/main/java/top/talyra42/keycase/ui/MainViewModel.kt#L529)）。
- [`VaultContainer.gunzip()`](../../core/src/main/kotlin/top/talyra42/keycase/core/vault/VaultContainer.kt#L399) 对解压后的字节数没有上限；64 MiB 密文可以解压成远超内存的数据。
- 图标包有 30 MiB 解压总量限制，但单张图片仍可能全尺寸 decode（见 P1-12）。

**建议**

- 统一 `readLimitedBytes(uri, maxBytes = 64 MiB)`，超过直接报错。
- 解压时用有上限的流式 copy，超过 64 MiB 停止并抛出格式异常。
- 图标包限制单文件字节/像素、总解压大小和图片数量。

### P1-15 导入备份会直接替换当前保险库，没有安全副本

**证据**

- [`MainViewModel.importBackup()`](../../app/src/main/java/top/talyra42/keycase/ui/MainViewModel.kt#L488) 成功解锁后直接 `store.write(bytes)`，当前 `vault.tkv` 被覆盖。
- 对话框只有“导入并替换”的文案（[`SettingsDialogs.kt#L237`](../../app/src/main/java/top/talyra42/keycase/ui/SettingsDialogs.kt#L237)），没有自动备份/导出当前库的步骤。

**建议**

- 覆盖前把当前文件复制到 `vault.tkv.pre-import-<timestamp>`（加密原样），或在 app-private 下保留一份 rolling 安全副本。
- 导入失败时不要写入；当前实现是解锁成功后才写，基本正确；但写入过程中断的风险仍应由临时文件 + rename 处理。
- UI 明确显示“当前库已保留为安全副本”。

### P1-16 测试与 CI 没有覆盖生命周期/导入/加密回归

**证据**

- 42 个 `@Test`，但没有针对 `MainViewModel`、`BiometricVault`、`AutoBackupManager`、`TokenListScreen` ticker、导入边界、改密码后保存的测试。
- `release.yml` 只在 tag 推送时运行单元测试 + assembleRelease；没有 PR 工作流，没有 lint 门禁，没有 connected test。
- P0-1 这种一个方法就能覆盖的致命 bug，现有测试完全没有发现。

**建议**

- 先加回归测试（P0-1、P0-2 静态检查、P1-1、P1-3、P1-7）。
- 加 `.github/workflows/ci.yml`：`assembleDebug`、`:core:test`、`:app:testDebugUnitTest`、`:app:lintDebug`。
- 可选：nightly emulator connected tests；至少把 AGENTS 里的 `ANDROID_SERIAL=emulator-5554` 流程固化。
- 不追求覆盖率数字，优先覆盖安全边界和状态迁移。

---

## 5. P2 / P3：体验、架构与技术债

### P2（体验/质量，建议排入 v0.2.0）

| ID | 问题 | 建议 |
|---|---|---|
| P2-1 | 设置里“上次备份”行有 chevron 但 `onClick = {}`（[SettingsScreen.kt#L314](../../app/src/main/java/top/talyra42/keycase/ui/SettingsScreen.kt#L314)） | 去掉 chevron，或打开备份详情/历史 |
| P2-2 | 设置条目数包含回收站条目（[SettingsScreen.kt#L193](../../app/src/main/java/top/talyra42/keycase/ui/SettingsScreen.kt#L193)） | 用 active items 计数，或明确写“含回收站” |
| P2-3 | “从 Aegis 导入”副标题仍写“合并 TOTP 条目与分组”，但分组 UI 已移除 | 更新文案；决定 Aegis groups 是否继续导入 |
| P2-4 | 收藏星只能显示，无法在详情页切换 | 加收藏按钮，或移除星标避免“假功能” |
| P2-5 | 首页“最近使用”实际按 `updatedAt` 排序、最多 6 条（DESIGN 写 5）；密码和令牌同名时视觉无法区分 | 明确叫“最近更新”或增加 `lastUsedAt`；加类型徽标；统一 5/6 |
| P2-6 | 详情页没有“打开网址”动作，只支持复制 | 对合法 URL 提供“打开”按钮，复制保留 |
| P2-7 | 隐藏验证码没有 10 秒自动恢复；详情页 reveal 后永不自动隐藏；最后 5 秒每秒触发一次 haptic（DESIGN 写“一次”） | 按 DESIGN 做 10s 定时/一次触感；或更新 DESIGN 说明 |
| P2-8 | 全局搜索页背景是纯白（[SearchScreen.kt#L72](../../app/src/main/java/top/talyra42/keycase/ui/SearchScreen.kt#L72)），与其他页面 `background` 不一致 | 改用 `background`；统一搜索页的顶部/输入框样式 |
| P2-9 | 列表内搜索不自动聚焦；全局搜索自动聚焦；关闭搜索后查询残留（P1-4） | 统一交互：打开即聚焦，关闭即清空，或保留可见输入框 |
| P2-10 | 编辑器缺少未保存提示、密码强度、生成器长度/字符集选项；生成密码会直接覆盖旧值 | 加 dirty 检查、强度提示、可选长度；覆盖前确认或提供撤销 |
| P2-11 | 设置中生物识别“不支持”行仍可点击；导入备份后状态不刷新（P0-5） | 禁用行并置灰；状态用 Flow 驱动 |
| P2-12 | 图标选择器最多显示 160 个匹配项，且只按名称搜索；导入图标包错误信息可能为英文 | 支持 issuer 搜索/分页；错误本地化 |
| P2-13 | 备份文件名只到秒，同一秒可能冲突；prune 按 `lastModified` 排序；失败时可能留下半文件 | 文件名加毫秒/序号；按文件名排序；临时文件 + rename/失败清理 |
| P2-14 | Aegis/Google 导入没有去重；`skipped` 数量没有展示 | 按 secret+issuer 去重或提示重复；显示“导入 N，跳过 M” |
| P2-15 | 没有“删除保险库/重置 App”入口，用户只能卸载 | 增加危险操作区 + 二次确认 + 先导出备份 |
| P2-16 | 强制深色时 `enableEdgeToEdge()` 没有显式同步系统栏图标明暗（[MainActivity.kt#L23](../../app/src/main/java/top/talyra42/keycase/MainActivity.kt#L23)），存在浅色系统栏 + 深色 App 的风险，需在系统浅色/App 深色组合下验证 | 按解析后的主题设置 `SystemBarStyle`；加入视觉验收 |
| P2-17 | 文档截图明显过时（home-dark/settings-dark 仍显示分组/旧首页），DESIGN 的“一次触感/10 秒隐藏”与实现不一致 | 修复后重拍 `docs/screenshots`；同步 DESIGN/README |
| P2-18 | 缺少 `SECURITY.md` / 威胁模型 / 漏洞报告方式 | 增加安全策略：威胁模型、支持的版本、报告渠道 |
| P2-19 | `MainViewModel` 675 行，设置、会话、导入、备份、文件操作混在一起；`PasswordScreens`/`SettingsScreen`/`TokenScreens` 均 600–870 行 | 按 feature 拆分 VM/Repository；UI 拆文件；先做低风险移动，不改行为 |
| P2-20 | 安全中心存在两份弱密码逻辑（Home `passwordIssueCount` 与 `securityIssues`） | 抽到 `:core` 或单一纯函数，避免规则漂移 |
| P2-21 | 改主密码后不会自动生成新备份；旧备份仍只能用旧密码打开。改密/导入后也没有自动备份 | 改密成功后提示“旧备份需旧密码”，可立即备份；导入/导入 Aegis 后按设置触发备份 |
| P2-22 | `importAegis()` / `importGoogleMigration()` 直接 `store.write()`，没有走 `saveMutex`；与普通保存并发时可能丢失更新 | 所有写入统一经过一个 `VaultRepository.save()`，内部串行化 |

### P3（清理/工程化）

- `AegisIconPack.vectorFor()` / `find()` / `parseSimpleIcon()` 约 200 行没有调用方，已被 AndroidSVG 路径取代；`parseAccentHex`、`SettingsScreen.InfoLine` 也是死代码。
- `ExampleUnitTest` / `ExampleInstrumentedTest` 是模板残留，建议删除或替换为真实测试。
- `colors.xml` 中 purple/teal 等资源未使用；`android:label` 在 Activity 上重复。
- `android:screenOrientation="portrait"` 在 Android 16+ 会被忽略，Lint 已提示；评估是否移除。
- 没有 `dataExtractionRules`（`allowBackup=false` 已提供主要保护，但 target 37 建议补齐）。
- 依赖版本明显落后：`core-ktx 1.10.1`、`lifecycle 2.6.1`、`activity-compose 1.8.0`、`fragment 1.8.5`；Lint 建议的版本见附录。
- `android.enableR8.fullMode=false` 已弃用；`-keep class kotlin.collections.** { *; }` 是宽泛 workaround，升级 AGP/Kotlin 后应尝试移除。
- 没有 ktlint/detekt；部分文件存在 `fun ... {        val` 这类格式化残留。
- 没有 dependency verification / lockfile；公开项目可接受，但供应链风险可记录。
- `strings.xml` 只有 biometric 文案；如果继续用 `LocalizedText.kt`，至少把它当作正式资源维护，而不是“补丁词典”。

---

## 6. UI / 视觉抽查记录

### 做得好的部分

- 创建/解锁/首页/列表/详情/设置的视觉语言统一：中性底色 + 单一强调色、圆角 14–24dp、卡片描边、空状态双层圆形图标。
- 底部四 Tab + Pager 的手感、FAB 展开、ModalBottomSheet 表单、令牌详情磁贴都符合设计文档。
- 密码/令牌列表的 A–Z 分组、字母索引、右对齐验证码胶囊在默认字号下清晰。
- 空状态、安全中心、回收站的文案层级基本一致。
- 深色配色（`#0B111B` / `#121B29`）整体协调；默认字号下可读性良好。

### 需要修的视觉/交互问题

1. **中英混排**：搜索页、编辑器图标行（见 P1-9 截图）；英文界面出现中文是最明显的观感问题。
2. **删除文案与行为矛盾**：删除提示“无法恢复”，实际可恢复（P1-6，见 [`evidence/delete-copy.png`](evidence/delete-copy.png)）。
3. **搜索关闭后空白列表**：看不到查询条件（P1-4，见 [`evidence/search-close-hidden-filter.png`](evidence/search-close-hidden-filter.png)）。
4. **搜索页纯白背景**，与首页/列表的 `#F5F7FA` 不一致，显得像另一个 App（P2-8）。
5. **首页“最近使用”两行完全一样**：同名密码和令牌没有类型区分，用户无法判断点进去是密码还是验证码（P2-5）。
6. **固定高度/宽度**：StatCard 72dp、InfoRow 标签 56dp、安全中心原因 64dp，大字号/英文长词容易截断（P1-11）。
7. **A–Z 索引字号 9sp、宽 18dp**，视觉上偏小，触控目标不足（P1-11）。
8. **令牌进度条 track 对比度很低**，在浅色背景上像一条断掉的蓝线；只显示到 50% 时容易被误解为加载条（P1-1/P2）。
9. **图标包预览一次性铺 3467 个图标**，快速滚动会频繁触发 SVG 解码；视觉没有分页/加载骨架（P1-12/P1-13）。
10. **详情页大图标**（82dp）使用 96/112px 位图，在高密度屏上偏软（P1-12）。

### 截图证据

| 截图 | 说明 |
|---|---|
| [`evidence/home-empty.png`](evidence/home-empty.png) | 当前 v0.1.2 首页空状态，基线视觉 |
| [`evidence/search-mixed-language.png`](evidence/search-mixed-language.png) | 搜索页中英混排 |
| [`evidence/editor-icon-row-untranslated.png`](evidence/editor-icon-row-untranslated.png) | 英文编辑器中的中文图标行 |
| [`evidence/search-close-hidden-filter.png`](evidence/search-close-hidden-filter.png) | 关闭搜索后仍被过滤的列表 |
| [`evidence/delete-copy.png`](evidence/delete-copy.png) | “无法恢复”与实际进回收站矛盾 |

---

## 7. 架构、性能与测试评估

### 架构

- **优点**：`:core` 是纯 JVM，安全关键逻辑可单测；容器格式、KDF、AES-GCM、OTP、导入都有清晰边界；`MainViewModel` 的 UI 状态集中，Compose 页面相对独立。
- **问题**：
  - `MainViewModel` 承担了存储、会话、设置、导入、备份、更新检查等过多职责，且直接依赖 Android `Context`/`Uri`，难以纯 JVM 测试。
  - 本地化通过“同名 `Text` 包装器 + 字典”实现，隐蔽且脆弱；一个 import 就能绕过（SearchScreen 已发生）。
  - 路由/编辑器状态是手写的 `Route` + `remember`，没有 SavedState 支持；复杂度和状态丢失风险都在上升。
  - 图标加载、ZIP 索引、位图缓存分散在 `AegisIconPack`/`IconBitmapCache`/`BrandAvatar`，缺少统一资源层。

### 性能

- 收益最大的优化：
  1. 解锁时先显示 UI，再异步预热图标（P1-13）；
  2. 图片按目标像素解码（P1-12）；
  3. 列表 `sectionsOf`/过滤用 `remember`/`derivedStateOf`，避免每次重组重新分组排序；
  4. 内置图标 ZIP 建 offset 索引，避免逐图标扫描；
  5. 验证码 ticker 合并为一个时钟，减少每行状态依赖。
- 不建议现在做微优化（如每行独立计时器），会违反 DESIGN 的“单 ticker”约束。

### 测试

- 现有测试覆盖了加密容器 round-trip、错误密码、篡改、OTP RFC 向量、Aegis 明文/加密导入、Google 迁移、格式/分组等纯函数。
- 缺口集中在：
  - 会话生命周期（P0-1）；
  - 敏感状态持久化（P0-2）；
  - 外部 Activity 与自动锁定；
  - 导入参数边界 / 资源上限；
  - 时区/本地化；
  - Compose 状态恢复（旋转、进程死亡）。

### CI

- 当前只有 release tag 工作流；PR 没有构建/测试/Lint 门禁。
- 建议先加最小 CI：`assembleDebug + unit tests + lintDebug`，再考虑 connected tests。Release 工作流保留签名/发布逻辑，不在此次 review 中改动密钥策略。

---

## 8. 建议的修复方案

> 原则：先修数据安全和“会丢用户数据”的问题，再做功能正确性，最后做国际化/无障碍/架构。每个阶段独立可验收、可回滚。

### 阶段 A：安全与数据完整性（P0，必须最先做）

**范围**

- P0-1 改密码后的密钥所有权 + 回归测试；
- P0-2 移除敏感字段的 `rememberSaveable`；
- P0-3 所有外部 Activity 启动统一走 `prepareExternalActivity`；
- P0-4 Aegis scrypt 内存上限 + 文件大小上限；
- P0-5 生物识别绑定 vaultId、导入后清理、状态刷新；
- P1-14 / P1-15 中与导入安全直接相关的部分（备份/图标包/解压上限、导入前安全副本）。

**交付**

- 修复 + 针对每项的回归测试；
- 手工验收：改密码→保存→锁定→新密码解锁；导入备份→生物识别状态；默认自动锁定下选图标；
- 模拟器截图（安全页除外，按 AGENTS）。

**建议版本**：v0.1.3（如果只做 A，可直接 patch 发布）。

### 阶段 B：功能正确性与关键 UX

**范围**

- P1-1 TOTP 时钟/进度条；
- P1-2 HOTP/Steam 产品决策后的实现；
- P1-3 OTP 参数校验；
- P1-4 搜索关闭清理；
- P1-5 URL 键盘配置；
- P1-6 删除/回收站文案与永久删除确认；
- P1-7 本地时间格式化；
- P1-8 路由/编辑器 SavedState + 未保存提示；
- P1-13 解锁预取异步化。

**交付**

- 每个 bug 对应截图/测试；
- 更新 `docs/screenshots` 中受影响的页面；
- 增加 `docs/design` 中与行为变化相关的说明（如 HOTP/Steam 决策）。

**建议版本**：v0.1.3 或 v0.2.0，取决于阶段 A 是否单独发布。

### 阶段 C：国际化、无障碍与视觉一致性

**范围**

- P1-9 本地化迁移/兜底；
- P1-10 对比度；
- P1-11 触控目标、语义、字体缩放；
- P1-12 图标分辨率；
- P2-8 搜索页背景、P2-5 类型区分、P2-7 haptic/隐藏行为等视觉交互；
- 重新拍摄 light/dark 截图。

**交付**

- `values/strings.xml` + `values-zh/strings.xml`（如选择完整迁移）；
- 中英文各一组截图；
- TalkBack / fontScale 1.3 手工验收记录；
- 一份本地化检查脚本或测试，防止再次出现绕过。

**建议版本**：v0.2.0（可能有较大 diff，单独发布更安全）。

### 阶段 D：架构、CI 与文档

**范围**

- P2-19 拆分 `MainViewModel` / 大 UI 文件；
- P2-20 合并弱密码逻辑；
- P1-16 PR CI + Lint 门禁；
- P3 死代码/依赖/Manifest 清理；
- P2-17 / P2-18 文档、截图、SECURITY.md；
- 评估依赖升级与 R8 full mode。

**交付**

- 不改变行为的重构 PR；
- CI 绿；
- `README` / `DESIGN` / `SECURITY` 同步。

**建议版本**：v0.2.x 或 v0.3.0。

### 建议的执行顺序与提交粒度

1. **A1** 修复 P0-1 + 测试（单独 commit，最高优先）。
2. **A2** P0-2 / P0-3（安全状态 + 外部启动）。
3. **A3** P0-4 / P0-5 / P1-14 / P1-15（导入边界 + 生物识别）。
4. **B** 按 bug 分组小 commit，每个 commit 附验收说明。
5. **C** 本地化迁移单独分支/大 commit，避免和功能修复混在一起。
6. **D** 纯重构 / CI / 文档。

每个阶段结束都跑：

```powershell
.\gradlew.bat :core:test :app:testDebugUnitTest :app:lintDebug
$env:ANDROID_SERIAL = "emulator-5554"
.\gradlew.bat :app:connectedDebugAndroidTest
```

---

## 9. 需要你确认的决策

1. **HOTP / Steam 的产品方向**
   - A. 完整支持（HOTP 计数器、Steam 格式、扫描/编辑都支持）——工作量最大，但导入数据不会“看起来能用实际不能用”。
   - B. 明确 TOTP-only：导入时拒绝/标记跳过，编辑不改类型——最省事，但会丢掉 Aegis/Google 里的 HOTP 条目。
   - C. **保留导入的 HOTP/Steam 只读展示，不改写类型，HOTP 提供“下一个码”**——推荐，兼顾兼容性和工作量。
2. **本地化方案**
   - A. **完整迁移到 Android resources**（推荐，彻底解决 SearchScreen 这类绕过和复数/上下文问题，但 diff 较大）。
   - B. 保留 `LocalizedText` 字典，只补缺口 + 加静态检查（快，但长期仍脆弱）。
3. **UI 优化范围**
   - 只修 P1 缺陷；还是顺带做 P2 的收藏、URL 打开、删除保险库、首页类型徽标等体验项？
   - 我建议：P1 必修；P2 中“收藏 / URL 打开 / 删除保险库”作为可选，先确认是否要放进本轮。
4. **发布节奏**
   - 方案一：v0.1.3 只发阶段 A（安全修复），阶段 B/C/D 进 v0.2.0；
   - 方案二：A+B 一起发 v0.1.3，C/D 进 v0.2.0。
   - 我倾向方案一：P0 尽快到用户手里，功能/UI 大改单独发。
5. **自动锁定架构**
   - 先修 P0-3 的遗漏入口即可；还是顺便把自动锁定改成生命周期/`ProcessLifecycleOwner` 驱动，减少手工 `prepareExternalActivity` 的遗漏风险？
   - 我建议先修遗漏 + 封装统一入口，架构改造放阶段 D。

---

## 10. 附录

### 10.1 关键文件行号索引

| 主题 | 位置 |
|---|---|
| 改密码密钥共享 | `core/.../vault/VaultContainer.kt:274-308` |
| 密钥清零 | `core/.../vault/VaultContainer.kt:55-57` |
| 改密码调用 | `app/.../ui/MainViewModel.kt:281-318` |
| 敏感 `rememberSaveable` | `AuthScreens.kt:59,132`; `SettingsDialogs.kt:56,127,171,226`; `PasswordScreens.kt:615,617`; `TokenScreens.kt:397,642` |
| 外部 Activity 保护 | `MainViewModel.kt:193`; `MainActivity.kt:70-81` |
| 遗漏入口 | `SettingsScreen.kt:220`; `IconPickerDialog.kt:144,153` |
| Aegis scrypt | `AegisImporter.kt:46-48,121-138` |
| 生物识别 | `BiometricVault.kt:25-35,84-119`; `MainViewModel.kt:488-513` |
| TOTP ticker | `TokenScreens.kt:143-164,207-218` |
| 令牌类型覆盖 | `TokenScreens.kt:389,442,676` |
| OTP 校验 | `Otp.kt:196-199`; `AegisImporter.kt:195` |
| 搜索残留 | `PasswordScreens.kt:116,156-160` |
| URL 键盘 | `PasswordScreens.kt:738` |
| 删除文案/永久删除 | `PasswordScreens.kt:394-395`; `TrashScreen.kt:250` |
| UTC 时间 | `PasswordScreens.kt:366`; `TrashScreen.kt:238` |
| 路由状态 | `KeyCaseApp.kt:156-160` |
| 本地化绕过 | `SearchScreen.kt:24`; `EditorIconRow.kt:15` |
| 对比度 | `theme/Theme.kt:23-24,48` |
| A–Z 索引 | `AlphabetIndex.kt:98-147` |
| 图片解码 | `IconPickerDialog.kt:378-395`; `ImportedIconPack.kt:89,104-120` |
| 图标分辨率 | `AegisIconPack.kt:315-333` |
| 解压上限 | `VaultContainer.kt:399-400` |
| 导入覆盖 | `MainViewModel.kt:488-513` |

### 10.2 未本地化的中文字面量（静态扫描）

扫描 `app/src/main` 中不在 `LocalizedText.kt` 精确词典里的中文字面量，共 27 处；大部分由动态 pattern 覆盖，真正缺失的主要是：

- `AutoBackupManager.kt:26-38` 的备份错误（4 条）；
- `MainViewModel.kt:375/561/614` 的导入/备份状态与错误；
- `PasswordScreens.kt:449/451/454` 的“N 位 / N 秒 / 密钥”；
- `SettingsDialogs.kt:189` 的 `otpauth-migration:// 链接`；
- `SettingsScreen.kt:150` 的图标导入状态；
- 错误消息/Toast 仍有中英混杂。

另外有 17 处 `contentDescription` 直接写死中文（返回、编辑、删除、复制、关闭、收藏、恢复、永久删除、显示/隐藏密码等）。

### 10.3 Lint 摘要

`lintDebug` 无 error。值得处理的 warning：

- 依赖版本落后：`core-ktx 1.10.1 → 1.19.1`、`lifecycle 2.6.1 → 2.11.0`、`activity-compose 1.8.0 → 1.13.0`、`fragment 1.8.5 → 1.9.1`、Compose BOM `2026.02.01 → 2026.09.00`、Kotlin `2.2.10 → 2.4.21`、BouncyCastle `1.80 → 1.86`。
- `LockedOrientationActivity` / `DiscouragedApi`：`CaptureActivity` 固定竖屏，Android 16+ 会忽略。
- `DataExtractionRules`：`allowBackup=false` 已存在，但 target 37 建议补 `android:dataExtractionRules`。
- `RedundantLabel`：Activity 的 `android:label` 与 application 重复。
- `UnusedResources`：`colors.xml` 中 purple/teal/black/white 等。
- `AutoboxingStateCreation`：`SettingsDialogs.kt:292-294` 的 `mutableStateOf(Float)`。
- `IconLauncherShape`：5 个密度 launcher PNG 铺满方形；如果使用自适应图标，可只保留 anydpi。
- `ModifierParameter`：`BrandAvatar` / `LetterAvatar` 的 Modifier 不是第一个可选参数。
- `UseKtx`：`toUri`、`edit`、`createBitmap` 等可读性建议。

### 10.4 验证命令

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
.\gradlew.bat :core:test :app:testDebugUnitTest :app:assembleDebug
.\gradlew.bat :app:lintDebug
$env:ANDROID_SERIAL = "emulator-5554"
.\gradlew.bat :app:connectedDebugAndroidTest
```

---

## 11. 结论

KeyCase 的“产品骨架”和“安全骨架”都已经成型，问题不在于方向，而在于**关键状态的所有权、不可信输入边界、以及 UI 文案/状态的系统性**。

建议不要直接进入零散修补，而是按第 8 节分四个阶段推进：先让数据不再丢、敏感值不再落保存态、导入边界可控；再修 TOTP/搜索/时间/回收站等日常正确性；然后统一国际化和无障碍；最后做架构、CI 和文档。每个阶段都可以独立验收、独立发布。

等你确认第 9 节的决策后，我会把方案收敛成一份带具体任务清单、验收标准和提交顺序的最终 Review 方案，然后从阶段 A 开始逐步开发。
