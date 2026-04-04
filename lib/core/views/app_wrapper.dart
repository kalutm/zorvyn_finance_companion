import 'package:finance_frontend/core/provider/providers.dart';
import 'package:finance_frontend/core/views/home.dart';
import 'package:finance_frontend/features/accounts/presentation/blocs/accounts/accounts_bloc.dart';
import 'package:finance_frontend/features/biometrics/presentation/views/biometric_lock_gate.dart';
import 'package:finance_frontend/features/budget/presentation/blocs/budgets/budgets_bloc.dart';
import 'package:finance_frontend/features/categories/presentation/blocs/categories/categories_bloc.dart';
import 'package:finance_frontend/features/transactions/presentation/bloc/transaction_form/transaction_form_bloc.dart';
import 'package:finance_frontend/features/transactions/presentation/bloc/transactions/transactions_bloc.dart';
import 'package:finance_frontend/features/transactions/presentation/cubits/report_analytics_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppWrapper extends ConsumerStatefulWidget {
  const AppWrapper({super.key});

  @override
  ConsumerState<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends ConsumerState<AppWrapper> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final systemOverlayStyle =
        theme.brightness == Brightness.light
            ? SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
            )
            : SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
            );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyle,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AccountsBloc(ref.read(accountServiceProvider)),
          ),
          BlocProvider(
            create:
                (context) =>
                    TransactionsBloc(ref.read(transactionServiceProvider)),
          ),
          BlocProvider(
            create:
                (context) =>
                    TransactionFormBloc(ref.read(transactionServiceProvider)),
          ),
          BlocProvider(
            create:
                (context) => CategoriesBloc(ref.read(categoryServiceProvider)),
          ),
          BlocProvider(
            create: (context) => BudgetsBloc(ref.read(budgetServiceProvider)),
          ),
          BlocProvider(
            create:
                (context) =>
                    ReportAnalyticsCubit(ref.read(transactionServiceProvider)),
          ),
        ],
        child: const BiometricLockGate(child: Home()),
      ),
    );
  }
}
