import 'package:flutter_test/flutter_test.dart';
import 'package:keycase/app/platform/biometric_auth.dart';
import 'package:local_auth/local_auth.dart';

class _FakeLocalAuthentication extends LocalAuthentication {
  bool available = true;
  bool approved = true;
  Object? error;

  @override
  Future<bool> isDeviceSupported() async => available;

  @override
  Future<bool> get canCheckBiometrics async => available;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async =>
      available ? <BiometricType>[BiometricType.fingerprint] : const [];

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic> authMessages = const <dynamic>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    final failure = error;
    if (failure != null) throw failure;
    return approved;
  }
}

void main() {
  test('可用性检查与成功/取消结果', () async {
    final fake = _FakeLocalAuthentication();
    final auth = BiometricAuth(authentication: fake);

    expect(await auth.isAvailable(), isTrue);
    expect(await auth.authenticate(reason: 'reason'), BiometricResult.success);

    fake.approved = false;
    expect(await auth.authenticate(reason: 'reason'), BiometricResult.canceled);

    fake.available = false;
    expect(await auth.isAvailable(), isFalse);
  });

  test('系统取消、不可用与失败分别映射', () async {
    final fake = _FakeLocalAuthentication();
    final auth = BiometricAuth(authentication: fake);

    fake.error = const LocalAuthException(
      code: LocalAuthExceptionCode.userCanceled,
    );
    expect(await auth.authenticate(reason: 'reason'), BiometricResult.canceled);

    fake.error = const LocalAuthException(
      code: LocalAuthExceptionCode.noBiometricsEnrolled,
    );
    expect(
      await auth.authenticate(reason: 'reason'),
      BiometricResult.unavailable,
    );

    fake.error = const LocalAuthException(
      code: LocalAuthExceptionCode.deviceError,
    );
    expect(await auth.authenticate(reason: 'reason'), BiometricResult.failed);
  });
}
