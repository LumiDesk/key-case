import 'package:flutter/foundation.dart';

/// 极简日志：发布包里用 `debugPrint` 会打到 logcat，但绝不能写入任何敏感值。
///
/// 规则：
/// - 只记事件与错误类型，不记主密码、vault key、TOTP secret、条目内容；
/// - 用户可见的错误由 Controller 的 `KeyCaseError` 表达，这里只做诊断。
class AppLogger {
  const AppLogger._();

  static void info(String message) => _write('I', message);

  static void warn(String message) => _write('W', message);

  static void error(String message, [Object? cause]) {
    _write('E', cause == null ? message : '$message: $cause');
  }

  static void _write(String level, String message) {
    if (kReleaseMode) {
      // 发布包不主动刷日志；真正排障走应用内的诊断页（后续版本）。
      return;
    }
    debugPrint('[$level] KeyCase $message');
  }
}
