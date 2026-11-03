# 测试与验收

## 自动化测试

| 层级 | 覆盖内容 | 入口 |
|---|---|---|
| 纯函数 | OTP、Base32、otpauth（含 Steam）、导入合并、安全审计、排序/搜索、网址、密码生成、日期、版本比较、KDF 边界 | `test/*_test.dart` |
| 模型 | v2 `login`/`totp` 互斥、往返、非法组合、TOTP 值域 | `test/models_test.dart`、`test/vault_migrations_test.dart` |
| 容器与仓库 | `KCV1` 创建/解锁/篡改、改密、备份替换、原子写、写队列、会话 epoch、锁定与删除、schemaVersion 校验 | `test/vault_container_test.dart`、`test/vault_repository_test.dart` |
| 状态与操作 | Controller 启动、创建/解锁/锁定、自动锁定、条目增删改、回收站、HOTP、偏好、生物识别、备份、导入、并发队列、锁定竞态 | `test/controller_test.dart` |
| 页面与组件 | 解锁页自动指纹、恢复入口、验证码隐藏/揭开、速拨按钮、锚点菜单、搜索、详情、设置、编辑、系统返回确认、扫码预填、锁定后回到原页面 | `test/*_page_test.dart`、`test/lock_navigation_test.dart`、`test/token_display_test.dart`、`test/menu_components_test.dart`、`test/app_shell_test.dart`、`test/app_shell_back_test.dart` |
| 布局 | 360dp + 2x 字号无溢出 | `test/layout_test.dart` |
| 组件策略 | 禁止底部单选弹层、禁止分段单选控件、禁止 `sheets.dart` 之外的裸弹层 | `test/component_policy_test.dart` |

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter test --coverage
```

`flutter test --coverage` 生成的 `coverage/lcov.info` 包含生成的中英文 l10n 文件；评估业务覆盖时先排除
`lib/l10n/app_localizations*.dart`。覆盖率用于发现未触达路径，不作为 CI 硬门槛。

## 模拟器验收

相机扫码、Android Keystore、系统生物识别、SAF 文档选择器、`FLAG_SECURE` 和外部浏览器无法靠 Dart
单元测试覆盖，必须在模拟器上逐项操作：

- 冷启动且已启用指纹：解锁页自动弹出系统指纹，正确指纹解锁；取消后停留解锁页，不循环弹。
- 手动锁定、自动锁定回前台：解锁页重新出现并自动弹一次；主密码仍可解锁。
- 锁定与恢复：在详情页或设置 Tab 锁定，解锁后回到原页面、原 Tab；锁定期间系统返回键不会关掉解锁页。
- 关闭「显示验证码」：列表显示与位数一致的圆点，下一码不显示数字；点击验证码揭开并复制，点其他区域或 10 秒后恢复隐藏。
- 令牌页加号：展开「扫码添加 / 手动添加」，主按钮变叉；再次点击、点页面空白、切换底部导航都会收起。
- 扫码添加：识别 otpauth 二维码后进入「新建令牌」页且服务名、账号、密钥已预填；直接返回不写入，点保存才出现在列表。
- 返回键：在登录、令牌、设置 Tab 按返回先回主页；在主页第一次返回显示「再次返回退出软件」底部提示，2 秒内第二次返回才退出；速拨展开时先收起速拨。
- 数据区「导出加密备份」：选择系统「新建文档」位置后文件可写入；取消选择不报错。设置页回收站副标题显示「共 N 条」或「暂无」。
- 关于区 GitHub 行：点击打开 `github.com/LumiDesk/key-case`。
- 设置页和编辑令牌高级设置：点行弹出锚点菜单，选项与当前值一致，小屏下菜单不越界。
- 搜索：点结果进入详情；返回后搜索词仍在。
- 图标选择器：搜索品牌、滚动到列表末尾、选择自定义图片。
- 语言切换后：回收站相对时间、指纹取消按钮、导入提示跟随语言。
- 恢复入口：解锁页「从加密备份恢复」可选文件、输入备份密码并替换；成功后指纹关闭、可重新开启；错误密码/损坏文件/版本不匹配的备份分别提示。
- Steam：扫描 `encoder=steam` 或被标记为 Steam 的 otpauth 二维码，进入编辑器后类型为 Steam、算法固定 SHA1、5 位、30 秒；保存后码为 5 位字母。
- 剪贴板：复制密码后 60 秒清空；复制别的内容后 60 秒不被清掉；设置里可关闭。
- 锁定竞态：保存瞬间按 Home/锁屏，回来必须要求解锁，且没有数据回写或会话复活。
- 尺寸：360dp + 2.0 字号下设置/首页/编辑/详情/回收站无溢出。
- release APK（R8）：安装后跑完整主链路与扫码/备份。
