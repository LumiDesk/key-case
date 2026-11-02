import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

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
  final l10n = AppLocalizations.of(context);
  final difference = DateTime.now().difference(time.toLocal());
  if (difference.inMinutes < 1) return l10n.timeJustNow;
  if (difference.inHours < 1) return l10n.timeMinutesAgo(difference.inMinutes);
  if (difference.inDays < 1) return l10n.timeHoursAgo(difference.inHours);
  if (difference.inDays < 7) return l10n.timeDaysAgo(difference.inDays);
  return formatDate(context, time);
}
