import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 用户可见的日期格式化：跟随应用语言，不手拼。
String formatDateTime(BuildContext context, DateTime time) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.yMMMd(locale).add_Hm().format(time.toLocal());
}

/// 只要日期。
String formatDate(BuildContext context, DateTime time) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.yMMMd(locale).format(time.toLocal());
}

/// 相对时间：刚刚 / N 分钟前 / N 天前，超过一周回落到日期。
String formatRelative(BuildContext context, DateTime time) {
  final difference = DateTime.now().difference(time.toLocal());
  if (difference.inMinutes < 1) return '刚刚';
  if (difference.inHours < 1) return '${difference.inMinutes} 分钟前';
  if (difference.inDays < 1) return '${difference.inHours} 小时前';
  if (difference.inDays < 7) return '${difference.inDays} 天前';
  return formatDate(context, time);
}
