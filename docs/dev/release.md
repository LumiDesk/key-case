# 发版规范

发布是**用户可见的对外动作**：只有用户明确要求时才执行。本文件定义版本号、发布说明、
Release 标题与提升流程；唯一命令入口是 `dart run scripts/publish.dart`。

## 1. 版本号

- 语义：`patch` 修问题与打磨、`minor` 新增功能、`major` 不兼容变更。
- `versionCode` 每次发版 +1，由脚本维护；不得回退，不得复用已发布过的版本号。
- tag 格式固定 `vX.Y.Z`；**不删除、不移动、不重复使用**已推送的 tag。
- 发版命令只有一种写法：

  ```bash
  dart run scripts/publish.dart patch    # 或 minor / major
  ```

- 脚本会依次：改 `pubspec.yaml` 与 `lib/app/app_version.dart` → `dart format` →
  `flutter analyze` → `flutter test` → 提交 `chore: release vX.Y.Z` → 打 tag →
  推送 `main` 与 tag。`--dry-run` 只打印版本并做必填项检查。

## 2. 发版前必须齐的三份文件

| 文件 | 内容 | 检查方 |
|---|---|---|
| `CHANGELOG.md` | 新增 `## [X.Y.Z] - YYYY-MM-DD` 段，英文，分 Added / Changed / Fixed，只写用户可见变化 | `scripts/publish.dart` |
| `docs/release-notes/vX.Y.Z.md` | Release 正文，英文，模板见第 4 节 | `scripts/publish.dart` 与 `release.yml` |
| `README.md` | `Project status` 的 `Current release` 改为新版本 | 人工 |

前两份缺任意一份，脚本在改动版本号之前直接退出；`release.yml` 还会在构建前再查一次
发布说明，避免白跑一次签名构建。三份文件与代码改动放在同一个 `docs: prepare vX.Y.Z release`
提交里。

## 3. Release 标题

固定为 `KeyCase X.Y.Z`（**不带 `v`**）。tag 是 `vX.Y.Z`，标题由工作流从 tag 去掉前缀
自动生成，发布后不手改标题。

## 4. Release 正文

唯一来源是 `docs/release-notes/vX.Y.Z.md`，由 `release.yml` 用 `--notes-file` 读取。
正文用英文，与 README、CHANGELOG 一致。

### 模板

```markdown
## Highlights

- 一条用户能感知的变化；1–6 条，按重要性排序。
- 每条一行，说明「用户看到什么变了」，不写类名、文件名、内部重构。

## Upgrade note

仅当存在不兼容或需要用户先操作的事项时保留：容器或备份格式变化、必须先导出备份、
签名或包名变化。没有就整段删掉。

Install this build over X.Y.Z; the vault and backup format is unchanged.

SHA-256 is published next to the APK.
```

### 写作规则

- 只写用户可见的变化；内部重构、测试、依赖升级、文档整理不进发布说明。
- `Highlights` 最多 6 条；超过说明这次发版该拆成 minor 或多写 CHANGELOG 细节。
- 不写 PR 号、commit 号、贡献者名单，不加 emoji。
- 结尾两行固定保留：一句安装/兼容说明，一行 SHA-256 提示。
- 升级需要额外步骤时，`Upgrade note` 必须写清楚先做什么、再做什么。

### 示例

`v1.1.1` 的实际正文见 [v1.1.1.md](../release-notes/v1.1.1.md)。

## 5. 发布流程

1. 写齐第 2 节的三份文件，提交 `docs: prepare vX.Y.Z release` 并推送 `main`。
2. 运行 `dart run scripts/publish.dart patch`；脚本自检、提交、打 tag、推送。
3. `.github/workflows/release.yml` 构建签名 arm64 APK，创建**预发布**，标题与正文按
   第 3、4 节生成。
4. 在真机上按 [testing.md](testing.md) 的主链路验收；冷启动、解锁、收藏、备注、
   令牌、备份都要过一遍。
5. 验收通过后提升为 Latest：

   ```bash
   gh release edit vX.Y.Z --prerelease=false --latest
   ```

   需要微调文案时，先 `gh release edit vX.Y.Z --notes-file docs/release-notes/vX.Y.Z.md`
   （必要时加 `--title`），再提升；仓库里的发布说明文件同步修改并提交。
6. 验收不通过：不发 Latest，修复后用下一个 `patch` 版本重发。**不替换**已上传的 APK，
   也不重用旧 tag。

## 6. 检查清单

- [ ] 用户明确授权发版
- [ ] 工作区干净，`main` 与 `origin/main` 同步
- [ ] `dart format`、`flutter analyze`、`flutter test` 全绿
- [ ] `CHANGELOG.md`、`docs/release-notes/vX.Y.Z.md`、`README.md` 三处版本一致
- [ ] 发布说明是英文、1–6 条 Highlights、无内部细节
- [ ] 截图与文档反映当前实现
- [ ] 真机验收通过后才提升 Latest
