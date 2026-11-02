# 技术取舍

只记录**当前有效**的决策与理由；被否决的选项只留一句结论。

## 容器与加密

- **单文件容器 `KCV1`，不是 SQLite。** 密码库必须静态加密，SQLite 会把明文/页缓存写到
  WAL 与临时文件；单文件容器同时让原子替换、备份与跨设备导入变简单。
- **KDF 默认 Argon2id 64 MiB / 3 轮 / p=2。** 本机实测（API 37 模拟器、AOT profile）约
  0.5 秒，快于 32 MiB/3 的近一倍内存成本几乎没有体感差异。参数写在容器头里，老库永远按
  头里的参数解锁，调默认值不影响已有数据。
- **AES-256-GCM，密文后附 16 字节 tag**，与 JCE 的 `AES/GCM/NoPadding` 表示一致。
- **KDF 与解密在后台 isolate；正文加密在主 isolate。** `Isolate.run` 的闭包会连同所在方法
  上下文一起被发送，在写队列闭包里调用会报 unsendable；正文只有几十 KB，主 isolate 加密
  只要几毫秒，不值得为此增加发送边界。
- **改主密码只换口令槽位**，vault key 与正文重新加密但不变 key，因此生物识别包裹的密钥
  继续有效。

## 生物识别

- **vault key 用 Android Keystore 的 AES-256-GCM 密钥包裹后存在 SharedPreferences**，
  解锁前先过系统指纹弹窗。没有使用 `setUserAuthenticationRequired`：它与 BiometricPrompt
  的有效期在部分机型上互相竞争，会出现“验证通过但解密失败”。当前模型与多数密码管理器
  一致：Keystore 密钥不可导出，攻击者需要应用 UID + 用户在场。
- 换库、恢复备份后 `vaultId` 不匹配会自动清除包裹密钥，避免拿旧 key 解新库。

## 数据与兼容

- **不兼容旧 Kotlin 版容器。** 旧版数据留在原应用私有目录，新版本不读也不删；需要迁移时
  用标准 `otpauth://` 二维码重新扫码即可。这样避免了为一次性迁移维护两套解析器。
- **备份只有一种形态**：同一容器的副本 `.kcbak`。自动快照写应用私有目录，保留最近 10 份；
  用户主动导出走系统文档选择器。
- **迁移策略**：`VaultData.schemaVersion` + `VaultMigrations` 的链式升级；升级前先读
  `schemaVersion`，不允许读取比当前实现更新的库（提示先升级应用）。

## UI 与技术选型

- **状态管理用 `ChangeNotifier` + `InheritedNotifier`**，与 Veri Fin 一致，不引入 Provider /
  Riverpod / Bloc。
- **锚点菜单用外部库 `anchored_menu`**，应用只把设计令牌桥接到 `AnchoredMenuThemeData`；
  不维护本地菜单实现。
- **图标包随 APK 打包**（Aegis Simple Icons，3467 个 SVG，约 5.3 MB）。目录声明不递归，
  因此 `pubspec.yaml` 必须同时列出 `pack.json` 与 `SVG/` 子目录。
- **品牌图标直接渲染 SVG**，不转成字体或位图：`flutter_svg` 按 SVG 文本缓存解析结果，
  列表滚动不会重复解析。
- **不引入图表库**：本应用没有统计图表需求。

## 已知限制

- 没有 Aegis / Google Authenticator 批量导入；令牌通过扫码或手动输入添加。
- 没有自定义图片图标；图标来自内置包 + 首字母头像。
- 没有自动更新检查，也没有任何网络权限。
- Flutter 会把 APK 体积带到约 20 MB 量级（旧 Kotlin 版约 6 MB），这是重写换来的开发效率与
  一致性的代价。
