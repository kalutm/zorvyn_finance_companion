abstract class SharedPreferencesService {
  Future<void> setDarkMode();
  Future<bool> isDarkMode();
  Future<void> setLightMode();

  Future<bool> isBiometricLockEnabled();
  Future<void> setBiometricLockEnabled(bool enabled);
}
