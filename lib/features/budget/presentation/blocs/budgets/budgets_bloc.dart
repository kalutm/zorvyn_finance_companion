import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:finance_frontend/features/budget/domain/entities/budget.dart';
import 'package:finance_frontend/features/budget/domain/exceptions/budget_exceptions.dart';
import 'package:finance_frontend/features/budget/domain/service/budget_service.dart';
import 'package:finance_frontend/features/budget/presentation/blocs/budgets/budgets_event.dart';
import 'package:finance_frontend/features/budget/presentation/blocs/budgets/budgets_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BudgetsBloc extends Bloc<BudgetsEvent, BudgetsState> {
  final BudgetService budgetService;
  StreamSubscription<List<Budget>>? _sub;

  BudgetsBloc(this.budgetService) : super(const BudgetsInitial()) {
    on<LoadBudgets>(_onLoadBudgets, transformer: droppable());
    on<RefreshBudgets>(_onRefreshBudgets, transformer: droppable());
    on<BudgetsUpdated>(_onBudgetsUpdated);

    _sub = budgetService.budgetsStream.listen(
      (budgets) => add(BudgetsUpdated(budgets)),
      onError: (err, st) {
        developer.log('BudgetService stream error', error: err, stackTrace: st);
      },
    );

    add(const LoadBudgets());
  }

  Future<void> _onLoadBudgets(
    LoadBudgets event,
    Emitter<BudgetsState> emit,
  ) async {
    emit(const BudgetsLoading());
    try {
      final budgets = await budgetService.getUserBudgets();
      emit(BudgetsLoaded(List.unmodifiable(budgets)));
    } catch (e) {
      emit(BudgetsOperationFailure(_mapErrorToMessage(e), const []));
    }
  }

  Future<void> _onRefreshBudgets(
    RefreshBudgets event,
    Emitter<BudgetsState> emit,
  ) async {
    final current =
        state is BudgetsLoaded
            ? (state as BudgetsLoaded).budgets
            : const <Budget>[];
    emit(BudgetsLoaded(List.unmodifiable(current)));
    try {
      final budgets = await budgetService.getUserBudgets();
      emit(BudgetsLoaded(List.unmodifiable(budgets)));
    } catch (e, st) {
      developer.log('Refresh budgets error', error: e, stackTrace: st);
      emit(BudgetsOperationFailure(_mapErrorToMessage(e), current));
    }
  }

  Future<void> _onBudgetsUpdated(
    BudgetsUpdated event,
    Emitter<BudgetsState> emit,
  ) async {
    emit(BudgetsLoaded(List.unmodifiable(event.budgets)));
  }

  String _mapErrorToMessage(Object e) {
    if (e is CouldnotFetchBudgets) {
      return 'Could not fetch budgets, please try reloading the page';
    }
    if (e is SocketException) {
      return 'No Internet connection!, please try connecting to the internet';
    }
    return e.toString();
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
