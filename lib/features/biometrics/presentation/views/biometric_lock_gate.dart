import 'package:finance_frontend/core/provider/providers.dart';
import 'package:finance_frontend/features/biometrics/presentation/cubits/biometric_gate_cubit.dart';
import 'package:finance_frontend/features/biometrics/presentation/cubits/biometric_gate_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BiometricLockGate extends ConsumerStatefulWidget {
  final Widget child;

  const BiometricLockGate({required this.child, super.key});

  @override
  ConsumerState<BiometricLockGate> createState() => _BiometricLockGateState();
}

class _BiometricLockGateState extends ConsumerState<BiometricLockGate> {
  late final BiometricGateCubit _cubit;
  bool _isPreferenceLoading = true;
  bool _isLockEnabled = true;

  @override
  void initState() {
    super.initState();
    _cubit = BiometricGateCubit(ref.read(biometricAuthServiceProvider));
    _initializeLockGate();
  }

  Future<void> _initializeLockGate() async {
    final sharedPrefs = ref.read(sharedPreferencesProvider);
    final isEnabled = await sharedPrefs.isBiometricLockEnabled();

    if (!mounted) {
      return;
    }

    setState(() {
      _isPreferenceLoading = false;
      _isLockEnabled = isEnabled;
    });

    if (isEnabled) {
      _cubit.unlockApp();
    }
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isPreferenceLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_clock_rounded,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Preparing security settings...',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    if (!_isLockEnabled) {
      return widget.child;
    }

    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<BiometricGateCubit, BiometricGateState>(
        builder: (context, state) {
          if (state is BiometricGateUnlocked) {
            return widget.child;
          }

          if (state is BiometricGateChecking || state is BiometricGateInitial) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fingerprint_rounded,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Securing your finance data...',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                  ],
                ),
              ),
            );
          }

          final failure = state as BiometricGateFailure;
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 56,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'App Locked',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      failure.message,
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => _cubit.unlockApp(),
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
