import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/import/otpauth_parser.dart';
import 'package:keycase/app/models/models.dart';

void main() {
  group('otpauth 解析', () {
    test('标准 TOTP 链接', () {
      final payload = parseOtpauthUri(
        'otpauth://totp/GitHub:talyra42?secret=JBSWY3DPEHPK3PXP&issuer=GitHub',
      );
      expect(payload, isNotNull);
      expect(payload!.type, OtpType.totp);
      expect(payload.issuer, 'GitHub');
      expect(payload.account, 'talyra42');
      expect(payload.secret, 'JBSWY3DPEHPK3PXP');
      expect(payload.digits, 6);
      expect(payload.period, 30);
    });

    test('缺 issuer 时从 label 前缀取', () {
      final payload = parseOtpauthUri(
        'otpauth://totp/Example%3Aalice%40example.com?secret=JBSWY3DPEHPK3PXP',
      );
      expect(payload?.issuer, 'Example');
      expect(payload?.account, 'alice@example.com');
    });

    test('HOTP 带计数器与算法', () {
      final payload = parseOtpauthUri(
        'otpauth://hotp/Test?secret=JBSWY3DPEHPK3PXP&counter=7&algorithm=SHA256&digits=8',
      );
      expect(payload?.type, OtpType.hotp);
      expect(payload?.counter, 7);
      expect(payload?.algorithm, OtpHashAlgorithm.sha256);
      expect(payload?.digits, 8);
    });

    test('拒绝非 otpauth 协议与坏密钥', () {
      expect(parseOtpauthUri('https://example.com'), isNull);
      expect(parseOtpauthUri('otpauth://totp/Test?secret=not*base32'), isNull);
    });

    test('生成的条目带上标题与账号', () {
      final payload = parseOtpauthUri(
        'otpauth://totp/GitHub:talyra42?secret=JBSWY3DPEHPK3PXP&issuer=GitHub',
      )!;
      final item = payload.toItem(DateTime.utc(2026, 1, 1));
      expect(item.kind, ItemKind.totp);
      expect(item.title, 'GitHub');
      expect(item.username, 'talyra42');
      expect(item.totp?.secret, 'JBSWY3DPEHPK3PXP');
    });

    test('Steam 二维码与导出链接对称', () {
      final payload = parseOtpauthUri(
        'otpauth://totp/Steam:alice?secret=MZXW6YTBOI'
        '&issuer=Steam&encoder=steam&digits=8&period=60',
      )!;
      expect(payload.type, OtpType.steam);
      expect(payload.digits, 5);
      expect(payload.period, 30);
      expect(payload.algorithm, OtpHashAlgorithm.sha1);

      final uri = buildOtpauthUri(
        payload.toSecret(),
        issuer: 'Steam',
        account: 'alice',
      );
      final reparsed = parseOtpauthUri(uri)!;
      expect(reparsed.type, OtpType.steam);
      expect(reparsed.digits, 5);
      expect(reparsed.period, 30);
    });
  });
}
