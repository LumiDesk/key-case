import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/app/security/security_audit.dart';

VaultItem login({
  required String id,
  required String password,
  DateTime? updatedAt,
  String title = 'Site',
}) {
  final now = DateTime.utc(2026, 1, 1);
  return VaultItem(
    id: id,
    kind: ItemKind.login,
    title: title,
    password: password,
    createdAt: now,
    updatedAt: updatedAt ?? now,
  );
}

void main() {
  group('弱密码判定', () {
    test('短、纯数字、纯字母都算弱', () {
      expect(isWeakPassword(''), isTrue);
      expect(isWeakPassword('abc123'), isTrue);
      expect(isWeakPassword('12345678901234'), isTrue);
      expect(isWeakPassword('abcdefghijklmn'), isTrue);
    });

    test('足够长且混合字符不算弱', () {
      expect(isWeakPassword('Tr0ub4dor-correct'), isFalse);
    });

    test('主密码强度评分随长度与字符类型提升', () {
      expect(masterPasswordScore(''), 0);
      expect(masterPasswordScore('short'), lessThan(2));
      expect(masterPasswordScore('a-very-long-passphrase-2026'), 4);
    });
  });

  group('安全中心', () {
    final now = DateTime.utc(2026, 6, 1);

    test('复用密码产出一组问题', () {
      final issues = auditVault(<VaultItem>[
        login(id: 'a', password: 'Shared#Pass123', title: 'A'),
        login(id: 'b', password: 'Shared#Pass123', title: 'B'),
      ], now: now);
      final reused = issues.where(
        (issue) => issue.kind == SecurityIssueKind.reused,
      );
      expect(reused, hasLength(1));
      expect(reused.first.items, hasLength(2));
    });

    test('超过一年的条目算过期', () {
      final issues = auditVault(<VaultItem>[
        login(
          id: 'old',
          password: 'Fresh#Pass1234',
          updatedAt: now.subtract(const Duration(days: 400)),
        ),
      ], now: now);
      expect(
        issues.any((issue) => issue.kind == SecurityIssueKind.stale),
        isTrue,
      );
    });

    test('已删除条目与令牌不参与', () {
      final now2 = DateTime.utc(2026, 6, 1);
      final issues = auditVault(<VaultItem>[
        login(id: 'gone', password: 'weak').copyWith(
          deletedAt: now2,
        ),
        VaultItem(
          id: 'token',
          kind: ItemKind.totp,
          title: 'T',
          totp: const TotpSecret(secret: 'JBSWY3DPEHPK3PXP'),
          createdAt: now2,
          updatedAt: now2,
        ),
      ], now: now2);
      expect(issues, isEmpty);
    });

    test('条目数统计去重', () {
      final count = securityIssueItemCount(<VaultItem>[
        login(id: 'a', password: 'Shared#Pass123'),
        login(id: 'b', password: 'Shared#Pass123'),
      ], now: now);
      expect(count, 2);
    });
  });
}
