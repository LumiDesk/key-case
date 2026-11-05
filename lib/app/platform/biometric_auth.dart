import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

import '../logging/app_logger.dart';

/// 一次生物识别验证的结果。
enum BiometricResult { success, canceled, failed, unavailable }

/// 生物识别封装。
///
/// 只负责「让系统验证用户是本人」；真正的密钥由 Android Keystore 保存，
/// 见 [NativeBridge.storeVaultKey]。
class BiometricAuth {
  BiometricAuth({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  Future<bool> isAvailable() async {
    try {
      final supported = await _authentication.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _authentication.canCheckBiometrics;
      if (canCheck) return true;
      final available = await _authentication.getAvailableBiometrics();
      return available.isNotEmpty;
    } on Exception catch (error) {
      AppLogger.warn('biometric availability check failed: $error');
      return false;
    }
  }

  /// 弹出系统生物识别提示。
  ///
  /// 用户主动取消不算错误：调用方应据此静默回退到主密码。系统弹窗的按钮
  /// 文案必须由调用方从 l10n 传入，这里不提供默认值。
  Future<BiometricResult> authenticate({
    required String reason,
    required String cancelLabel,
    String title = 'KeyCase',
  }) async {
    try {
      final approved = await _authentication.authenticate(
        localizedReason: reason,
        authMessages: <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: title,
            // Android 会把 hint 显示成第二行说明；留空只保留 reason 一行提示。
            signInHint: '',
            cancelButton: cancelLabel,
          ),
        ],
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return approved ? BiometricResult.success : BiometricResult.canceled;
    } on LocalAuthException catch (error) {
      AppLogger.warn('biometric authenticate failed: ${error.code.name}');
      return switch (error.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout => BiometricResult.canceled,
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout ||
        LocalAuthExceptionCode.userRequestedFallback =>
          BiometricResult.unavailable,
        _ => BiometricResult.failed,
      };
    } on Exception catch (error) {
      AppLogger.warn('biometric authenticate failed: $error');
      return BiometricResult.failed;
    }
  }
}
