# 技术取舍

只记录**当前有效**的决策与理由，不复述历史方案。

## 容器与加密

- **单文件容器 `KCV1`，不是 SQLite。** 密码库必须静态加密，SQLite 会把明文/页缓存写到
  WAL 与临时文件；单文件容器同时让原子替换、备份与跨设备导入变简单。
- **KDF 默认 Argon2id 64 MiB / 3 轮 / p=2。** 参数写在容器头里，解锁时按头里的参数计算；
  读取时校验 64 KiB–256 MiB、1–10 轮、p=1–8，超限直接拒绝，避免恶意备份拖垮内存。
- **AES-256-GCM，密文后附 16 字节 tag。** 正文是 gzip 压缩后的 JSON，`vaultId` 作为 AAD
  绑定；口令槽位用 slot id + 类型作为 AAD。payload 为 `schemaVersion 2`，条目只用互斥的
  `login` / `totp` 嵌套对象。
- **KDF 与解密在后台 isolate；正文加密在主 isolate。** `Isolate.run` 的闭包会连同所在方法
  上下文一起被发送，在写队列闭包里调用会报 unsendable；正文只有几十 KB，主 isolate 加密
  只要几毫秒。
- **改主密码：换新口令槽位，用同一 vault key 重新加密正文（新 nonce）。** vault key 不变，
  因此 Keystore 包裹的密钥继续有效。

## 生物识别

- **vault key 用 Android Keystore 的 AES-256-GCM 密钥包裹后存在 SharedPreferences**，
  解锁前先过系统 BiometricPrompt。没有使用 `setUserAuthenticationRequired`：它与
  BiometricPrompt 的有效期在部分机型上互相竞争，会出现“验证通过但解密失败”。Keystore
  密钥不可导出，但**不由 BiometricPrompt 在密码学层强制用户在场**；拿到应用 UID 的执行环境
  可以绕过应用层提示。
- 换库、恢复备份后 `vaultId` 不匹配会自动清除包裹密钥，避免拿旧 key 解新库；删除库/关闭
  生物识别会删除 Keystore 别名。
- 主密码始终是兜底路径；生物识别不可用或被系统清理时退回主密码。

## 数据与备份

- **备份只有一种形态**：同一容器的副本 `.kcbak`。自动快照写用户选定的 SAF 目录（其下的
  `KeyCase/` 子目录），保留最近 10 份；只在内容型修改后写，1 分钟内最多一次；轮转只处理
  `keycase-*.kcbak`。主动导出通过原生 `ACTION_CREATE_DOCUMENT` 选择目标 URI 后直接写入。
- **版本策略**：容器 `formatVersion` 保持 1，payload 当前 `schemaVersion 2`；升级前先读
  `schemaVersion`，比当前新的库提示升级应用，与当前 `schemaVersion` 不一致的库/备份拒绝读取。
  未来只追加迁移段，不回改历史段。
- **容器读入有边界**：头部 1 MiB、正文 64 MiB，gzip 解压有输出上限；导入文件上限 64 MB。
  Aegis 导入对 scrypt 参数设上限，避免恶意文件把内存打满。

## UI 与技术选型

- **状态管理用 `ChangeNotifier` + `InheritedNotifier`**，不引入 Provider / Riverpod / Bloc。
- **保险库写入串行化。** Controller 用一个操作队列串行所有写操作；Repository 用会话 epoch
  阻止锁定/换库后仍在途的保存复活会话。
- **安全默认值**：截图保护默认开；复制密码/验证码后 60 秒自动清除剪贴板（内容仍匹配才清）；
  自动锁定默认立即。
- **锁定用全屏解锁路由覆盖当前页面，不销毁导航栈。** 解锁后回到锁定前的页面和 Tab；
  vault key 与保险库数据仍立即清空，页面里未保存的编辑草稿作为界面状态留在锁屏下方。
- **锚点菜单用外部库 `anchored_menu`**，应用只把设计令牌桥接到 `AnchoredMenuThemeData`；
  不维护本地菜单实现。
- **图标包随 APK 打包，三套共 6800+ 个 SVG（约 16 MB）。** 目录声明不递归，因此
  `pubspec.yaml` 要分别列出每套包的目录、`SVG/` 子目录与许可证文件。
  - `simple`：KornaVue/aegis-simple-icons v269（Simple Icons，CC0），圆形品牌色徽章，
    自动匹配只认这套与 `dashboard` 的 issuer 表。
  - `dashboard`：homarr-labs/dashboard-icons（Apache-2.0），全彩服务 logo。只收每个品牌的
    主文件（去掉 `-dark`/`-light`/`-wordmark` 等变体），跳过 >25 KB 的巨型 SVG 与
    `<text>`/`<image>`/`<foreignObject>` 文件，并把 CSS 类规则摊平成元素属性
    ——`vector_graphics_compiler` 不解析样式表，不摊平会整片变黑。
  - `aegis`：aegis-icons（CC0），单色 2FA 徽章；只收与上面两套不重名的图标，
    避免选择器里出现两个同名徽章。
  - 全彩包里大量纯黑字形在深色卡片上不可见，渲染时统一垫 `kcIconPlate` 浅色底板。
- **品牌图标直接渲染 SVG**，不转成字体或位图：`flutter_svg` 按 SVG 文本缓存解析结果，
  列表滚动不会重复解析。
- **不引入图表库**：本应用没有统计图表需求。

## 网络与限制

- 唯一的网络行为是用户点击「检查更新」时请求 GitHub Release；没有后台轮询，也不上传数据。
- 自动快照需要用户先选一个 SAF 目录；没有目录时不会写任何文件。
- Release APK 只构建 `arm64`，体积约 40 MB。
- 主密码无法恢复；改密码或换设备前先导出加密备份。
