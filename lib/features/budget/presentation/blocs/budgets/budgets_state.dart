import 'package:equatable/equatable.dart';
import 'package:finance_frontend/features/budget/domain/entities/budget.dart';
import 'package:flutter/foundation.dart';

@immutable
abstract class BudgetsState extends Equatable {
  const BudgetsState();

  @override
  List<Object?> get props => [];
}

class BudgetsInitial extends BudgetsState {
  const BudgetsInitial();
}

class BudgetsLoading extends BudgetsState {
  const BudgetsLoading();
}

class BudgetsLoaded extends BudgetsState {
  final List<Budget> budgets;
  final String _fingerprint;

  BudgetsLoaded(this.budgets) : _fingerprint = _computeFingerprint(budgets);

  static String _computeFingerprint(List<Budget> budgets) {
    return budgets
        .map(
          (b) =>
              '${b.id}:${b.name}:${b.limitAmount}:${b.active}:${b.categoryId ?? ''}:${b.accountId ?? ''}:${b.alertThreshold}',
        )
        .join('|');
  }

  @override
  List<Object?> get props => [budgets, _fingerprint];
}

class BudgetsOperationFailure extends BudgetsState {
  final List<Budget> budgets;
  final String message;
  final String _fingerprint;

  BudgetsOperationFailure(this.message, this.budgets)
    : _fingerprint = BudgetsLoaded._computeFingerprint(budgets);

  @override
  List<Object?> get props => [message, budgets, _fingerprint];
}
