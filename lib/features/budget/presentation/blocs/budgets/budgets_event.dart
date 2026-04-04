import 'package:equatable/equatable.dart';
import 'package:finance_frontend/features/budget/domain/entities/budget.dart';
import 'package:flutter/foundation.dart';

@immutable
abstract class BudgetsEvent extends Equatable {
  const BudgetsEvent();

  @override
  List<Object?> get props => [];
}

class LoadBudgets extends BudgetsEvent {
  const LoadBudgets();
}

class RefreshBudgets extends BudgetsEvent {
  const RefreshBudgets();
}

class BudgetsUpdated extends BudgetsEvent {
  final List<Budget> budgets;
  const BudgetsUpdated(this.budgets);

  @override
  List<Object?> get props => [budgets];
}
