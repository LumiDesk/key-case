import 'dart:convert';
import 'dart:io';

import '../logging/app_logger.dart';

/// 一次可用的更新。
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.releaseUrl,
    required this.notes,
  });

  final String version;
  final String releaseUrl;
  final String notes;
}

class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);

  final String message;

  @override
  String toString() => message;
}

const String _releasesApi =
    'https://api.github.com/repos/LumiDesk/key-case/releases/latest';

/// 手动检查更新（只在用户点按「检查更新」时联网）。
///
/// 请求的是仓库的 latest release；返回 null 表示已是最新。
/// 不发送任何设备信息，只带一个固定的 User-Agent（GitHub API 要求）。
Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(Uri.parse(_releasesApi));
    request.headers
      ..set(HttpHeaders.userAgentHeader, 'KeyCase')
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final response = await request.close();
    if (response.statusCode != 200) {
      throw UpdateCheckException('GitHub 返回 ${response.statusCode}');
    }
    final body = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const UpdateCheckException('无法解析 GitHub 响应');
    }

    final rawTag = decoded['tag_name'] as String? ?? '';
    final version = rawTag.startsWith('v') ? rawTag.substring(1) : rawTag;
    if (version.isEmpty) {
      throw const UpdateCheckException('Release 缺少版本号');
    }
    if (compareVersions(version, currentVersion) <= 0) {
      return null;
    }
    return UpdateInfo(
      version: version,
      releaseUrl: decoded['html_url'] as String? ?? '',
      notes: decoded['body'] as String? ?? '',
    );
  } on SocketException catch (error) {
    AppLogger.warn('update check network error: $error');
    throw const UpdateCheckException('网络不可用');
  } on FormatException catch (error) {
    AppLogger.warn('update check parse error: $error');
    throw const UpdateCheckException('无法解析 GitHub 响应');
  } finally {
    client.close(force: true);
  }
}

/// 语义化版本比较：返回 <0 表示 a 比 b 旧。
///
/// 只比较数字段，忽略预发布后缀：`1.2.0-beta` 视作 `1.2.0`。
int compareVersions(String a, String b) {
  List<int> parse(String value) {
    final core = value.split('-').first.split('+').first;
    return core
        .split('.')
        .map(
          (part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        )
        .toList();
  }

  final left = parse(a);
  final right = parse(b);
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    if (l != r) return l.compareTo(r);
  }
  return 0;
}
