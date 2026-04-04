abstract class BiometricAuthService {
  Future<bool> canAuthenticate();

  Future<bool> authenticate({required String reason});
}
