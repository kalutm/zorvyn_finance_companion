import 'dart:async';

import 'package:finance_frontend/features/budget/domain/entities/budget.dart';
import 'package:finance_frontend/features/budget/domain/entities/dtos/budget_create.dart';
import 'package:finance_frontend/features/budget/domain/entities/dtos/budget_patch.dart';

abstract class BudgetService {
  Stream<List<Budget>> get budgetsStream;

  Future<List<Budget>> getUserBudgets();

  Future<Budget> createBudget(BudgetCreate create);

  Future<Budget> getBudget(String id);

  Future<Budget> updateBudget(String id, BudgetPatch patch);

  Future<Budget> deactivateBudget(String id);

  Future<void> deleteBudget(String id);

  Future<Budget> restoreBudget(String id);

  Future<void> clearCache();
}
