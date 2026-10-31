# 双钥（TwinKey）— Android 本地密码 + 2FA 管理器

> ⚠️ 2026-10-31 讨论后部分决策已变更：名称改为 **KeyCase**；自动填充降级（v1 不做）；TOTP 升为核心；图标包改用 Aegis 格式（内置 aegis-simple-icons）；许可证按 verifin 使用 **GPL-3.0-or-later**。本文保留作调研记录，最新设计见 `设计决策-v0.5.md` 与 `prototype/`。
>
> 产品方案 v1 ｜ 2026-10-31 ｜ 状态：已被 v0.4 部分取代
> 前置调研：[调研与方案讨论.md](调研与方案讨论.md)
> 参考实现：`D:\Projects\TestSpace\Aegis`（Aegis 3.4.3，GPL-3.0）

---

## 0. 一页纸

| 项 | 结论 |
|---|---|
| 一句话 | 一个**不联网**的 Android App，同时管密码和 TOTP 验证码，自动填充，数据只存在本机 |
| 用户 | 先自己用；打磨好后开源发布 |
| 平台 | Android 8.0+（minSdk 26），targetSdk 36 |
| 云 | 无账号、无同步、**不申请 INTERNET 权限** |
| 存储 | 单个加密容器文件 + 原子写入 + 本地轮转备份 + 可选 SAF 目录备份 |
| 密码学 | Argon2id + XChaCha20-Poly1305；槽位（slot）模型：密码 / 生物识别 / 恢复码 |
| TOTP | otpauth、Steam、HOTP、Google Authenticator 迁移二维码；Aegis 级列表体验 |
| 图标 | 内置图标包 + 兼容 Aegis `.zip` 图标包 + 自定义图片 |
| 自动填充 | `AutofillService`，可设为系统默认密码管理器 |
| 技术栈 | Kotlin + Jetpack Compose + 单 Activity + 手动 DI |
| 周期 | 全职 10–14 周到 v1.0；业余 5–7 个月 |

**产品代号**：双钥 / TwinKey（暂定，发布前做商标与商店重名检索）。

---

## 1. 定位与差异化

### 1.1 要解决什么

现在 Android 上要同时管密码和 2FA，通常得装两个 App：

- **Bitwarden**：密码 + 自动填充 + 云同步，但 TOTP 列表体验一般，而且要账号/云。
- **Aegis**：TOTP 体验和图标包是同类里最好的，但完全不管密码，也没有自动填充。

**双钥 = Aegis 的验证器体验 + Bitwarden 的密码/自动填充能力 + 完全本地。**

### 1.2 差异点（按重要性排序）

1. **零网络**：Manifest 里没有 `INTERNET` 权限，安装后从系统层面证明它传不出去数据。这是比"我们承诺不收集"强得多的信任背书。
2. **一个库、两种条目**：登录条目可以挂 TOTP；纯 TOTP 条目（GitHub、Google 这类）单独存在。一个解锁，两件事都能干。
3. **Aegis 兼容的图标包**：社区现成的 Aegis 图标包（aegis-icons、simple-icons 等）直接导入，不用重新做生态。
4. **本地优先但不裸奔**：单文件加密、原子写入、轮转备份、可导出可迁移，丢了手机不至于丢数据。

### 1.3 不做什么（同样重要）

不做账号、不做云同步、不做多端、不做浏览器扩展、不做桌面端、不做密码共享、不做在线泄露检测、不做广告/统计 SDK、不做无障碍服务式自动填充。

---

## 2. 设计原则

1. **本地优先**：任何功能都不依赖服务器；断网、飞行模式、无 Google 服务都能完整使用。
2. **数据安全 > 功能数量**：宁可少一个功能，不允许出现明文落盘、日志泄露、nonce 复用。
3. **自动填充是一等公民**：不是"顺便支持"，而是从第一版就按"每天用几十次"的标准做。
4. **可迁移**：能导入 Aegis / Google Authenticator，能导出完整备份；不制造数据孤岛。
5. **克制的范围**：v1 只做密码 + TOTP + 自动填充 + 图标，其他一律推后。

---

## 3. 用户与场景

**主用户画像**：Android 中高级用户，关心隐私，已有 Aegis 或 Bitwarden 使用经验，能接受"没有云同步"的代价。

| 场景 | 期望 | 关键设计 |
|---|---|---|
| 登录 App/网站 | 键盘上方出现建议，点一下填进去 | AutofillService + 解锁链路 |
| 看验证码 | 打开 App 就能看到，1 秒内 | 生物识别直达验证器 Tab |
| 新增账号 | 扫码/粘贴 otpauth，自动配图标 | QR + issuer 匹配 |
| 换手机 | 导出加密备份，新机导入 | 自包含备份文件 |
| 忘记主密码 | 用恢复码救回 | 恢复码槽位 |

---

## 4. 功能范围

### P0（v1.0 必须有）

| 模块 | 功能 |
|---|---|
| 保险库 | 创建、解锁、锁定、修改主密码、恢复码、生物识别解锁、自动锁定 |
| 密码 | 增删改查、分组、收藏、搜索、复制/查看、密码生成器、密码历史（最近 5 条） |
| TOTP | 扫码添加、手动添加、otpauth URI、TOTP/HOTP/Steam、倒计时、一键复制、分组、收藏、搜索 |
| 组合 | 登录条目可附带 TOTP；TOTP Tab 汇总所有带 TOTP 的条目 |
| 图标 | 内置图标包、导入 Aegis `.zip` 图标包、自定义图片、按 issuer/域名自动推荐 |
| 自动填充 | 填充用户名/密码、保存/更新提示、解锁流程、设为默认的引导 |
| 备份 | 加密导出/导入、保存前自动轮转本地备份、可选 SAF 目录自动备份 |
| 导入 | Aegis（加密备份/明文导出）、Google Authenticator 迁移二维码、CSV（Bitwarden/Chrome） |
| 安全 | 禁止截屏、剪贴板定时清除、禁止系统备份、隐藏悬浮窗、无网络权限 |
| 其他 | 深色模式、动态取色、中文界面、开源许可页面 |

### P1（v1.1）

- 自动填充里直接复制 TOTP；填充后自动复制验证码（可选）
- 安全笔记、自定义字段
- 弱密码/重复密码离线报告（本地计算，不联网）
- 更多导入器（Bitwarden JSON、1Password CSV 等）、导出 CSV/HTML
- 分组拖拽排序、条目自定义排序
- 英文界面
- 备份提醒、备份完整性校验

### P2（以后）

- Passkey（Android 14+ Credential Manager 的 `CredentialProviderService`）
- 可选的桌面端/浏览器扩展（需要重新考虑"零网络"定位）
- 多用户/共享（与本地定位冲突，谨慎）

### 明确不做

云同步、账号体系、密码共享、在线泄露检测、广告、统计、崩溃上报、无障碍服务自动填充、iOS。

---

## 5. 信息架构与关键流程

### 5.1 导航

```
底部导航
├── 密码
│   ├── 列表（收藏 / 全部分组 / 搜索）
│   ├── 详情
│   └── 编辑
├── 验证器
│   ├── 列表（收藏 / 分组 / 搜索）
│   ├── 详情
│   └── 添加（扫码 / 手动 / 粘贴 URI）
└── 设置
    ├── 安全（自动锁定、生物识别、截屏、剪贴板）
    ├── 自动填充（状态、设为默认、使用说明）
    ├── 图标包（内置、已导入、导入 ZIP）
    ├── 备份与恢复
    ├── 导入
    └── 关于 / 开源许可
```

顶层搜索可跨"密码 + 验证器"，结果按类型分组。

### 5.2 首次启动

```
欢迎页
  → 设置主密码（强度提示 + 确认 + 警告"忘记只能靠恢复码"）
  → 生成恢复码（20 字节，Base32 分组显示；要求用户抄写/保存后勾选确认）
  → 是否开启生物识别
  → 是否从 Aegis/Google Authenticator 导入
  → 主页
```

### 5.3 自动填充

```
用户在登录框聚焦
  → 系统 Autofill 建议条出现"双钥"
  → 点击
  → 已解锁：直接列出匹配条目 → 选择 → 填充
  → 未解锁：透明解锁页（生物识别/主密码）→ 列出匹配条目 → 填充
  → 登录成功后系统提示"保存到双钥？" → 确认/修改 → 保存
```

### 5.4 添加 TOTP

```
验证器 Tab → + → 扫码
  → CameraX 预览 + ZXing 识别
  → 解析 otpauth:// → 预览（服务名/账号/图标建议）
  → 保存
手动添加：服务名、账号、密钥（Base32）、算法、位数、周期
```

---

## 6. 数据模型

存储的是**加密前的 JSON**，整个 JSON 压缩后加密；下面是明文结构（仅存在于内存和加密容器内）。

```json
{
  "schema": 1,
  "vaultId": "uuid",
  "createdAt": "2026-10-31T12:00:00Z",
  "items": [
    {
      "id": "uuid",
      "kind": "login",
      "title": "GitHub",
      "issuer": "GitHub",
      "username": "me@example.com",
      "password": "....",
      "urls": ["https://github.com", "androidapp://com.github.android"],
      "notes": "",
      "totp": {
        "type": "totp",
        "secret": "BASE32...",
        "algorithm": "SHA1",
        "digits": 6,
        "period": 30,
        "counter": null
      },
      "icon": {
        "data": "base64...",
        "mime": "image/webp",
        "source": "pack:c553f06f/github"
      },
      "groupIds": ["uuid"],
      "favorite": false,
      "createdAt": "...",
      "updatedAt": "...",
      "passwordHistory": [
        { "password": "....", "changedAt": "..." }
      ]
    },
    {
      "id": "uuid",
      "kind": "totp",
      "title": "Google",
      "issuer": "Google",
      "username": "me@gmail.com",
      "totp": { "type": "totp", "secret": "BASE32...", "algorithm": "SHA1", "digits": 6, "period": 30 },
      "icon": null,
      "groupIds": [],
      "favorite": true
    }
  ],
  "groups": [
    { "id": "uuid", "name": "工作", "order": 0 }
  ]
}
```

约束：

- `kind`：`login` | `totp` | `note`（note 为 P1 预留）。
- 登录条目 `totp` 可为 `null`；TOTP 条目 `password` 为空。
- 图标统一存**缩小后的字节**（≤192×192，WebP/PNG，≤20KB），保证备份自包含；`source` 只用于显示"来自哪个图标包"。
- `urls` 同时承担网页域名与 Android 包名（`androidapp://`）匹配。
- 所有时间用 UTC ISO-8601；`schema` 用于迁移。
- 未知字段反序列化时忽略，保证向前兼容。

---

## 7. 加密设计

### 7.1 威胁模型

| 防 | 不防 |
|---|---|
| 手机丢失、文件被拷走 | 已 root / 越狱、系统被植入 |
| 云盘/备份泄露（文件是密文） | 键盘记录器、恶意无障碍服务 |
| 数据库被其他 App 读取（应用私有目录 + 加密） | 被胁迫交出主密码 |
| 剪贴板、截屏、最近任务泄露 | 屏幕录制、肩窥（只能缓解） |
| 暴力破解（Argon2id 提高成本） | 弱主密码被字典攻击（只能靠强度提示） |
| 备份文件被篡改（AEAD 校验） | 供应链攻击（依赖库被投毒） |

一句话：**它保护"文件离开设备"的场景，不保护"设备已经被控制"的场景。**

### 7.2 密钥层级与槽位

```
主密码 ──Argon2id(salt, m, t, p)──► Password Key ──┐
                                                    ├── AEAD 解包 ──► Vault Key (32B)
恢复码 ──HKDF/Argon2id──────────────► Recovery Key ─┤                      │
                                                    │                      ├── AEAD 加密整个 vault JSON
Keystore 密钥（生物识别）────────────► Bio Key ─────┘                      └── 不落盘，只在内存
```

- **Vault Key**：随机 32 字节，创建时生成，是唯一真正加密数据的密钥。
- **槽位（slot）**：每个槽位用自己的密钥把 Vault Key 包起来。支持多个槽位 = 多种解锁方式，且**改主密码只需重写密码槽，不用重加密整个库**。
- 槽位类型：
  - `password`：Argon2id(主密码) → 包 Vault Key。
  - `biometric`：Android Keystore 中 `setUserAuthenticationRequired(true)` 的 AES 密钥 → 包 Vault Key；生物识别录入变化时密钥失效，回退主密码。
  - `recovery`：恢复码经 Argon2id/HKDF → 包 Vault Key。
- 槽位各自带 salt、KDF 参数、nonce，独立 AEAD，互不影响。

### 7.3 算法与参数

| 用途 | 选择 | 参数 |
|---|---|---|
| 口令 KDF | Argon2id（libsodium `crypto_pwhash`） | 默认 m=64MiB, t=3, p=4；创建时校准到 0.6–1.2s，下限 m=32MiB, t=3, p=2；参数写入头部 |
| 对称加密 | XChaCha20-Poly1305（libsodium） | 24 字节随机 nonce，每次加密新生成 |
| 恢复码 | 20 字节随机 → Base32 | 160 bit，32 字符，分 8 组显示 |
| 随机源 | `SecureRandom` / libsodium | 不用 `Random`、不用时间戳 |
| 哈希 | SHA-256（图标寻址、校验） | 标准库 |
| 压缩 | gzip | 加密前压缩，降低文件体积 |

备选（如果不想引入 native 库）：`org.signal:argon2` + Android `AES-256-GCM`（12 字节 nonce，单文件场景安全）。代价是解锁慢 2–3 倍，且要自己管 nonce。**默认仍推荐 libsodium。**

### 7.4 文件格式

```
┌────────────┬─────────┬──────────────┬─────────────────────────┐
│ magic 4B   │ ver 1B  │ headerLen 4B │ header JSON (UTF-8)     │
│ "TKV1"     │ 0x01    │ big-endian   │ 明文，含 KDF 参数/槽位   │
├────────────┴─────────┴──────────────┴─────────────────────────┤
│ ciphertext = XChaCha20-Poly1305(VaultKey, nonce, gzip(json))  │
│ 末尾 16B 为 Poly1305 tag                                       │
└───────────────────────────────────────────────────────────────┘
```

Header 示例：

```json
{
  "vaultId": "uuid",
  "createdAt": "...",
  "kdf": { "algo": "argon2id", "m": 65536, "t": 3, "p": 4 },
  "cipher": { "algo": "xchacha20poly1305", "nonce": "base64" },
  "compression": "gzip",
  "slots": [
    {
      "id": "uuid",
      "type": "password",
      "salt": "base64",
      "kdf": { "algo": "argon2id", "m": 65536, "t": 3, "p": 4 },
      "nonce": "base64",
      "wrappedKey": "base64"
    },
    {
      "id": "uuid",
      "type": "biometric",
      "alias": "twinkey.bio.v1",
      "nonce": "base64",
      "wrappedKey": "base64"
    },
    {
      "id": "uuid",
      "type": "recovery",
      "salt": "base64",
      "kdf": { "algo": "argon2id", "m": 65536, "t": 3, "p": 4 },
      "nonce": "base64",
      "wrappedKey": "base64"
    }
  ]
}
```

- **AAD**：payload 绑定 `magic + version + vaultId`；每个槽位绑定 `slotId + slotType`，防止槽位被替换/拼接。
- Header 明文是必要的（要先知道 KDF 参数才能解密），但其中只有"被包裹的 Vault Key"，没有可直接使用的密钥。
- 文件扩展名暂定 `.tkv`；备份文件名 `twinkey-YYYYMMDD-HHmmss.tkv`。

### 7.5 生命周期

| 操作 | 做法 |
|---|---|
| 创建 | 随机 Vault Key → 建密码槽 + 恢复码槽 → 写文件 |
| 解锁 | 读 header → 按槽位派生 key → 解包 Vault Key → 解密 payload → 内存模型 |
| 修改主密码 | 验证旧密码 → 新 salt/新槽替换密码槽 → 其他槽保留 → 原子写 |
| 开启/关闭生物识别 | 增删 biometric 槽；Keystore 密钥删除 |
| 用恢复码 | 输入恢复码 → 解包 Vault Key → 强制设置新主密码 |
| 锁定 | 清零 Vault Key、清空内存模型、清剪贴板 |
| 导出 | 复制当前文件（或重新序列化）到 SAF；导出时可选择"用当前密码"或"新备份密码" |
| 自动备份 | 保存成功后，把上一版复制到 `backup/`，保留最近 7 份；可选同时写 SAF 目录 |

### 7.6 明确禁止

- ❌ 自己实现 Argon2/AES/ChaCha；只用 libsodium / 标准库。
- ❌ 复用 nonce；每次加密必须新随机 24 字节。
- ❌ 用主密码的 SHA-256 直接当密钥。
- ❌ 明文写临时文件、日志、崩溃堆栈、剪贴板历史。
- ❌ 用 `String` 保存密钥/密码；用 `ByteArray`/`CharArray`，用完清零。
- ❌ 把 Vault Key 写进 SharedPreferences/DataStore。
- ❌ 在 `onSaveInstanceState` 里放密码。

---

## 8. 自动填充（Android）

### 8.1 组件

| 组件 | 职责 |
|---|---|
| `TwinKeyAutofillService` | 解析 `AssistStructure`、匹配条目、构造 `Dataset`、处理保存 |
| `AutofillUnlockActivity` | 透明主题，生物识别/主密码解锁，返回后继续填充 |
| `SaveRequestActivity` | 保存/更新确认，预填用户名密码 |
| `DomainMatcher` | 域名/包名归一化与匹配 |
| `AutofillOnboarding` | 检测是否默认、跳转系统设置、OEM 差异说明 |

### 8.2 匹配规则

1. 取 `FillContext.webDomain`（浏览器）或 `packageName`（App）。
2. 条目 `urls` 归一化：去 scheme、`www.`、路径、端口，转小写。
3. 优先级：完全相等 > 子域（`login.example.com` 匹配 `example.com`）> 包名完全相等 > 标题模糊（只在手动搜索里）。
4. 匹配不到时，提供一个"搜索双钥"的数据集，打开选择页。
5. 填充时在 UI 上显示来源（App 名/域名），防止钓鱼页面骗填充。

### 8.3 解锁链路

- 未解锁时，返回带 `setAuthentication()` 的 `FillResponse`，点击后启动透明解锁页。
- 解锁成功后，用短时 token（内存，30 秒）完成本次填充；**不把 Vault Key 交给 Autofill 进程之外的任何组件**。
- 这条链路在原生 Android / MIUI / ColorOS / One UI 上行为不完全一致，**M4 的第一件事是做 3 台真机技术验证**，再决定实现细节。

### 8.4 保存

- 用 `SaveInfo` 声明用户名/密码字段；登录成功后系统弹"保存到双钥"。
- 保存页允许改标题、选分组、配图标；识别为"已有条目改密码"时提示更新而非新建。
- 保存前做一次内存中的重复检测（同域名 + 同用户名）。

### 8.5 安全

- 锁定时数据集标题只显示"双钥（已锁定）"，不泄露账号。
- 解锁页 `FLAG_SECURE` + `setHideOverlayWindows(true)`（API 31+）。
- 不实现无障碍服务；不读取屏幕内容；不做"自动点击登录"。
- 填充前校验目标包名/域名与条目匹配，绝不"盲填"。
- 保存时过滤掉 OTP 字段，避免把验证码当密码存。

---

## 9. TOTP 验证器

### 9.1 支持范围

| 类型 | 支持 |
|---|---|
| TOTP | SHA1/SHA256/SHA512，6/8 位，周期 30/60（可自定义 1–300） |
| HOTP | 计数器递增并持久化 |
| Steam | 5 位自定义字母表，30 秒 |
| URI | `otpauth://totp|hotp|steam/...`、`otpauth-migration://offline?data=...` |
| 导入 | Google Authenticator 迁移二维码（多张分批合并）、Aegis 明文/加密备份 |

### 9.2 生成与解析

- Base32 解码容忍空格、短横线、小写、缺省 padding。
- HMAC 后动态截断，`code = (binary & 0x7fffffff) % 10^digits`，左侧补零。
- Steam：取 31 位后按 5 次取模映射到 `23456789BCDFGHJKMNPQRTVWXY`。
- 时间用 `System.currentTimeMillis() / 1000`，不联网校时；设备时间明显异常时提示。
- 用 RFC 6238 附录 B 的测试向量做单元测试。

### 9.3 UI

- 列表：图标、服务名、账号、大号等宽验证码、倒计时环/条；点击复制并震动反馈。
- 只对可见条目每秒重算，避免整表刷新。
- 支持收藏置顶、分组筛选、搜索（服务名/账号）。
- 详情页：大号验证码、进度、复制、编辑、删除、移动分组。
- 可选"隐藏验证码直到点击"（防肩窥），默认关闭。
- 锁屏/最近任务中不显示验证码（`FLAG_SECURE`）。

### 9.4 安全

- TOTP secret 与密码同等对待：只在加密容器内，绝不明文落盘。
- 二维码扫描结果不写日志；剪贴板中的 secret 60 秒清除。
- 与密码同库的取舍：方便，但设备被控制时两个因素一起丢。文档和首次启动提示里要写清楚；P1 可加"查看验证器需二次验证"。

---

## 10. 图标系统

### 10.1 内置图标包

- 打包 200–300 个常用服务图标（来源：Simple Icons，CC0；品牌 logo 仍受商标约束，公开分发需注明）。
- 资源放 `assets/iconpacks/builtin/`，格式与 Aegis 一致，启动时索引。
- 风格：单色图形 + 按域名哈希生成的背景色，统一、清爽、不挑主题。

### 10.2 兼容 Aegis 图标包

Aegis 格式（见 `Aegis/docs/iconpacks.md`）：

```json
{
  "uuid": "c553f06f-...",
  "name": "Alex' Icon Pack",
  "version": 1,
  "icons": [
    { "name": "Google", "filename": "services/Google.png", "category": "Services", "issuer": ["google"] }
  ]
}
```

- `.zip` + 根目录 `pack.json`；支持 SVG/PNG/JPEG。
- 导入：SAF 选文件 → 解析 → 校验（UUID、版本、路径穿越、zip bomb、单包 ≤20MB/≤2000 图标）→ 解压到 `files/icons/{uuid}/{version}`。
- 管理：列出已装包、预览、删除、升级（同 UUID 新版本替换旧版本）。
- 选中图标后**复制缩小后的字节进 vault**，保证换机/删包后图标还在；`source` 记录来源。

### 10.3 自定义图标

- 相册选图 → 居中裁切 → 缩到 192×192 → WebP 80% → 存进条目。
- 也支持"用首字母 + 颜色"作为兜底。

### 10.4 自动匹配

- 按 `issuer` / 域名 / 标题做不区分大小写的包含匹配；命中多个时按"精确 > 前缀 > 包含"排序。
- 新建条目时展示 3–6 个建议图标，一键选用。

---

## 11. 安全与隐私

| 项 | 方案 |
|---|---|
| 网络 | Manifest **不含** `INTERNET` / `ACCESS_NETWORK_STATE`；无任何 SDK 上报 |
| 系统备份 | `android:allowBackup="false"` + `dataExtractionRules` 排除全部 |
| 截屏/最近任务 | 默认 `FLAG_SECURE`；可在设置关闭（不推荐） |
| 剪贴板 | 复制 60 秒后自动清除；Android 13+ 标记 `EXTRA_IS_SENSITIVE`；锁定/退出时立即清 |
| 悬浮窗/点击劫持 | 解锁页、详情页 `setHideOverlayWindows(true)`；敏感按钮 `filterTouchesWhenObscured` |
| 生物识别 | `BiometricPrompt` + `CryptoObject`；仅 BIOMETRIC_STRONG；失败回退主密码 |
| 自动锁定 | 退后台 1 分钟 / 熄屏立即 / 可配置；进程被杀即锁定 |
| 内存 | 密钥/密码用 `ByteArray`，用后 `fill(0)`；不在 ViewModel 长期持有明文密码 |
| 日志 | Release 关闭所有日志；禁止打印条目内容；异常只记类型 |
| 组件导出 | 仅 AutofillService 导出（受 `BIND_AUTOFILL_SERVICE` 保护）；其余 `exported=false` |
| 备份 | 加密备份 + 导入时 AEAD 校验；本地保留 7 份轮转 |
| 恢复 | 恢复码 160-bit；创建时强制确认已保存；可重新生成（需解锁） |

**无网络权限的副作用**：不能在线检查更新、不能崩溃上报、不能下载图标包。更新靠应用商店/GitHub，图标包靠本地导入——这些都是可接受的取舍。

---

## 12. 技术栈与工程结构

### 12.1 选型

| 层 | 选择 | 理由 |
|---|---|---|
| 语言 | Kotlin 2.x | Android 事实标准 |
| UI | Jetpack Compose + Material 3 | 开发快、动态取色、易做统一视觉 |
| 导航 | Navigation Compose（单 Activity） | 简单，转场可控 |
| 异步 | Coroutines + Flow/StateFlow | 官方推荐 |
| 序列化 | kotlinx.serialization（JSON） | 无反射、可测试、将来可迁 KMP |
| 加密 | libsodium（Lazysodium AAR） | Argon2id + XChaCha20 + 清零工具，一次到位 |
| 存储 | 单文件 + `AtomicFile` | 备份/迁移简单，Aegis 已验证 |
| 偏好 | DataStore | 只存非敏感设置 |
| DI | 手动 `AppContainer` | 小项目，省掉 Hilt 的构建成本 |
| 相机/扫码 | CameraX + ZXing core | 不依赖 Google Play Services，离线可用 |
| 图标 | Coil 3 + coil-svg | Compose 友好，SVG/位图统一 |
| 生物识别 | androidx.biometric | 标准方案 |
| 密码强度 | zxcvbn（P1） | 比"长度+字符集"靠谱 |
| 测试 | JUnit4 + Robolectric + Compose UI Test | 覆盖核心逻辑与关键界面 |
| 构建 | Gradle KTS + Version Catalog + R8 | 标准 |

### 12.2 模块

```
:app        UI、Activity、AutofillService、DI、导航
:core       纯 Kotlin：模型、加密、容器读写、OTP、匹配、导入器接口
            （不依赖 Android，可直接 JVM 单测，将来可迁 KMP）
```

`core` 里通过接口隔离平台能力：

```kotlin
interface KeyStore { fun wrap(alias: String, key: ByteArray): ByteArray; fun unwrap(alias: String, data: ByteArray): ByteArray }
interface Clock { fun nowSeconds(): Long }
```

### 12.3 目录草案

```
com.twinkey.app
├── core/
│   ├── crypto/        Argon2, Aead, KeySlot, VaultKey
│   ├── vault/         VaultFile, VaultRepository, VaultCodec
│   ├── otp/           Totp, Hotp, Steam, OtpUri, Base32
│   ├── model/         Item, Group, IconRef, VaultData
│   └── importer/      AegisImporter, GoogleAuthImporter, CsvImporter
├── data/              FileVaultStore, BackupManager, SettingsStore
├── ui/                screens, components, theme
├── autofill/          service, matcher, unlock activity, save activity
├── icons/             IconPackManager, IconLoader, BuiltinPack
└── App.kt
```

### 12.4 关键依赖（不含版本号）

`androidx.compose.*`、`androidx.navigation:navigation-compose`、`androidx.lifecycle:lifecycle-viewmodel-compose`、`androidx.datastore:datastore-preferences`、`androidx.biometric:biometric`、`androidx.camera:camera-*`、`com.google.zxing:core`、`io.coil-kt.coil3:coil-compose`/`coil-svg`、`org.jetbrains.kotlinx:kotlinx-serialization-json`、`com.goterl:lazysodium-android`（或 `org.signal:argon2`）、`junit`/`robolectric`。

---

## 13. 里程碑

| 阶段 | 内容 | 全职 | 业余 |
|---|---|---|---|
| M0 设计 | 本方案定稿、线框、容器格式、加密测试向量、工程骨架 | 1 周 | 2 周 |
| M1 保险库 | 创建/解锁/锁定/改密/恢复码/生物识别/备份导出、单测 | 2–3 周 | 4–6 周 |
| M2 密码 + TOTP | 条目 CRUD、列表/搜索/分组、生成器、扫码、验证码列表 | 2–3 周 | 4–6 周 |
| M3 图标 | 内置包、Aegis 包导入、自定义图标、自动匹配 | 1 周 | 2 周 |
| M4 自动填充 | Service、解锁链路、保存、默认引导、3 台真机验证 | 2–3 周 | 4–6 周 |
| M5 打磨 | 导入器、安全加固、无障碍、性能、Beta、发布 | 2 周 | 3–4 周 |
| 合计 | | **10–14 周** | **5–7 个月** |

> 自动填充和 OEM 兼容是最不可控的部分，排期要留缓冲。

---

## 14. 验收标准

- **加密**：RFC 6238 向量通过；错误密码/篡改文件给出明确错误且不崩溃；全盘搜索不到明文密码（测试断言）。
- **解锁**：中端机主密码解锁 ≤1.5s；生物识别 ≤0.5s；1000 条搜索 ≤100ms。
- **自动填充**：Pixel / 小米 / OPPO（或华为）三台真机上，锁定与解锁状态都能填充；保存提示可用。
- **TOTP**：TOTP/HOTP/Steam 正确；Google 迁移二维码可导入；Aegis 备份可导入。
- **备份**：1000 条导出→清空→导入，数据完全一致；损坏文件被拒绝。
- **安全**：无 INTERNET 权限；`allowBackup=false`；截屏被阻止；剪贴板 60s 清除。
- **体积**：APK ≤20MB。
- **稳定性**：连续 7 天日常使用无崩溃、无数据丢失。

---

## 15. 风险与对策

| 风险 | 影响 | 对策 |
|---|---|---|
| 自动填充在 OEM 上行为不一致 | 核心功能不可用 | M4 先做 3 台真机技术验证；提供手动复制兜底 |
| 用户忘记主密码 | 数据永久丢失 | 强制恢复码 + 明确警告 + 备份提醒 |
| 文件损坏/误删 | 数据丢失 | AtomicFile + 7 份轮转 + SAF 备份 + 导入校验 |
| 自研加密出错 | 灾难性 | 只用 libsodium；测试向量；先写 spec；后期外部审计 |
| 图标包版权/商标 | 公开分发风险 | 只用 CC0 图标源；About 注明；接受下架风险 |
| 复制 Aegis 代码导致 GPL | 许可证约束 | 只参考思路，不复制代码；若要复制则整体 GPL-3.0 |
| 范围蔓延（passkey/同步） | 延期 | P0 清单冻结，新需求进 P1/P2 |

---

## 16. 需要你拍板的决策

| # | 决策 | 我的默认 | 备选 |
|---|---|---|---|
| 1 | TOTP 与密码同库、同解锁 | **同库**，登录条目可挂 TOTP，验证器单独 Tab | 分两个库/两次解锁（更安全但麻烦） |
| 2 | 恢复码 | **要**，创建时强制生成并确认 | 不要，忘密码即丢数据 |
| 3 | 自动备份 | **默认开**：保存前轮转 7 份；可选 SAF 目录每日备份 | 只手动导出 |
| 4 | 图标包 | **兼容 Aegis `.zip`** + 内置 200–300 个 Simple Icons | 只做内置 |
| 5 | 导入 | **Aegis + Google Authenticator** 为 P0，CSV 为 P1 | 只做 CSV |
| 6 | 开源许可证 | 不复制 Aegis 代码 → **Apache-2.0** | 复制/修改 Aegis 代码 → GPL-3.0 |
| 7 | minSdk | **26（Android 8.0）** | 28/29（更省适配） |
| 8 | 应用名 | **双钥 / TwinKey**（暂定） | 发布前再定 |

---

## 17. Aegis 参考点（读源码用）

| 主题 | 文件 |
|---|---|
| 容器格式（JSON + header + base64 密文） | `app/src/main/java/com/beemdevelopment/aegis/vault/VaultFile.java` |
| 原子写入、备份、导出 | `.../vault/VaultRepository.java`（`AtomicFile`、`aegis.json`） |
| AES-GCM / scrypt 参数 | `.../crypto/CryptoUtils.java`（N=2^15, r=8, p=1） |
| 槽位模型（密码/生物识别/备份密码） | `.../vault/slots/Slot.java`、`PasswordSlot.java`、`BiometricSlot.java` |
| Keystore 生物识别 | `.../crypto/KeyStoreHandle.java` |
| 图标包格式与导入 | `.../icons/IconPack.java`、`IconPackManager.java`、`docs/iconpacks.md` |
| otpauth / Google 迁移解析 | `.../otp/GoogleAuthInfo.java` |
| TOTP/HOTP/Steam 算法 | `.../crypto/otp/TOTP.java`、`HOTP.java`、`.../otp/SteamInfo.java` |

Aegis 是 GPL-3.0：**读可以，复制要谨慎**。图标包格式是公开规范，实现它不受 GPL 影响。

---

## 18. 参考

- Aegis：https://github.com/beemdevelopment/Aegis ｜ 图标包文档：`docs/iconpacks.md`
- Android Autofill：https://developer.android.com/identity/autofill/autofill-services
- Android Credential Manager（P2 passkey 用）：https://developer.android.com/identity/sign-in/credential-manager
- OWASP Password Storage Cheat Sheet：https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
- Argon2 RFC 9106：https://www.rfc-editor.org/rfc/rfc9106
- TOTP RFC 6238：https://www.rfc-editor.org/rfc/rfc6238
- libsodium：https://doc.libsodium.org


