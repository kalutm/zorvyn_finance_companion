import 'package:finance_frontend/features/transactions/presentation/cubits/report_analytics_cubit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// abstractions & implementations
import 'package:finance_frontend/features/settings/domain/services/shared_preferences_service.dart'; // SharedPreferencesService
import 'package:finance_frontend/features/settings/data/services/finance_shared_preferences_service.dart'; // FinanceSharedPreferencesService

import 'package:finance_frontend/features/accounts/domain/service/account_service.dart'; // AccountService
import 'package:finance_frontend/features/accounts/data/services/hive_account_service.dart'; // HiveAccountService

import 'package:finance_frontend/features/categories/domain/service/category_service.dart'; // CategoryService
import 'package:finance_frontend/features/categories/data/services/hive_category_service.dart'; // HiveCategoryService

import 'package:finance_frontend/features/transactions/domain/service/transaction_service.dart'; // TransactionService
import 'package:finance_frontend/features/transactions/data/service/finance_transaction_service.dart'; // FinanceTransactionService

import 'package:finance_frontend/features/transactions/domain/data_source/trans_data_source.dart'; // TransDataSource
import 'package:finance_frontend/features/transactions/data/data_sources/hive_trans_data_source.dart'; // HiveTransDataSource

import 'package:finance_frontend/features/budget/domain/service/budget_service.dart'; // BudgetService
import 'package:finance_frontend/features/budget/data/services/hive_budget_service.dart'; // HiveBudgetService

// Blocs / Cubits
import 'package:finance_frontend/features/settings/presentation/cubits/settings_cubit.dart'; // SettingsCubit
import 'package:finance_frontend/features/accounts/presentation/blocs/accounts/accounts_bloc.dart'; // AccountsBloc
import 'package:finance_frontend/features/accounts/presentation/blocs/account_form/account_form_bloc.dart'; // AccountFormBloc
import 'package:finance_frontend/features/categories/presentation/blocs/categories/categories_bloc.dart'; // CategoriesBloc
import 'package:finance_frontend/features/categories/presentation/blocs/category_form/category_form_bloc.dart'; // CategoryFormBloc
import 'package:finance_frontend/features/transactions/presentation/bloc/transactions/transactions_bloc.dart'; // TransactionsBloc
import 'package:finance_frontend/features/transactions/presentation/bloc/transaction_form/transaction_form_bloc.dart'; // TransactionFormBloc
import 'package:finance_frontend/features/budget/presentation/blocs/budgets/budgets_bloc.dart'; // BudgetsBloc
import 'package:finance_frontend/features/budget/presentation/blocs/budget_form/budget_form_bloc.dart'; // BudgetFormBloc

/// Low level / core providers ///

/// Rest Api base Url provider

/// Shared preferences provider
final sharedPreferencesProvider = Provider<SharedPreferencesService>((ref) {
  return FinanceSharedPreferencesService();
});

/// Services & DataSources  ///

/// HiveAccountService exposed as AccountService (interface)
final accountServiceProvider = Provider<AccountService>((ref) {
  return HiveAccountService();
});

/// HiveCategoryService exposed as CategoryService (interface)
final categoryServiceProvider = Provider<CategoryService>((ref) {
  return HiveCategoryService();
});

/// HiveTransDataSource exposed as TransDataSource (interface)
final transDataSourceProvider = Provider<TransDataSource>((ref) {
  return HiveTransDataSource();
});

/// HiveBudgetService exposed as BudgetService (interface)
final budgetServiceProvider = Provider<BudgetService>((ref) {
  return HiveBudgetService();
});

/// FinanceTransactionService exposed as TransactionService (interface)
final transactionServiceProvider = Provider<TransactionService>((ref) {
  // Note: depends on AccountService (interface) and TransDataSource (interface)
  return FinanceTransactionService(
    ref.read(accountServiceProvider),
    ref.read(transDataSourceProvider),
  );
});

/// Blocs / Cubits ///

/// SettingsCubit
final settingsCubitProvider = Provider<SettingsCubit>((ref) {
  final service = ref.read(sharedPreferencesProvider);
  return SettingsCubit(service);
});

/// AccountsBloc
final accountsBlocProvider = Provider<AccountsBloc>((ref) {
  final service = ref.read(accountServiceProvider);
  return AccountsBloc(service);
});

/// AccountFormBloc
final accountFormBlocProvider = Provider<AccountFormBloc>((ref) {
  final service = ref.read(accountServiceProvider);
  return AccountFormBloc(service);
});

/// CategoriesBloc
final categoriesBlocProvider = Provider<CategoriesBloc>((ref) {
  final service = ref.read(categoryServiceProvider);
  return CategoriesBloc(service);
});

/// CategoryFormBloc
final categoryFormBlocProvider = Provider<CategoryFormBloc>((ref) {
  final service = ref.read(categoryServiceProvider);
  return CategoryFormBloc(service);
});

/// TransactionsBloc
final transactionsBlocProvider = Provider<TransactionsBloc>((ref) {
  final service = ref.read(transactionServiceProvider);
  return TransactionsBloc(service);
});

/// TransactionFormBloc
final transactionFormBlocProvider = Provider<TransactionFormBloc>((ref) {
  final service = ref.read(transactionServiceProvider);
  return TransactionFormBloc(service);
});

/// BudgetsBloc
final budgetsBlocProvider = Provider<BudgetsBloc>((ref) {
  final service = ref.read(budgetServiceProvider);
  return BudgetsBloc(service);
});

/// BudgetFormBloc
final budgetFormBlocProvider = Provider<BudgetFormBloc>((ref) {
  final service = ref.read(budgetServiceProvider);
  return BudgetFormBloc(service);
});

/// ReportAnlyticsCubit
final reportAnalyticsCubitProvider = Provider<ReportAnalyticsCubit>((ref) {
  final service = ref.read(transactionServiceProvider);
  return ReportAnalyticsCubit(service);
});
