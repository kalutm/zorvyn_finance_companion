import 'package:equatable/equatable.dart';
import 'package:finance_frontend/features/budget/domain/entities/dtos/budget_create.dart';
import 'package:finance_frontend/features/budget/domain/entities/dtos/budget_patch.dart';
import 'package:flutter/foundation.dart';

@immutable
abstract class BudgetFormEvent extends Equatable {
  const BudgetFormEvent();

  @override
  List<Object?> get props => [];
}

class CreateBudget extends BudgetFormEvent {
  final BudgetCreate create;
  const CreateBudget(this.create);

  @override
  List<Object?> get props => [create];
}

class GetBudget extends BudgetFormEvent {
  final String id;
  const GetBudget(this.id);

  @override
  List<Object?> get props => [id];
}

class UpdateBudget extends BudgetFormEvent {
  final String id;
  final BudgetPatch patch;
  const UpdateBudget(this.id, this.patch);

  @override
  List<Object?> get props => [id, patch];
}

class DeactivateBudget extends BudgetFormEvent {
  final String id;
  const DeactivateBudget(this.id);

  @override
  List<Object?> get props => [id];
}

class RestoreBudget extends BudgetFormEvent {
  final String id;
  const RestoreBudget(this.id);

  @override
  List<Object?> get props => [id];
}

class DeleteBudget extends BudgetFormEvent {
  final String id;
  const DeleteBudget(this.id);

  @override
  List<Object?> get props => [id];
}
