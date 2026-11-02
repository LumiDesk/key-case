import 'package:flutter/widgets.dart';

import 'keycase_controller.dart';

/// 把 Controller 注入组件树。UI 只通过它读取状态，不直接访问 repository。
class KeyCaseScope extends InheritedNotifier<KeyCaseController> {
  const KeyCaseScope({
    super.key,
    required KeyCaseController controller,
    required super.child,
  }) : super(notifier: controller);

  static KeyCaseController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<KeyCaseScope>();
    assert(scope != null, 'KeyCaseScope 未挂载');
    return scope!.notifier!;
  }

  /// 只读取、不订阅（用于回调里拿 controller 调方法）。
  static KeyCaseController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<KeyCaseScope>();
    assert(scope != null, 'KeyCaseScope 未挂载');
    return scope!.notifier!;
  }
}
