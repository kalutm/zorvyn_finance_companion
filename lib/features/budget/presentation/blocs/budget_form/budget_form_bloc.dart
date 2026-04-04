import 'dart:io';

import 'package:finance_frontend/features/budget/domain/exceptions/budget_exceptions.dart';
import 'package:finance_frontend/features/budget/domain/service/budget_service.dart';
import 'package:finance_frontend/features/budget/presentation/blocs/budget_form/budget_form_event.dart';
import 'package:finance_frontend/features/budget/presentation/blocs/budget_form/budget_form_state.dart';
import 'package:finance_frontend/features/budget/presentation/blocs/entities/operation_type_enum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BudgetFormBloc extends Bloc<BudgetFormEvent, BudgetFormState> {
  final BudgetService service;

  BudgetFormBloc(this.service) : super(const BudgetFormInitial()) {
    on<CreateBudget>(_onCreate);
    on<GetBudget>(_onGet);
    on<UpdateBudget>(_onUpdate);
    on<DeactivateBudget>(_onDeactivate);
    on<RestoreBudget>(_onRestore);
    on<DeleteBudget>(_onDelete);
  }

  Future<void> _onCreate(
    CreateBudget event,
    Emitter<BudgetFormState> emit,
  ) async {
    try {
      emit(const BudgetOperationInProgress());
      final budget = await service.createBudget(event.create);
      emit(BudgetOperationSuccess(budget, BudgetOperationType.create));
    } catch (e) {
      emit(BudgetOperationFailure(_mapErrorToMessage(e)));
    }
  }

  Future<void> _onGet(GetBudget event, Emitter<BudgetFormState> emit) async {
    try {
      emit(const BudgetOperationInProgress());
      final budget = await service.getBudget(event.id);
      emit(BudgetOperationSuccess(budget, BudgetOperationType.read));
    } catch (e) {
      emit(BudgetOperationFailure(_mapErrorToMessage(e)));
    }
  }

  Future<void> _onUpdate(
    UpdateBudget event,
    Emitter<BudgetFormState> emit,
  ) async {
    try {
      emit(const BudgetOperationInProgress());
      final budget = await service.updateBudget(event.id, event.patch);
      emit(BudgetOperationSuccess(budget, BudgetOperationType.update));
    } catch (e) {
      emit(BudgetOperationFailure(_mapErrorToMessage(e)));
    }
  }

  Future<void> _onDeactivate(
    DeactivateBudget event,
    Emitter<BudgetFormState> emit,
  ) async {
    try {
      emit(const BudgetOperationInProgress());
      final budget = await service.deactivateBudget(event.id);
      emit(BudgetOperationSuccess(budget, BudgetOperationType.deactivate));
    } catch (e) {
      emit(BudgetOperationFailure(_mapErrorToMessage(e)));
    }
  }

  Future<void> _onRestore(
    RestoreBudget event,
    Emitter<BudgetFormState> emit,
  ) async {
    try {
      emit(const BudgetOperationInProgress());
      final budget = await service.restoreBudget(event.id);
      emit(BudgetOperationSuccess(budget, BudgetOperationType.restore));
    } catch (e) {
      emit(BudgetOperationFailure(_mapErrorToMessage(e)));
    }
  }

  Future<void> _onDelete(
    DeleteBudget event,
    Emitter<BudgetFormState> emit,
  ) async {
    try {
      emit(const BudgetOperationInProgress());
      await service.deleteBudget(event.id);
      emit(BudgetDeleteOperationSuccess(event.id));
    } catch (e) {
      emit(BudgetOperationFailure(_mapErrorToMessage(e)));
    }
  }

  String _mapErrorToMessage(Object e) {
    if (e is CouldnotCreateBudget) {
      return 'Couldnot create budget, please try using another budget name';
    }
    if (e is CouldnotGetBudget) {
      return 'Couldnot get budget or Budget not found';
    }
    if (e is CouldnotUpdateBudget) {
      return 'Couldnot update budget, please try again';
    }
    if (e is CouldnotDeactivateBudget) {
      return 'Couldnot deactivate budget, please try again';
    }
    if (e is CouldnotRestoreBudget) {
      return 'Couldnot restore budget, please try again';
    }
    if (e is CouldnotDeleteBudget) {
      return 'Couldnot delete budget, please try again';
    }
    if (e is SocketException) {
      return 'No Internet connection!, please try connecting to the internet';
    }
    return e.toString();
  }
}
