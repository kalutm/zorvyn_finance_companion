import 'package:finance_frontend/core/provider/providers.dart';
import 'package:finance_frontend/features/budget/presentation/blocs/budget_form/budget_form_bloc.dart';
import 'package:finance_frontend/features/budget/presentation/blocs/budgets/budgets_bloc.dart';
import 'package:finance_frontend/features/budget/presentation/views/budgets_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BudgetsWrapper extends ConsumerWidget {
  const BudgetsWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<BudgetsBloc>()),
        BlocProvider(
          create: (_) => BudgetFormBloc(ref.read(budgetServiceProvider)),
        ),
      ],
      child: const BudgetsView(),
    );
  }
}
