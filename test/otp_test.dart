import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/crypto/base32.dart';
import 'package:keycase/app/models/models.dart';
import 'package:keycase/app/otp/otp.dart';

/// RFC 6238 的种子是 ASCII "12345678901234567890"，这里转成 Base32。
String rfcSecret() =>
    base32Encode(Uint8List.fromList(utf8.encode('12345678901234567890')));

void main() {
  group('TOTP（RFC 6238 测试向量）', () {
    final secret = TotpSecret(secret: rfcSecret(), digits: 8, period: 30);

    const vectors = <int, String>{
      59: '94287082',
      1111111109: '07081804',
      1111111111: '14050471',
      1234567890: '89005924',
      2000000000: '69279037',
      20000000000: '65353130',
    };

    vectors.forEach((seconds, expected) {
      test('T=$seconds', () {
        final counter = seconds ~/ 30;
        expect(generateOtpCode(secret: secret, counter: counter), expected);
      });
    });

    test('剩余秒数：时间片边界返回完整周期', () {
      DateTime at(int seconds) =>
          DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      // 59 秒处于 30..59 的最后一个时间片，只剩 1 秒。
      expect(otpSecondsRemaining(secret, at(59)), 1);
      // 整 30 秒是下一轮时间片的开始。
      expect(otpSecondsRemaining(secret, at(30)), 30);
      expect(otpSecondsRemaining(secret, at(31)), 29);
    });
  });

  group('HOTP（RFC 4226 附录 D）', () {
    test('计数器 0..9 的 6 位码', () {
      final secret = TotpSecret(
        type: OtpType.hotp,
        secret: rfcSecret(),
        digits: 6,
      );
      const expected = <String>[
        '755224',
        '287082',
        '359152',
        '969429',
        '338314',
        '254676',
        '287922',
        '162583',
        '399871',
        '520489',
      ];
      for (var counter = 0; counter < expected.length; counter++) {
        expect(
          generateOtpCode(
            secret: secret.copyWith(counter: counter),
            counter: counter,
          ),
          expected[counter],
        );
      }
    });

    test('HOTP 没有倒计时', () {
      final secret = TotpSecret(type: OtpType.hotp, secret: rfcSecret());
      expect(otpSecondsRemaining(secret, DateTime.now()), 0);
    });
  });

  group('Steam', () {
    test('输出 5 位、只含 Steam 字母表', () {
      final secret = TotpSecret(
        type: OtpType.steam,
        secret: 'JBSWY3DPEHPK3PXP',
      );
      final code = generateOtpCode(secret: secret, counter: 12345);
      expect(code.length, 5);
      expect(
        RegExp(r'^[23456789BCDFGHJKMNPQRTVWXY]{5}$').hasMatch(code),
        isTrue,
      );
    });
  });

  group('格式化', () {
    test('自动分组：6 位 3+3、8 位 4+4', () {
      expect(formatOtpCode('123456', CodeGrouping.auto), '123 456');
      expect(formatOtpCode('12345678', CodeGrouping.auto), '1234 5678');
    });

    test('指定分组与不分组', () {
      expect(formatOtpCode('12345678', CodeGrouping.three), '123 456 78');
      expect(formatOtpCode('12345678', CodeGrouping.four), '1234 5678');
      expect(formatOtpCode('12345678', CodeGrouping.none), '12345678');
    });

    test('Steam 永不分组', () {
      expect(formatOtpCode('ABCDE', CodeGrouping.auto, steam: true), 'ABCDE');
    });

    test('隐藏态与可见码等宽', () {
      expect(hiddenOtpCode('123456'), '••• •••');
      expect(hiddenOtpCode('12345678'), '••• ••• ••');
    });
  });

  group('Base32', () {
    test('解码容忍小写、空格与填充', () {
      expect(
        base32Decode('JBSWY3DP EHPK3PXP'),
        base32Decode('jbswy3dpehpk3pxp'),
      );
      expect(base32Decode('MZXW6==='), utf8.encode('foo'));
    });

    test('非法字符抛 FormatException', () {
      expect(() => base32Decode('ABC1'), throwsFormatException);
    });
  });
}
