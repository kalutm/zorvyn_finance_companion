import 'package:finance_frontend/core/provider/providers.dart';
import 'package:finance_frontend/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:finance_frontend/features/settings/presentation/cubits/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  bool _isBiometricLockEnabled = true;
  bool _isBiometricLoading = true;
  bool _isUpdatingBiometric = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
  }

  Future<void> _loadBiometricSetting() async {
    final service = ref.read(sharedPreferencesProvider);
    final enabled = await service.isBiometricLockEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _isBiometricLockEnabled = enabled;
      _isBiometricLoading = false;
    });
  }

  Future<void> _updateBiometricLock(bool enabled) async {
    setState(() {
      _isUpdatingBiometric = true;
      _isBiometricLockEnabled = enabled;
    });

    final service = ref.read(sharedPreferencesProvider);
    await service.setBiometricLockEnabled(enabled);

    if (!mounted) {
      return;
    }
    setState(() {
      _isUpdatingBiometric = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          BlocSelector<SettingsCubit, SettingsState, bool>(
            selector: (state) => state is SettingsStateDark,
            builder: (context, isDarkMode) {
              return SwitchListTile(
                title: const Text('Dark Mode'),
                value: isDarkMode,
                onChanged: (_) => context.read<SettingsCubit>().changeTheme(),
                secondary: Icon(
                  isDarkMode ? Icons.brightness_2 : Icons.brightness_7,
                ),
              );
            },
          ),
          if (_isBiometricLoading)
            const ListTile(
              leading: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('Loading biometric settings...'),
            )
          else
            SwitchListTile(
              title: const Text('Biometric App Lock'),
              subtitle: const Text(
                'Require fingerprint/face unlock when opening the app.',
              ),
              value: _isBiometricLockEnabled,
              onChanged:
                  _isUpdatingBiometric
                      ? null
                      : (value) => _updateBiometricLock(value),
              secondary: Icon(
                _isBiometricLockEnabled
                    ? Icons.fingerprint_rounded
                    : Icons.lock_open_rounded,
              ),
            ),
        ],
      ),
    );
  }
}
