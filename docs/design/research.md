# 手机密码管理器：选型调研与自研方案讨论

> 日期：2026-10-31 ｜ 状态：讨论稿（未写代码）
> 目标：先确定"用现成的还是自己做"，再确定"如果做，用什么技术栈、怎么分期"。

## 0. 结论先行

1. **只想用**：首选 **Bitwarden**（免费、开源、全平台、可自建）；想数据完全自己掌控，用 **Vaultwarden** 自建服务端；坚持纯离线，用 **KeePassDX（Android）/ KeePassium（iOS）+ KDBX 文件 + 网盘同步**。
2. **想做产品/练手**：不要做"通用型密码管理器"的全量功能。先选一个切口（Android 优先、本地优先、中文体验、自托管、passkey 优先），把**自动填充体验 + 密钥管理**做扎实，比堆功能重要一个数量级。
3. **技术栈**：Android 单端起步用 **Kotlin + Jetpack Compose**；确定要双端再考虑 **KMP** 或 **Flutter + 原生自动填充插件**；追求长期正确可以上 **Rust core + UniFFI**，但对个人开发者偏重。
4. **真正的难点不是加密算法**，是密钥层级设计、自动填充的安全与体验、备份/恢复/迁移、以及长期维护。算法用 libsodium 这类成熟库，别自己拼。

---

## 1. 现成方案：先看别人做到什么程度

### 1.1 主流选择对比

| 方案 | 形态 | 开源 | 同步 | 自动填充 | 适合谁 |
|---|---|---|---|---|---|
| **Bitwarden** | 全平台 + 浏览器扩展 | 是（GPL/AGPL 为主） | 官方云 / 自建 | 好 | 大多数人，闭眼选 |
| **Vaultwarden** | 只做服务端（Rust） | 是 | 自建，兼容 Bitwarden 客户端 | 取决于客户端 | 有 VPS/ NAS，想自托管 |
| **KeePassDX** | Android | 是（Kotlin） | 无，靠文件同步 | 好（KDBX 生态最佳之一） | 纯离线、极客 |
| **KeePassium** | iOS | 是（Swift，Freemium） | iCloud/WebDAV 等 | 好 | iPhone + KeePass 文件 |
| **KeePassXC** | 桌面（C++/Qt） | 是 | 文件 | 浏览器扩展 | 桌面端配合 KeePass 系 |
| **Proton Pass** | Android/iOS/Web | 移动端代码已开源 | Proton 云 | 好 | 已经在用 Proton 生态 |
| **Keyguard** | Android | 是（Kotlin/Compose） | 连 Bitwarden/KeePass 服务 | 好 | 想看高质量参考实现 |
| **Passbolt** | 自托管，团队向 | 是 | 自建 | 一般 | 小团队共享密码 |
| **Padloc** | PWA/桌面/移动壳 | 是（TS） | 自建 | 一般 | 想看 Web 技术栈怎么做 |
| **Pass (passwordstore)** | CLI + Android 客户端 | 是 | Git | 一般 | GPG/CLI 用户 |

补充：

- **Bitwarden** 在 2025 年把移动端迁到了 .NET MAUI 的原生实现（官方称 native mobile apps），体验比早期的 Xamarin 版好很多；它事实上已经是"开源密码管理器"的默认答案。
- **Proton Pass** 的 Android 客户端代码在 `protonpass/android-pass`，适合研究"商业级开源 App 怎么组织"。
- **Keyguard** 是一个个人开发者做的 Bitwarden/KeePass 客户端，Kotlin + Compose，代码结构和自动填充实现都值得读，适合作为我们自研的参照物。
- **Strongbox**（iOS/macOS）很好用但**闭源**，如果"开源"是硬指标就排除。

### 1.2 国内使用要注意

- Bitwarden 官方云在国内可访问，但速度一般；对稳定性敏感就自建 Vaultwarden（境外 VPS 或国内 VPS，国内 80/443 需要备案）。
- Proton 系服务在国内访问不稳定，需自行确认。
- KeePass 系 + 坚果云/OneDrive/Syncthing 是最"抗封锁"的组合，代价是同步冲突要自己处理。
- 国内应用商店上架需要 **App 备案 + 软著**，苹果中国区也需要备案号；个人开发者做公开分发的成本不低（详见 2.9）。

### 1.3 决策建议

```
只是想安全地用
├─ 愿意用云、要省事 ────────── Bitwarden 官方云
├─ 有服务器、要自主 ────────── Vaultwarden + Bitwarden 客户端
└─ 要绝对离线 ──────────────── KeePassDX/KeePassium + KDBX + 网盘

想做东西
├─ 学习/作品集 ─────────────── Android 单端 MVP（本文 2.x）
├─ 小团队共享 ─────────────── 别自研，Passbolt / Vaultwarden 组织
└─ 公开产品 ───────────────── 先想清楚差异化，再谈技术
```

---

## 2. 如果我们要自己做

### 2.1 先回答三个问题（它们决定一切）

| 问题 | 选项 | 影响 |
|---|---|---|
| 给谁用？ | 自己 / 小团队 / 公开产品 | 决定要不要合规、要不要审计、要不要多用户 |
| 哪些平台？ | Android only / iOS only / 双端 | 决定技术栈和 2~3 倍工作量 |
| 要不要云同步？ | 纯本地 / 文件同步 / 自建服务 | 决定数据格式、冲突模型、后端 |

我的默认假设（如果不是请纠正）：**Android 优先、先本地后同步、个人/小范围使用**。下面按这个假设展开。

### 2.2 威胁模型：先写清楚"防什么、不防什么"

**要防：**

- 手机丢失/被偷 → 没有主密码打不开；数据库文件被拷走也解不开。
- 云厂商/服务器管理员偷看 → 零知识，服务端只有密文。
- 网络中间人 → TLS + 端到端加密，服务端也解不开。
- 备份泄露、剪贴板泄露、截屏、肩窥、日志/崩溃上报带出明文。
- 自动填充被钓鱼（恶意 App 伪造登录框骗取填充）。

**不防（要诚实告诉用户）：**

- 已 root/越狱、被植入木马、键盘记录器、恶意无障碍服务。
- 系统级备份（如 iCloud 备份、部分厂商云备份）可能包含 App 数据。
- 被胁迫交出主密码；屏幕录制。
- 供应链攻击（依赖库被投毒）。

**结论：** 密码管理器的安全 = **零知识设计 + 客户端加密 + 最小化服务端信任 + 严格的自动填充匹配**，而不是"用了 AES"。

### 2.3 密码学设计（核心，不能拍脑袋）

#### 密钥层级

```
主密码 + 随机 salt（每库独立，存明文于头部）
        │  Argon2id(m=64MiB, t=3, p=4)   ← 参数可调，随库存储
        ▼
   Master Key (32B)
        ├── HKDF(info="auth")  → Auth Hash  ──→ 发给服务器做认证
        └── HKDF(info="wrap")  → Wrapping Key
                                      │
随机 Vault Key (32B) ─────────────────┘
        │  AEAD 加密后存本地/服务器（wrapped_vault_key）
        ▼
   每条记录：AEAD(Vault Key, 随机 nonce) → ciphertext
```

要点：

- **主密码永远不出设备**；服务器只见到 Auth Hash（服务端再做一次慢哈希存储）。
- **换主密码只重wrap Vault Key**，不用重加密所有条目。
- **恢复密钥**：生成一个随机 128-bit recovery code，用它单独包裹一份 Vault Key。用户忘主密码时不至于数据全灭——这是产品必修课，很多自研项目忽略。
- **KDF 参数随库存储**，解锁时若发现参数低于当前目标，用新参数重wrap（渐进升级）。
- 条目结构带 `schema_version`，为将来迁移留路。

#### 算法与参数

| 用途 | 推荐 | 说明 |
|---|---|---|
| 口令 KDF | **Argon2id** | RFC 9106；OWASP 最低 m=19MiB,t=2,p=1，密码管理器建议更高（64MiB/3/4 或按设备校准到 ~0.5–1s） |
| 对称加密 | **XChaCha20-Poly1305**（libsodium） | 24 字节随机 nonce，基本不用担心碰撞；比 AES-GCM 的 12 字节 nonce 更好管 |
| 备选 | AES-256-GCM | 只有在 nonce 严格计数/随机且绝不复用时才安全 |
| 随机数 | 平台 CSPRNG / libsodium | 密码生成、salt、nonce、恢复密钥都用它 |
| 本地库 | SQLCipher 4 | 整库 AES-256，成熟；密钥放 Keystore/Keychain 保护 |
| TOTP | RFC 6238 | 种子当高价值密文存，注意时间漂移 |
| 哈希/认证 | HKDF-SHA256 + 服务端 Argon2id/bcrypt | Auth Hash 与加密密钥必须分开派生 |

#### 明确不要做的事

- ❌ 用 AES-CBC + 自己拼 HMAC（ padding oracle、MAC-then-encrypt 坑）。
- ❌ 用主密码的 SHA-256 当加密密钥。
- ❌ 同一个 nonce 加密两条数据（GCM 下是灾难性的）。
- ❌ 把明文索引、明文日志、崩溃堆栈里的密码落盘/上报。
- ❌ 用 `String` 存密码（不可变、GC 会复制）；用 `ByteArray`/原生内存，用完 `fill(0)`。
- ❌ 自己实现 Argon2/AES/ChaCha（用 libsodium、Tink、平台 CryptoKit）。
- ❌ 把"root 检测"当安全边界（可绕过，只能当提示）。

### 2.4 技术栈选型

| 方案 | 共享程度 | 自动填充 | 加密/生态 | 上手成本 | 适合 |
|---|---|---|---|---|---|
| **原生双端**（Kotlin+Compose / Swift+SwiftUI） | 0 | 最好 | 最稳 | 最高（两份） | 追求体验与安全 |
| **KMP**（Kotlin 共享 core + 原生 UI） | 60–70% | 仍需原生模块 | 好（Kotlin/Native 调 libsodium 有摩擦） | 中高 | 会 Kotlin、确定双端 |
| **Rust core + UniFFI + 原生 UI** | 80% | 原生模块 | 最好（内存可控、易审计） | 高（构建链复杂） | 长期正确、有系统编程经验 |
| **Flutter** | UI+逻辑 80% | 必须写 Kotlin/Swift 插件 | 好（FFI 调 libsodium） | 中 | 一个人想快速出双端 |
| **React Native** | 类似 Flutter | 同上 | 一般（JS 引擎面大） | 中 | 前端背景 |
| **.NET MAUI** | 高 | 原生模块 | 好 | 中 | C# 背景（Bitwarden 的选择） |

**我的推荐（按你的情况三选一）：**

1. **只做 Android / 想最快验证** → **Kotlin + Compose**。
   - `core` 模块写成纯 Kotlin、不依赖 Android API；加密用接口隔离（`CryptoEngine`），Android 实现用 libsodium JNI 或 Google Tink。
   - 将来要 iOS，再把 `core` 迁 KMP，成本可控。
2. **确定双端、一个人** → **Flutter** + 原生自动填充插件。
   - UI 和业务逻辑共享，自动填充/生物识别/Keystore 仍写 Kotlin 与 Swift；这是绕不开的。
3. **想学安全工程 / 长期维护** → **Rust `vault-core` + UniFFI**，Android/iOS 只做壳。
   - 加密、序列化、同步协议都在 Rust，双端复用，最容易做审计；代价是构建链和调试成本。

**不建议**：用 WebView/PWA 承载自动填充（平台限制），或一上来就双端 + 云同步 + 团队共享 + 浏览器扩展全做。

#### 本地存储

- Android：Room + SQLCipher（`net.zetetic:sqlcipher-android`），或 SQLDelight + SQLCipher。
- iOS：GRDB + SQLCipher。
- **整库加密 vs 字段级加密**：MVP 用整库 SQLCipher 最简单；同步时每条记录再单独 AEAD 加密，服务端只存 blob。字段级加密只在"服务端要搜索"时才需要，MVP 不需要。
- 搜索：解锁后在内存建索引，不要把明文索引落盘。

### 2.5 数据模型与同步（草案）

```sql
vault(id, name, kdf_salt, kdf_params, wrapped_vault_key, rev, created_at)
item(id, vault_id, type, ciphertext, nonce, rev, deleted_at, updated_at)
attachment(id, item_id, blob_ref, size, nonce)
device(id, name, last_seen, wrapped_key)
```

条目明文（加密前的 JSON/CBOR）：

```json
{
  "type": "login",
  "title": "...", "username": "...", "password": "...",
  "urls": ["..."], "notes": "...", "totp": "...",
  "custom_fields": [{"name": "...", "value": "...", "hidden": true}],
  "created_at": "...", "updated_at": "..."
}
```

同步协议（够用就好）：

- `GET /sync?since=rev` 拉增量；`POST /items` 带 `base_rev` 提交。
- 冲突：条目级 last-write-wins + 墓碑（`deleted_at`）；字段级合并留到以后。
- 附件：分块上传对象存储（S3/R2），数据库只存引用。
- 服务端技术：Go / Node / Kotlin Ktor + Postgres 或 SQLite 都行；个人项目用 Cloudflare Workers + D1/R2 最省运维，但国内访问是问题。
- **无服务器方案**：WebDAV（坚果云/Nextcloud）或 iCloud Drive 存一个加密 blob。实现最简单，多设备冲突体验差，适合 MVP 之后。

### 2.6 自动填充：真正的胜负手

**Android**

- `AutofillService`（API 26+）+ `InlineSuggestions`（API 30+）；`saveInfo` 支持保存新账号。
- 严格匹配：用 `FillContext` 的包名/域名匹配条目，UI 上显示"为哪个 App/网站填充"，防钓鱼。
- 解锁：`BiometricPrompt`；填充前二次确认可配置。
- 防截屏：`FLAG_SECURE`；剪贴板 60 秒清除 + Android 13 `EXTRA_IS_SENSITIVE`。
- Passkey：Android 14+ 的 **Credential Manager**，实现 `CredentialProviderService`，这是 2026 年做密码管理器绕不开的能力。
- 注意：自动填充框架本身有攻击面（伪造登录框、覆盖 UI），别做"无脑自动填"。

**iOS**

- `ASCredentialProviderExtension`（AutoFill）+ `ASCredentialIdentityStore` 提供 QuickType 建议。
- Passkey：iOS 17+ 第三方 provider 才被允许，需要 entitlement + associated domains，审核与配置都更麻烦。
- 扩展是独立进程，解锁状态要通过 App Group + Keychain 共享；扩展内不能弹自定义 UI（系统渲染），体验受限。
- 主 App 与扩展共享数据库时，注意 SQLCipher 密钥的 Keychain 可访问性（`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` + biometric ACL）。

**结论**：如果只做 Android，自动填充能做得比 iOS 好很多；这也是"Android 优先"的一个理由。

### 2.7 其他容易被忽略的产品细节

- **恢复**：恢复密钥 + 加密备份导出（带版本号），并教用户验证备份可用。
- **迁移**：支持从 Bitwarden/Chrome/KeePass CSV 导入，支持导出，避免用户被锁死。
- **密码生成**：长度/字符集可配，避免 modulo bias，支持 EFF 词表 passphrase。
- **TOTP**：扫码/手动录入，注意时间同步与备份。
- **锁定策略**：退后台立即锁 / 超时锁 / 失败次数递增延迟；生物识别失败回退主密码。
- **隐私**：崩溃上报、分析 SDK 一律不带内容；截图/最近任务预览要遮挡。
- **可用性**：解锁速度、搜索速度、填充步骤数，直接决定用户会不会用下去。

### 2.8 MVP 范围与排期（现实估计）

| 阶段 | 内容 | 有经验的全职 | 业余 |
|---|---|---|---|
| P0 | 威胁模型、密钥层级、线框、技术选型 | 3–5 天 | 1–2 周 |
| P1 | 本地库、解锁、列表/搜索、增删改、生成器、生物识别、加密导出 | 4–6 周 | 2–3 个月 |
| P2 | Android 自动填充 + 保存提示 + 防截屏/剪贴板 | 2–3 周 | 1–1.5 个月 |
| P3 | 同步服务 + 多设备 + 冲突 + 附件 | 4–8 周 | 2–4 个月 |
| P4 | TOTP、导入、passkey、审计 | 4–8 周 | 3–6 个月 |
| P5 | iOS（原生或 KMP/Flutter） | 6–10 周 | 3–6 个月 |

- 安全审计（外部）大约 1–4 万美元、2–4 周；公开产品建议做，自用可跳过。
- 长期成本主要在：平台 API 年年变（自动填充、passkey）、加密库升级、用户支持。

### 2.9 合规与分发（如果公开做）

- **中国区 iOS**：App Store 上架需要 **App 备案号**（工信部），个人主体办理和审核都更麻烦；TestFlight/外区账号可自用。
- **国内 Android 商店**：普遍要求 **软著 + App 备案**，部分类目要求企业资质。
- **自用/小范围**：GitHub Releases / F-Droid / 直接装 APK，基本无合规负担。
- **公开产品**：隐私政策、个人信息保护法合规；若服务器在境外且面向国内用户，还会涉及数据出境问题。密码管理器属于高敏感数据，**本地优先 + 可选自托管**是最省事的合规姿势。

---

## 3. 我的建议

1. **先用再造**：花一周认真用 Bitwarden（或 Vaultwarden），记录 10 个让你不爽的点。如果这些点不足以支撑一个产品，就别做——自研密码管理器的安全成本远高于它的功能价值。
2. **如果做，先做 Android 单端**：Kotlin + Compose，`core` 纯 Kotlin，libsodium + SQLCipher，本地优先，自动填充做到"比 Bitwarden 顺手"再谈其他。
3. **先写设计文档再写代码**：密钥层级、数据格式、同步协议、威胁模型，这四页纸比 1 万行代码值钱。
4. **不要碰的东西**：自研加密算法、双端同时开工、MVP 就做共享/团队、把浏览器扩展当第一优先级。
5. **可差异化的方向**（如果要做产品）：中文/本地化体验、本地优先 + 一键自托管、passkey 优先、极简离线、面向家庭/小团队的共享。

---

## 4. 待讨论

1. 目标是**自己用**、**练手/作品集**，还是**公开产品**？
2. 平台：**Android only**、iOS only，还是双端？你更熟 Kotlin、Swift、Dart、Rust 中的哪个？
3. 是否要**云同步**？愿意维护一台服务器吗？还是文件同步（WebDAV/网盘）就够？
4. 能接受的周期：**1 个月试水**，还是**半年做成可用产品**？
5. 有没有安全/密码学背景？愿不愿意为审计付费？

---

## 5. 参考

- Bitwarden：https://bitwarden.com ｜ 移动端仓库：https://github.com/bitwarden/android
- Vaultwarden：https://github.com/dani-garcia/vaultwarden
- KeePassDX：https://www.keepassdx.com ｜ KeePassium：https://keepassium.com
- Proton Pass Android：https://github.com/protonpass/android-pass
- Keyguard：https://keyguard.dev ｜ 架构文档：https://keyguard.dev/docs/architecture/
- Passbolt：https://www.passbolt.com ｜ Padloc：https://padloc.app ｜ pass：https://passwordstore.org
- Android Autofill：https://developer.android.com/identity/autofill/autofill-services
- Android Credential Manager：https://developer.android.com/identity/sign-in/credential-manager
- Apple AuthenticationServices：https://developer.apple.com/documentation/authenticationservices
- OWASP Password Storage Cheat Sheet：https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
- Argon2 RFC 9106：https://www.rfc-editor.org/rfc/rfc9106 ｜ TOTP RFC 6238：https://www.rfc-editor.org/rfc/rfc6238
- libsodium：https://doc.libsodium.org ｜ SQLCipher：https://www.zetetic.net/sqlcipher/
