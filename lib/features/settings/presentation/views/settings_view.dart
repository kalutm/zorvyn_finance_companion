import 'package:finance_frontend/core/provider/providers.dart';
import 'package:finance_frontend/features/accounts/presentation/blocs/accounts/accounts_bloc.dart';
import 'package:finance_frontend/features/budget/presentation/blocs/budgets/budgets_bloc.dart';
import 'package:finance_frontend/features/categories/presentation/blocs/categories/categories_bloc.dart';
import 'package:finance_frontend/features/settings/presentation/cubits/data_transfer_cubit.dart';
import 'package:finance_frontend/features/settings/presentation/cubits/data_transfer_state.dart';
import 'package:finance_frontend/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:finance_frontend/features/settings/presentation/cubits/settings_state.dart';
import 'package:finance_frontend/features/transactions/presentation/bloc/transactions/transactions_bloc.dart';
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
    // Inject living BLoC references into the DataTransferCubit so it can
    // reload them automatically after a successful import.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DataTransferCubit>().registerBlocs(
        accountsBloc: context.read<AccountsBloc>(),
        transactionsBloc: context.read<TransactionsBloc>(),
        categoriesBloc: context.read<CategoriesBloc>(),
        budgetsBloc: context.read<BudgetsBloc>(),
      );
    });
  }

  Future<void> _loadBiometricSetting() async {
    final service = ref.read(sharedPreferencesProvider);
    final enabled = await service.isBiometricLockEnabled();
    if (!mounted) return;
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

    if (!mounted) return;
    setState(() {
      _isUpdatingBiometric = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<DataTransferCubit, DataTransferState>(
        listener: (context, state) {
          if (state is DataTransferSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green.shade700,
              ),
            );
            // Reset to idle so the next action can show a fresh snackbar.
            context.read<DataTransferCubit>().reset();
          } else if (state is DataTransferFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red.shade700,
              ),
            );
            context.read<DataTransferCubit>().reset();
          }
        },
        builder: (context, transferState) {
          final isTransferring = transferState is DataTransferLoading;

          return ListView(
            children: [
              // ── Appearance ──────────────────────────────────────────────
              BlocSelector<SettingsCubit, SettingsState, bool>(
                selector: (state) => state is SettingsStateDark,
                builder: (context, isDarkMode) {
                  return SwitchListTile(
                    title: const Text('Dark Mode'),
                    value: isDarkMode,
                    onChanged: (_) =>
                        context.read<SettingsCubit>().changeTheme(),
                    secondary: Icon(
                      isDarkMode ? Icons.brightness_2 : Icons.brightness_7,
                    ),
                  );
                },
              ),

              // ── Biometric lock ──────────────────────────────────────────
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

              const Divider(),

              // ── Data management ─────────────────────────────────────────
              ListTile(
                leading:
                    isTransferring
                        ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.upload_rounded),
                title: const Text('Export Data'),
                subtitle: const Text(
                  'Save a backup of all your accounts, transactions, '
                  'budgets, and categories.',
                ),
                enabled: !isTransferring,
                onTap:
                    isTransferring
                        ? null
                        : () =>
                            context.read<DataTransferCubit>().exportData(),
              ),
              ListTile(
                leading:
                    isTransferring
                        ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.download_rounded),
                title: const Text('Import Data'),
                subtitle: const Text(
                  'Restore from a previously exported backup file (.zip). '
                  'This will overwrite all current data.',
                ),
                enabled: !isTransferring,
                onTap:
                    isTransferring
                        ? null
                        : () =>
                            context.read<DataTransferCubit>().importData(),
              ),
            ],
          );
        },
      ),
    );
  }
}
