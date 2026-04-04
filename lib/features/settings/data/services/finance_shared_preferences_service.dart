import 'package:finance_frontend/features/settings/domain/services/shared_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FinanceSharedPreferencesService implements SharedPreferencesService {
  static const String _darkModeKey = 'isDarkMode';
  static const String _biometricLockEnabledKey = 'isBiometricLockEnabled';

  Future<SharedPreferences> get _sharedPreferences async {
    return await SharedPreferences.getInstance();
  }

  @override
  Future<bool> isDarkMode() async {
    final sharedPref = await _sharedPreferences;
    final isDarkMode = sharedPref.getBool(_darkModeKey) ?? true;
    return isDarkMode;
  }

  @override
  Future<void> setDarkMode() async {
    final sharedPref = await _sharedPreferences;
    sharedPref.setBool(_darkModeKey, true);
  }

  @override
  Future<void> setLightMode() async {
    final sharedPref = await _sharedPreferences;
    sharedPref.setBool(_darkModeKey, false);
  }

  @override
  Future<bool> isBiometricLockEnabled() async {
    final sharedPref = await _sharedPreferences;
    final isEnabled = sharedPref.getBool(_biometricLockEnabledKey) ?? true;
    return isEnabled;
  }

  @override
  Future<void> setBiometricLockEnabled(bool enabled) async {
    final sharedPref = await _sharedPreferences;
    await sharedPref.setBool(_biometricLockEnabledKey, enabled);
  }
}
