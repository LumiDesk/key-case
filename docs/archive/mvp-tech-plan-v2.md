# 手机密码管理器 · MVP 技术方案 v2

> ⚠️ 2026-10-31 讨论后范围已变更：自动填充不再是 v1 核心（用户明确“不重要，甚至不需要”），TOTP 升为核心，密码与 TOTP 同一加密库；本文的自动填充/排期部分待重写。最新设计见 `设计决策-v0.5.md`。
>
> 日期：2026-10-31 ｜ 前置：`调研与方案讨论.md`
> 约束：**Android Only ｜ 纯本地、无云同步 ｜ 自己先用，成熟后公开**
> 开发方式：AI 写代码（Vibe Coding），你负责方向、验收和真机测试

---

## 1. 范围

### 做（MVP）

- 创建保险库 / 主密码解锁 / 生物识别解锁
- 登录条目的增删改查、搜索
- 密码生成器
- **自动填充**（填充 + 保存新账号提示）
- 自动锁定、防截屏、剪贴板定时清理
- 加密备份导出 / 导入、自动备份到用户指定文件夹
- 中文 UI，深色模式

### 不做（MVP 之后）

- 云同步、账号体系、多设备
- 分享、团队、浏览器扩展、桌面端、iOS
- 附件、卡片/身份条目、Passkey、TOTP（TOTP 放 M5）
- 图标自动抓取（无网络权限，做不了）

### 一个关键产品决策：**不申请 INTERNET 权限**

纯本地 + 无网络，是这类产品最强的信任状：用户可以在系统设置里看到"此应用没有网络权限"，比任何隐私政策都硬。代价是没有崩溃上报、没有在线图标、没有检查更新（应用商店负责更新）。

---

## 2. 关键决策与理由

| 决策 | 选择 | 理由 |
|---|---|---|
| 存储形态 | **单个加密文件**（不是 SQLCipher 数据库） | 无同步场景下文件最自然：备份=复制、迁移=导入导出、测试=读写文件；省掉 Room/SQLCipher/KSP 一整条链，AI 迭代更快 |
| 加密库 | **libsodium**（XChaCha20-Poly1305）+ **argon2kt**（Argon2id） | 成熟、有 RFC 测试向量；24 字节 nonce 不用担心碰撞 |
| 架构 | 单模块 + 分包，**不用 Hilt** | 依赖越少，AI 越不容易编错；手写 `AppContainer` 足够 |
| 序列化 | kotlinx.serialization JSON | 可读、易调试；体积对这个量级无所谓 |
| 最低版本 | minSdk 26（Android 8.0） | 覆盖自动填充 API；InlineSuggestions 在 30+ 优雅降级 |
| 生物识别 | 可选开启，Keystore 绑定 | 便利性优先；失败回退主密码；换指纹即失效 |
| 备份 | 加密文件导出 + 可选目录自动备份（SAF） | 无云同步时，**数据丢失是头号风险**，不是被黑 |

> 你提到"文件被别人拿到也不担心解密"——这个判断成立，但有两个前提：**KDF 足够慢 + 主密码足够强**。本地文件可以被离线暴力破解一辈子，没有服务器帮你限速。所以 Argon2id 参数要按设备校准，主密码要设强度门槛。

---

## 3. 架构

```
UI (Compose) ── ViewModel ── VaultRepository ── VaultFile (加解密/原子写)
                                   │
                            VaultSession（内存中的已解锁状态）
                                   │
        ┌──────────────────────────┼──────────────────────────┐
   AutofillService            BiometricUnlock             BackupManager
   （读 session）             （Keystore 解包 vaultKey）   （SAF 导出）
```

- **VaultSession**：单例，持有 `vaultKey` 和解密后的 `Vault` 对象；锁定即清零。
- **VaultRepository**：所有读写都走它；每次修改 → 重新序列化 → 加密 → 原子写盘。
- **AutofillService 与 UI 同进程**（默认），直接读 session；未解锁时走"认证 Dataset"。

---

## 4. 文件格式（v1）

```
偏移   长度   字段
0      4     magic  "PVLT"
4      1     format_version = 1
5      1     kdf_id = 1 (Argon2id)
6      4     m_cost (KiB, uint32 LE)
10     4     t_cost (uint32 LE)
14     1     p_cost
15     1     reserved = 0
16     16    salt
32     24    wrap_nonce
56     48    wrapped_vault_key = AEAD(wrapKey, wrap_nonce, vaultKey, AAD=0..32)
104    24    payload_nonce
128    ...   payload_ciphertext = AEAD(vaultKey, payload_nonce, payload_json, AAD=0..128)
```

- 头部（0..128）作为 AAD 参与认证：改一个字节，解密就失败。
- `payload_json` 结构：

```json
{
  "schema": 1,
  "vault_id": "uuid",
  "created_at": "2026-10-31T12:00:00Z",
  "items": [
    {
      "id": "uuid", "type": "login",
      "title": "", "username": "", "password": "",
      "urls": [], "notes": "", "tags": [],
      "created_at": "", "updated_at": ""
    }
  ]
}
```

- 写入必须**原子**：写 `vault.tmp` → `fd.sync()` → `rename` 覆盖 `vault.pvlt`；旧文件保留为 `vault.pvlt.bak`。
- 读取顺序：主文件失败 → 尝试 `.bak` → 提示用户，绝不静默丢数据。
- 未知 `format_version` 拒绝打开；`schema` 旧版本在内存中迁移后再写回。

---

## 5. 密钥层级与生命周期

```
主密码 + salt ──Argon2id(m,t,p)──► masterKey (32B)
                                      │ HKDF-SHA256("pvlt-wrap-v1")
                                      ▼
                                   wrapKey (32B)
                                      │ 解包
                                      ▼
随机 vaultKey (32B) ◄── wrapped_vault_key
                                      │ 直接加密 payload
                                      ▼
                                  vault.pvlt
```

- **改主密码**：只重算 masterKey/wrapKey、重写 `wrapped_vault_key`，payload 不动。
- **生物识别**：Keystore 里生成 AES-GCM 密钥（`setUserAuthenticationRequired(true)`、`setInvalidatedByBiometricEnrollment(true)`、`setUnlockedDeviceRequired(true)`），用它加密一份 `vaultKey` 存 prefs；验证成功后解出 vaultKey，跳过 Argon2id。
- **内存**：key 用 `ByteArray`，锁定/退出时 `fill(0)`；不打印、不进日志、不进崩溃上报（本来也没有网络）。
- **恢复**：MVP 先做"导出加密备份"，M5 再加恢复密钥（随机 128-bit，单独包裹 vaultKey），避免用户忘密码即全灭。

KDF 参数建议：首次创建时在设备上校准到 ~600ms，`m ∈ [32MiB, 128MiB]`、`t ∈ [2, 4]`、`p = min(4, 核数/2)`；打开时若参数低于下限则拒绝并提示（防呆，不是防攻击）。

---

## 6. 自动填充（体验核心）

### 流程

1. 用户在系统设置里启用本应用为 Autofill Service。
2. `onFillRequest`：解析 `AssistStructure`，按 **包名 / webDomain** 匹配条目。
3. 已解锁 → 直接返回 Dataset；未解锁 → 返回带 `setAuthentication()` 的 Dataset，点击后打开解锁页，解锁完系统会重新发起填充请求。
4. 登录成功页出现保存提示：`SaveInfo` + `onSaveRequest`，弹确认后写入。
5. **严格匹配**：只对完全匹配的包名/域名填充；UI 上显示来源；不做"猜测性填充"。

### 细节

- 自己的包名加入黑名单，避免填充自己的主密码框（否则会递归/误导）。
- 主密码输入框 `importantForAutofill="no"`。
- 解析字段时优先 `autofillHints`，其次 view id / hint 文本，最后兜底。
- 填充后不自动提交登录，交给用户点。
- 保存时去重：同包名+同用户名则提示更新。

---

## 7. 安全清单（发布前逐项过）

- [ ] `allowBackup=false` + `dataExtractionRules` 排除 vault 文件（防止被系统云备份带走）
- [ ] 所有界面 `FLAG_SECURE`；最近任务预览遮挡（API 33+ `setRecentsScreenshotEnabled(false)`）
- [ ] 解锁页 `setHideOverlayWindows(true)`（API 31+），敏感按钮 `filterTouchesWhenObscured`
- [ ] 剪贴板：复制密码 60s 后清空；API 33+ 标记 `EXTRA_IS_SENSITIVE`；锁定时立即清空
- [ ] 自动锁定：退后台 N 秒/立即；失败次数递增延迟（不做"永久锁定"，避免自锁）
- [ ] 密码框 `IME_FLAG_NO_PERSONALIZED_LEARNING`，减少输入法学习
- [ ] Release 关闭 debuggable、开启 R8、移除日志
- [ ] 检查 merged manifest 确认没有 `INTERNET` 权限（依赖可能偷偷加）
- [ ] 不在异常信息/文件名/标题里写敏感内容
- [ ] 导入/导出明文 CSV 必须二次确认并警告

---

## 8. 备份（比加密更重要）

无云同步时，用户丢数据的概率远高于被破解。MVP 必须有：

1. **手动导出**：SAF 选位置，导出 `.pvlt`（还是加密的），文件名带日期。
2. **导入**：选文件 → 输入该文件的主密码 → 合并或覆盖（默认合并，按 id 去重）。
3. **自动备份**：用户选一个目录（可以是网盘同步目录），每次保存后写一份，保留最近 5 份；用 SAF 持久化权限，不需要网络权限。
4. **首次创建后引导**：明确告诉用户"没有云同步，请立即导出备份"，并提供"验证备份可打开"的入口。

---

## 9. 技术栈与依赖

| 用途 | 选型 |
|---|---|
| 语言 / UI | Kotlin 2.x、Jetpack Compose、Material 3 |
| 架构 | ViewModel + StateFlow + 单向数据流；手写 `AppContainer` |
| 导航 | Navigation Compose |
| 序列化 | kotlinx.serialization |
| 加密 | `com.goterl:lazysodium-android:5.2.0`（XChaCha20-Poly1305）+ `com.lambdapioneer.argon2kt:argon2kt`（Argon2id） |
| 生物识别 | `androidx.biometric:biometric:1.1.0` |
| 设置存储 | DataStore Preferences |
| 文件选择 | SAF（`ACTION_OPEN_DOCUMENT_TREE` / `ACTION_CREATE_DOCUMENT`） |
| 构建 | AGP 8.x、Gradle KTS、version catalog、JDK 17 |
| SDK | compileSdk/targetSdk 36，minSdk 26 |

备选：如果 argon2kt 的原生库在某台设备上出问题，退回 Bouncy Castle 的 `Argon2BytesGenerator`（纯 Java，慢 2–3 倍但零 ABI 风险）。

---

## 10. 工程结构

```
app/src/main/java/<pkg>/
  App.kt, MainActivity.kt
  di/AppContainer.kt
  crypto/  CryptoEngine.kt  Argon2.kt  Aead.kt  KdfParams.kt  SecretBytes.kt
  vault/   VaultFile.kt  VaultRepository.kt  VaultModels.kt  VaultSession.kt
  ui/      unlock/  list/  edit/  generator/  settings/  backup/
  autofill/ PmAutofillService.kt  StructureParser.kt  DatasetFactory.kt
  biometric/ BiometricUnlock.kt
  backup/  BackupManager.kt
```

`crypto/` 不依赖 Android（除 Keystore），保持可单测；将来要 iOS 或换 Rust 时，这层是边界。

---

## 11. 里程碑与验收

| 阶段 | 内容 | 验收标准 | 预估 |
|---|---|---|---|
| M0 | 骨架、依赖、CI（本地 gradle test） | 空 App 能跑，`./gradlew test` 通过 | 2–3 天 |
| M1 | 文件格式 + 加密 + 创建/解锁 | 建库、重启后解锁、错密码报错、改一个字节解密失败 | 4–6 天 |
| M2 | 列表/搜索/编辑/生成器 | 增删改查可用，1000 条不卡 | 4–6 天 |
| M3 | 自动填充 + 保存提示 | 在 2 个真实 App + 1 个网页上填充成功 | 4–6 天 |
| M4 | 生物识别、自动锁定、截屏/剪贴板、备份 | 真机过安全清单；导出→删库→导入恢复 | 3–5 天 |
| M5 | 打磨（引导、空状态、深色、TOTP、恢复密钥） | 给一个非技术朋友能用 | 3–5 天 |

总计约 **3–5 周** 的高强度迭代（取决于真机测试和返工）。公开产品再加：图标/文案/商店素材、隐私政策、软著/备案。

---

## 12. 测试计划

**单元测试（必须）**

- Argon2id RFC 9106 测试向量
- XChaCha20-Poly1305 RFC 8439 / libsodium 向量
- 文件 round-trip：建库→存→读→字段一致
- 负例：错密码、篡改 header、篡改密文、截断文件、未知版本
- KDF 参数下限校验
- schema 迁移
- 大库性能：5000 条保存/搜索 < 200ms

**真机手测**

- 自动填充：微信/淘宝/银行 App/Chrome（不同 `autofillHints` 实现）
- 生物识别：录入新指纹后旧 key 失效
- 杀进程后自动填充是否要求解锁
- 断电/强杀时文件不损坏（写一半）
- 备份到网盘目录再恢复

---

## 13. Vibe Coding 的注意事项

1. **先冻协议，再写代码**：文件格式、密钥层级、KDF 参数写成文档，AI 不许"顺手优化"。
2. **加密代码必须配 KAT 测试**，没有测试向量不算完成；每次改动都跑。
3. **不要让 AI 自己发明加密流程**；只允许调用 libsodium/argon2kt 的固定 API。
4. 一次只做一个里程碑，做完真机验收再进入下一个；别让 AI 同时改 UI 和 crypto。
5. 从第一天就 `git init`，每个能跑的版本打 tag；签名 keystore 单独备份（丢了就无法更新已发布应用）。
6. 让 AI 先写测试再写实现，尤其是文件读写和自动填充解析。
7. 代码评审重点看：nonce 是否随机、key 是否清零、异常里是否带明文、是否误加网络权限。

---

## 14. 待确认

1. **单文件 vs SQLCipher**：我推荐单文件（理由见 §2），你确认吗？
2. **minSdk 26** 可以吗（覆盖 Android 8.0+）？
3. 公开时是否**开源**（建议 GPL-3.0，密码管理器开源是信任加分项）？
4. TOTP 放 M5 还是更晚？
5. 应用名 / 包名（例如 `com.example.vault`，定了再改成本高）。


