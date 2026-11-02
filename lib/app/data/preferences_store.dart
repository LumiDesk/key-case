import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// 设备偏好存储：一个 JSON 字符串，键固定。
///
/// 只放 UI 偏好；保险库内容、vault key、备份口令都不在这里。
class PreferencesStore {
  static const String storageKey = 'keycase.preferences.v1';

  Future<AppPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const AppPreferences();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return AppPreferences.fromJson(decoded.cast<String, Object?>());
      }
    } on FormatException {
      // 损坏的偏好不应该阻止解锁，回落到默认值。
    }
    return const AppPreferences();
  }

  Future<void> save(AppPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(preferences.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}
