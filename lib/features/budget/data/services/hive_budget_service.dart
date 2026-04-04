import 'dart:async';

import 'package:finance_frontend/core/storage/hive_bootstrap.dart';
import 'package:finance_frontend/core/storage/hive_box_names.dart';
import 'package:finance_frontend/features/budget/domain/entities/budget.dart';
import 'package:finance_frontend/features/budget/domain/entities/dtos/budget_create.dart';
import 'package:finance_frontend/features/budget/domain/entities/dtos/budget_patch.dart';
import 'package:finance_frontend/features/budget/domain/exceptions/budget_exceptions.dart';
import 'package:finance_frontend/features/budget/domain/service/budget_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveBudgetService implements BudgetService {
  final List<Budget> _cache = [];
  final StreamController<List<Budget>> _controller =
      StreamController<List<Budget>>.broadcast();

  @override
  Stream<List<Budget>> get budgetsStream => _controller.stream;

  Future<Box<dynamic>> _budgetsBox() async {
    await HiveBootstrap.ensureInitialized();
    if (Hive.isBoxOpen(HiveBoxNames.budgets)) {
      return Hive.box<dynamic>(HiveBoxNames.budgets);
    }
    return Hive.openBox<dynamic>(HiveBoxNames.budgets);
  }

  Future<Box<dynamic>> _metaBox() async {
    await HiveBootstrap.ensureInitialized();
    if (Hive.isBoxOpen(HiveBoxNames.meta)) {
      return Hive.box<dynamic>(HiveBoxNames.meta);
    }
    return Hive.openBox<dynamic>(HiveBoxNames.meta);
  }

  Future<String> _nextBudgetId() async {
    final box = await _metaBox();
    final current = (box.get(HiveBoxNames.budgetIdCounter) as int?) ?? 0;
    final next = current + 1;
    await box.put(HiveBoxNames.budgetIdCounter, next);
    return next.toString();
  }

  String? _normalizeNullableId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value;
  }

  Budget _fromStored(Map<String, dynamic> json) {
    return Budget(
      id: json['id'].toString(),
      name: (json['name'] ?? '').toString(),
      limitAmount: (json['limit_amount'] ?? '0').toString(),
      currency: (json['currency'] ?? 'ETB').toString(),
      categoryId: _normalizeNullableId(json['category_id']?.toString()),
      accountId: _normalizeNullableId(json['account_id']?.toString()),
      alertThreshold: (json['alert_threshold'] as int?) ?? 80,
      active: json['active'] as bool? ?? true,
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> _toStored(Budget budget) {
    return {
      'id': budget.id,
      'name': budget.name,
      'limit_amount': budget.limitAmount,
      'currency': budget.currency,
      'category_id': budget.categoryId,
      'account_id': budget.accountId,
      'alert_threshold': budget.alertThreshold,
      'active': budget.active,
      'created_at': budget.createdAt.toIso8601String(),
    };
  }

  void _emitCache() {
    try {
      _controller.add(List.unmodifiable(_cache));
    } catch (_) {}
  }

  @override
  Future<List<Budget>> getUserBudgets() async {
    try {
      final box = await _budgetsBox();
      final budgets =
          box.values
              .whereType<Map>()
              .map((raw) => _fromStored(Map<String, dynamic>.from(raw)))
              .toList();

      budgets.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _cache
        ..clear()
        ..addAll(budgets);
      _emitCache();

      return List.unmodifiable(_cache);
    } on BudgetException {
      rethrow;
    } catch (_) {
      throw CouldnotFetchBudgets();
    }
  }

  @override
  Future<Budget> createBudget(BudgetCreate create) async {
    try {
      final box = await _budgetsBox();
      final created = Budget(
        id: await _nextBudgetId(),
        name: create.name,
        limitAmount: create.limitAmount,
        currency: create.currency,
        categoryId: _normalizeNullableId(create.categoryId),
        accountId: _normalizeNullableId(create.accountId),
        alertThreshold: create.alertThreshold,
        active: true,
        createdAt: DateTime.now(),
      );

      await box.put(created.id, _toStored(created));

      _cache.insert(0, created);
      _emitCache();

      return created;
    } on BudgetException {
      rethrow;
    } catch (_) {
      throw CouldnotCreateBudget();
    }
  }

  @override
  Future<Budget> getBudget(String id) async {
    try {
      final cached = _cache.where((b) => b.id == id);
      if (cached.isNotEmpty) {
        return cached.first;
      }

      final box = await _budgetsBox();
      final raw = box.get(id);
      if (raw is! Map) {
        throw CouldnotGetBudget();
      }

      final budget = _fromStored(Map<String, dynamic>.from(raw));
      final idx = _cache.indexWhere((b) => b.id == budget.id);
      if (idx == -1) {
        _cache.insert(0, budget);
      } else {
        _cache[idx] = budget;
      }
      _emitCache();

      return budget;
    } on BudgetException {
      rethrow;
    } catch (_) {
      throw CouldnotGetBudget();
    }
  }

  @override
  Future<Budget> updateBudget(String id, BudgetPatch patch) async {
    try {
      final box = await _budgetsBox();
      final raw = box.get(id);
      if (raw is! Map) {
        throw CouldnotUpdateBudget();
      }

      final existing = _fromStored(Map<String, dynamic>.from(raw));
      final updated = Budget(
        id: existing.id,
        name: patch.name ?? existing.name,
        limitAmount: patch.limitAmount ?? existing.limitAmount,
        currency: patch.currency ?? existing.currency,
        categoryId:
            patch.categoryId != null
                ? _normalizeNullableId(patch.categoryId)
                : existing.categoryId,
        accountId:
            patch.accountId != null
                ? _normalizeNullableId(patch.accountId)
                : existing.accountId,
        alertThreshold: patch.alertThreshold ?? existing.alertThreshold,
        active: existing.active,
        createdAt: existing.createdAt,
      );

      await box.put(id, _toStored(updated));

      final idx = _cache.indexWhere((b) => b.id == updated.id);
      if (idx == -1) {
        _cache.insert(0, updated);
      } else {
        _cache[idx] = updated;
      }
      _emitCache();

      return updated;
    } on BudgetException {
      rethrow;
    } catch (_) {
      throw CouldnotUpdateBudget();
    }
  }

  @override
  Future<Budget> deactivateBudget(String id) async {
    try {
      final box = await _budgetsBox();
      final raw = box.get(id);
      if (raw is! Map) {
        throw CouldnotDeactivateBudget();
      }

      final existing = _fromStored(Map<String, dynamic>.from(raw));
      final updated = Budget(
        id: existing.id,
        name: existing.name,
        limitAmount: existing.limitAmount,
        currency: existing.currency,
        categoryId: existing.categoryId,
        accountId: existing.accountId,
        alertThreshold: existing.alertThreshold,
        active: false,
        createdAt: existing.createdAt,
      );

      await box.put(id, _toStored(updated));

      final idx = _cache.indexWhere((b) => b.id == updated.id);
      if (idx == -1) {
        _cache.insert(0, updated);
      } else {
        _cache[idx] = updated;
      }
      _emitCache();

      return updated;
    } on BudgetException {
      rethrow;
    } catch (_) {
      throw CouldnotDeactivateBudget();
    }
  }

  @override
  Future<void> deleteBudget(String id) async {
    try {
      final box = await _budgetsBox();
      await box.delete(id);

      _cache.removeWhere((budget) => budget.id == id);
      _emitCache();
    } on BudgetException {
      rethrow;
    } catch (_) {
      throw CouldnotDeleteBudget();
    }
  }

  @override
  Future<Budget> restoreBudget(String id) async {
    try {
      final box = await _budgetsBox();
      final raw = box.get(id);
      if (raw is! Map) {
        throw CouldnotRestoreBudget();
      }

      final existing = _fromStored(Map<String, dynamic>.from(raw));
      final restored = Budget(
        id: existing.id,
        name: existing.name,
        limitAmount: existing.limitAmount,
        currency: existing.currency,
        categoryId: existing.categoryId,
        accountId: existing.accountId,
        alertThreshold: existing.alertThreshold,
        active: true,
        createdAt: existing.createdAt,
      );

      await box.put(id, _toStored(restored));

      final idx = _cache.indexWhere((b) => b.id == restored.id);
      if (idx == -1) {
        _cache.insert(0, restored);
      } else {
        _cache[idx] = restored;
      }
      _emitCache();

      return restored;
    } on BudgetException {
      rethrow;
    } catch (_) {
      throw CouldnotRestoreBudget();
    }
  }

  @override
  Future<void> clearCache() async {
    _cache.clear();
    _emitCache();
  }

  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
