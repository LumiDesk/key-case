# 测试与验收

## 自动化测试

| 层级 | 覆盖内容 | 入口 |
|---|---|---|
| 纯函数 | OTP、Base32、otpauth、导入合并、安全审计、排序/搜索、网址、密码生成、日期、版本比较 | `test/*_test.dart` |
| 容器与仓库 | `KCV1` 创建/解锁/篡改、改密、备份替换、原子写、写队列、锁定与删除 | `test/vault_container_test.dart`、`test/vault_repository_test.dart` |
| 状态与操作 | Controller 启动、创建/解锁/锁定、自动锁定、条目增删改、回收站、HOTP、偏好、生物识别、备份、导入 | `test/controller_test.dart` |
| 页面与组件 | 解锁页自动指纹、验证码隐藏/揭开、速拨按钮、锚点菜单、搜索、详情、设置、编辑 | `test/*_page_test.dart`、`test/token_display_test.dart`、`test/menu_components_test.dart`、`test/app_shell_test.dart` |
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
- 关闭「显示验证码」：列表显示与位数一致的圆点，下一码不显示数字；点击验证码揭开并复制，点其他区域或 10 秒后恢复隐藏。
- 令牌页加号：展开「扫码添加 / 手动添加」，主按钮变叉；再次点击、点页面空白、切换底部导航都会收起。
- 设置页和编辑令牌高级设置：点行弹出锚点菜单，选项与当前值一致，小屏下菜单不越界。
- 搜索：点结果进入详情；返回后搜索词仍在。
- 图标选择器：搜索品牌、滚动到列表末尾、选择自定义图片。
- 语言切换后：回收站相对时间、指纹取消按钮、导入提示跟随语言。
