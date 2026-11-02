import '../models/models.dart';

/// 安全中心的问题类型。
enum SecurityIssueKind { weak, reused, stale }

class SecurityIssue {
  const SecurityIssue({required this.kind, required this.items});

  final SecurityIssueKind kind;

  /// 同一问题涉及的条目。弱口令与过期通常一条，复用是一组。
  final List<VaultItem> items;
}

const int weakPasswordLength = 10;
const Duration stalePasswordAge = Duration(days: 365);

/// 扫描登录项，产出可解释的问题列表（令牌条目没有口令，不参与）。
///
/// 判定刻意保守：
/// - 弱：短于 [weakPasswordLength]、纯数字/纯字母、或整串只有一种字符；
/// - 复用：非空口令在两个及以上条目出现；
/// - 过期：`updatedAt` 早于一年前；没有改过密码的时间戳，只能用它近似。
List<SecurityIssue> auditVault(List<VaultItem> items, {DateTime? now}) {
  final active = items
      .where((item) => !item.isDeleted && item.kind == ItemKind.login)
      .toList(growable: false);
  final issues = <SecurityIssue>[];
  final reference = now ?? DateTime.now();

  for (final item in active) {
    if (isWeakPassword(item.password)) {
      issues.add(
        SecurityIssue(kind: SecurityIssueKind.weak, items: <VaultItem>[item]),
      );
    }
    if (reference.difference(item.updatedAt.toLocal()) > stalePasswordAge) {
      issues.add(
        SecurityIssue(kind: SecurityIssueKind.stale, items: <VaultItem>[item]),
      );
    }
  }

  final byPassword = <String, List<VaultItem>>{};
  for (final item in active) {
    final password = item.password;
    if (password.isEmpty) continue;
    byPassword.putIfAbsent(password, () => <VaultItem>[]).add(item);
  }
  for (final group in byPassword.values) {
    if (group.length >= 2) {
      issues.add(SecurityIssue(kind: SecurityIssueKind.reused, items: group));
    }
  }

  return issues;
}

/// 参与统计的条目数（去重后），用于设置页副标题。
int securityIssueItemCount(List<VaultItem> items, {DateTime? now}) {
  final ids = <String>{};
  for (final issue in auditVault(items, now: now)) {
    for (final item in issue.items) {
      ids.add(item.id);
    }
  }
  return ids.length;
}

bool isWeakPassword(String password) {
  if (password.isEmpty) return true;
  if (password.length < weakPasswordLength) return true;
  final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
  final hasDigit = RegExp(r'[0-9]').hasMatch(password);
  final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(password);
  if (!hasLetter && !hasDigit) return true;
  if (RegExp(r'^\d+$').hasMatch(password)) return true;
  if (RegExp(r'^[A-Za-z]+$').hasMatch(password)) return true;
  if (!hasSymbol && !(hasLetter && hasDigit)) return true;
  return false;
}

/// 主密码强度评分（0–4），用于创建/修改主密码时的即时反馈。
///
/// 规则与 [isWeakPassword] 不同：主密码允许长口令短语，长度权重更高。
int masterPasswordScore(String password) {
  if (password.isEmpty) return 0;
  var score = 0;
  if (password.length >= 10) score++;
  if (password.length >= 16) score++;
  if (RegExp(r'[A-Za-z]').hasMatch(password) &&
      RegExp(r'[0-9]').hasMatch(password)) {
    score++;
  }
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(password) || password.length >= 24) {
    score++;
  }
  return score.clamp(0, 4);
}
