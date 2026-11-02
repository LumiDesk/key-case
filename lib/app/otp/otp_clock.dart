import 'dart:async';

import 'package:flutter/foundation.dart';

/// 全应用唯一的秒级时钟。
///
/// 令牌列表与详情共用同一个 ticker：每行各自起 Timer 会让几十行在后台持续调度，
/// 既费电又难对齐。行内只监听 [seconds]，验证码按时间片边界自然刷新。
class OtpClock {
  OtpClock() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _tick();
  }

  late final Timer _ticker;

  /// 当前 Unix 秒。同一秒内不会重复通知。
  final ValueNotifier<int> seconds = ValueNotifier<int>(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
  );

  /// 当前时间，供需要 Date 的调用方使用（每秒更新一次）。
  DateTime get now =>
      DateTime.fromMillisecondsSinceEpoch(seconds.value * 1000, isUtc: false);

  void _tick() {
    final next = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (next != seconds.value) {
      seconds.value = next;
    }
  }

  void dispose() {
    _ticker.cancel();
    seconds.dispose();
  }
}
