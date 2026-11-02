import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/import/otpauth_parser.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/app/update/update_checker.dart';
import 'package:keycase/app/util/password_generator.dart';
import 'package:keycase/app/util/url_tools.dart';

void main() {
  group('网址工具', () {
    test('补全 https 并拒绝非 http(s) 协议', () {
      expect(normalizeUrl('github.com'), 'https://github.com');
      expect(normalizeUrl('https://example.com/a'), 'https://example.com/a');
      expect(normalizeUrl('javascript:alert(1)'), isNull);
      expect(normalizeUrl('ftp://example.com'), isNull);
      expect(normalizeUrl('   '), isNull);
      expect(normalizeUrl('https://'), isNull);
    });

    test('展示地址去掉协议与末尾斜杠', () {
      expect(displayUrl('https://github.com/'), 'github.com');
      expect(displayUrl('https://example.com/path?q=1'), 'example.com/path');
      expect(displayUrl('ftp://example.com'), 'ftp://example.com');
    });
  });

  group('密码生成', () {
    test('长度与字符类别符合选项', () {
      const options = PasswordGeneratorOptions(length: 24);
      final generated = generatePassword(options);

      expect(generated.length, 24);
      expect(RegExp(r'[a-z]').hasMatch(generated), isTrue);
      expect(RegExp(r'[A-Z]').hasMatch(generated), isTrue);
      expect(RegExp(r'[0-9]').hasMatch(generated), isTrue);
      expect(RegExp(r'[^A-Za-z0-9]').hasMatch(generated), isTrue);
    });

    test('关闭全部字符类别时返回空串', () {
      expect(
        generatePassword(
          const PasswordGeneratorOptions(
            lowercase: false,
            uppercase: false,
            digits: false,
            symbols: false,
          ),
        ),
        isEmpty,
      );
    });
  });

  group('otpauth 生成与解析往返', () {
    test('TOTP 密钥、账号与算法保持', () {
      const secret = TotpSecret(
        secret: 'JBSWY3DPEHPK3PXP',
        algorithm: OtpHashAlgorithm.sha256,
        digits: 8,
        period: 60,
      );
      final uri = buildOtpauthUri(
        secret,
        issuer: 'Example',
        account: 'alice@example.com',
      );
      final parsed = parseOtpauthUri(uri);

      expect(parsed, isNotNull);
      expect(parsed!.secret, secret.secret);
      expect(parsed.issuer, 'Example');
      expect(parsed.account, 'alice@example.com');
      expect(parsed.algorithm, OtpHashAlgorithm.sha256);
      expect(parsed.digits, 8);
      expect(parsed.period, 60);
    });

    test('HOTP 保留计数器', () {
      const secret = TotpSecret(
        type: OtpType.hotp,
        secret: 'JBSWY3DPEHPK3PXP',
        counter: 42,
      );
      final parsed = parseOtpauthUri(buildOtpauthUri(secret, account: 'bob'));

      expect(parsed?.type, OtpType.hotp);
      expect(parsed?.counter, 42);
    });
  });

  group('版本比较', () {
    test('按数字段比较并忽略预发布后缀', () {
      expect(compareVersions('1.0.0', '1.0.0'), 0);
      expect(compareVersions('1.0.0-beta', '1.0.0'), 0);
      expect(compareVersions('1.2.0', '1.10.0'), lessThan(0));
      expect(compareVersions('2.0', '1.9.9'), greaterThan(0));
      expect(compareVersions('1.0.0+8', '1.0.0+9'), 0);
    });
  });
}
