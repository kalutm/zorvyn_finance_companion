import 'package:finance_frontend/features/biometrics/domain/services/biometric_auth_service.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class LocalBiometricAuthService implements BiometricAuthService {
  final LocalAuthentication _localAuth;

  LocalBiometricAuthService([LocalAuthentication? localAuth])
    : _localAuth = localAuth ?? LocalAuthentication();

  @override
  Future<bool> canAuthenticate() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics || isDeviceSupported;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      final isAvailable = await canAuthenticate();
      if (!isAvailable) {
        return false;
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );

      return didAuthenticate;
    } on PlatformException {
      return false;
    }
  }
}
