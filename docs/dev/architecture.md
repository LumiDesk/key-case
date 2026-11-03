# 架构导览

执行规则以 [AGENTS.md](../../AGENTS.md) 为准；本文件只做源码导航。

KeyCase 只交付 Android，权威数据是应用私有目录里的单个加密容器 `vault.kcv`。
`main.dart` 创建 `KeyCaseController` 并等待 `bootstrap()`，随后把
`KeyCaseScope` 注入组件树；页面从 Controller 读状态、调方法，不接触文件与 Keystore。

| 领域 | 源码 |
|---|---|
| 容器格式与编解码 | `lib/app/vault/vault_container.dart`、`vault_migrations.dart` |
| 文件仓库与会话 | `lib/app/vault/vault_repository.dart`（原子写、写互斥、isolate KDF） |
| 备份 | `lib/app/vault/backup_service.dart`（快照轮转、SAF 导出/导入） |
| 查询与排序 | `lib/app/vault/vault_query.dart` |
| 加密原语 | `lib/app/crypto/`（Argon2id、AES-GCM、Base32、安全随机） |
| 令牌计算 | `lib/app/otp/otp.dart`、`otp_clock.dart`（全应用唯一 ticker） |
| 第三方导入 | `lib/app/import/`（otpauth、Aegis、Google 迁移、合并去重） |
| 模型 | `lib/app/models/`，`models.dart` 是稳定 barrel |
| 状态 | `keycase_controller.dart` + `keycase_controller_ops.dart`（extension）、`keycase_state.dart`、`keycase_scope.dart` |
| 偏好 | `lib/app/data/preferences_store.dart`（SharedPreferences 单键 JSON） |
| 安全审计 | `lib/app/security/security_audit.dart` |
| 原生能力 | `lib/app/platform/native_bridge.dart` ↔ `android/.../MainActivity.kt` + `VaultKeyStore.kt`（FLAG_SECURE、Keystore、SAF 目录与导出文档） |
| 生物识别 | `lib/app/platform/biometric_auth.dart`（local_auth） |
| 图标 | `lib/app/icons/`（pack.json 索引、SVG 文本缓存、品牌匹配） |
| 更新检查 | `lib/app/update/update_checker.dart` |
| 页面 | `lib/pages/`；共用弹层入口在 `pages/sheets.dart` |
| 设计令牌 | `lib/app/app_theme.dart` |
| 轻反馈 | `lib/app/feedback.dart` |
| 日志 | `lib/app/logging/app_logger.dart` |
| 工具函数 | `lib/app/util/`（日期、网址、密码生成） |

## 数据流

1. 启动：`bootstrap()` 读偏好 → 判断 `vault.kcv` 是否存在 → `missing` / `locked`。
2. 解锁：`VaultRepository.unlock` 在 isolate 里跑 Argon2id + AES-GCM，返回 `UnlockedVault`
   （header + vault key + `VaultData`）。
3. 修改：页面调用 Controller 的操作 → 构造新的 `VaultData` → `VaultRepository.save`
   （写队列串行、临时文件 + rename）→ 更新内存状态 → 可选自动快照。
4. 锁定：清零 vault key、清空内存里的保险库数据，并用全屏解锁路由盖住当前页面；
   解锁后回到锁定前的页面。后台/超时由 `handleAppPaused` / `handleAppResumed` 驱动。

## 分层边界

- **UI** 只依赖 `KeyCaseController` 与 `KeyCaseScope`，不 import 文件、Keystore 或容器实现。
- **Controller** 持有 `KeyCaseState` 与 `AppPreferences`，把 `KeyCaseError` / `KeyCaseNotice`
  交给 `messages.dart` 翻译；不直接拼用户文案。
- **Repository** 独占解锁会话、vault key 与写队列；所有落盘都经过它。
- **Container** 只负责 `KCV1` 编解码与密码学参数，不感知页面与偏好。
