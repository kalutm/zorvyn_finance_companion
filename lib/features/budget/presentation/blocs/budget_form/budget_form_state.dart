import 'package:equatable/equatable.dart';
import 'package:finance_frontend/features/budget/domain/entities/budget.dart';
import 'package:finance_frontend/features/budget/presentation/blocs/entities/operation_type_enum.dart';
import 'package:flutter/foundation.dart';

@immutable
abstract class BudgetFormState extends Equatable {
  const BudgetFormState();

  @override
  List<Object?> get props => [];
}

class BudgetFormInitial extends BudgetFormState {
  const BudgetFormInitial();
}

class BudgetOperationInProgress extends BudgetFormState {
  const BudgetOperationInProgress();
}

class BudgetOperationSuccess extends BudgetFormState {
  final Budget budget;
  final BudgetOperationType operationType;
  const BudgetOperationSuccess(this.budget, this.operationType);

  @override
  List<Object?> get props => [budget, operationType];
}

class BudgetDeleteOperationSuccess extends BudgetFormState {
  final String id;
  const BudgetDeleteOperationSuccess(this.id);

  @override
  List<Object?> get props => [id];
}

class BudgetOperationFailure extends BudgetFormState {
  final String message;
  const BudgetOperationFailure(this.message);

  @override
  List<Object?> get props => [message];
}
