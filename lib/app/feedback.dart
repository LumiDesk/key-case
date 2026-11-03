import 'dart:async';

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 轻反馈：复制成功、已保存这类一闪而过的提示。
///
/// 全应用只有这一个轻反馈入口：破坏性确认、表单校验和阻塞进度不在这里，
/// 走对话框或页内状态。
class KcFeedbackController extends ChangeNotifier {
  String? _message;
  Timer? _timer;

  String? get message => _message;

  void show(String text) {
    _message = text;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1600), () {
      _message = null;
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class KcFeedbackScope extends InheritedNotifier<KcFeedbackController> {
  const KcFeedbackScope({
    super.key,
    required KcFeedbackController controller,
    required super.child,
  }) : super(notifier: controller);

  /// 取根级反馈控制器；没有挂宿主时返回 null（纯 widget 测试可跳过）。
  static KcFeedbackController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<KcFeedbackScope>()
        ?.notifier;
  }

  static KcFeedbackController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'KcFeedbackScope 未挂载');
    return controller!;
  }
}

/// 把轻反馈画在内容上层，位置固定在底部导航之上。
class KcFeedbackHost extends StatelessWidget {
  const KcFeedbackHost({
    super.key,
    required this.controller,
    required this.child,
  });

  final KcFeedbackController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KcFeedbackScope(
      controller: controller,
      child: Stack(
        children: <Widget>[
          child,
          Positioned(
            left: 0,
            right: 0,
            bottom: 96,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final message = controller.message;
                  final visible = message != null && message.isNotEmpty;
                  return AnimatedSlide(
                    offset: visible ? Offset.zero : const Offset(0, 0.4),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: AnimatedOpacity(
                      opacity: visible ? 1 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: Center(child: _FeedbackPill(text: message ?? '')),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackPill extends StatelessWidget {
  const _FeedbackPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? kcSurfaceRaisedDark : kcSurfaceLight;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.12) : kcLine;
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(kcRadiusXl),
        border: Border.all(color: borderColor),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
