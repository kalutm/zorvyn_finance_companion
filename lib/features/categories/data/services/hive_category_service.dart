import 'dart:async';

import 'package:finance_frontend/core/storage/hive_bootstrap.dart';
import 'package:finance_frontend/core/storage/hive_box_names.dart';
import 'package:finance_frontend/features/categories/domain/entities/category.dart';
import 'package:finance_frontend/features/categories/domain/entities/category_type_enum.dart';
import 'package:finance_frontend/features/categories/domain/entities/dtos/category_create.dart';
import 'package:finance_frontend/features/categories/domain/entities/dtos/category_patch.dart';
import 'package:finance_frontend/features/categories/domain/exceptions/category_exceptions.dart';
import 'package:finance_frontend/features/categories/domain/service/category_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveCategoryService implements CategoryService {
  final List<FinanceCategory> _cache = [];
  final StreamController<List<FinanceCategory>> _controller =
      StreamController<List<FinanceCategory>>.broadcast();

  @override
  Stream<List<FinanceCategory>> get categoriesStream => _controller.stream;

  Future<Box<dynamic>> _categoriesBox() async {
    await HiveBootstrap.ensureInitialized();
    if (Hive.isBoxOpen(HiveBoxNames.categories)) {
      return Hive.box<dynamic>(HiveBoxNames.categories);
    }
    return Hive.openBox<dynamic>(HiveBoxNames.categories);
  }

  Future<Box<dynamic>> _transactionsBox() async {
    await HiveBootstrap.ensureInitialized();
    if (Hive.isBoxOpen(HiveBoxNames.transactions)) {
      return Hive.box<dynamic>(HiveBoxNames.transactions);
    }
    return Hive.openBox<dynamic>(HiveBoxNames.transactions);
  }

  Future<Box<dynamic>> _metaBox() async {
    await HiveBootstrap.ensureInitialized();
    if (Hive.isBoxOpen(HiveBoxNames.meta)) {
      return Hive.box<dynamic>(HiveBoxNames.meta);
    }
    return Hive.openBox<dynamic>(HiveBoxNames.meta);
  }

  Future<String> _nextCategoryId() async {
    final box = await _metaBox();
    final current = (box.get(HiveBoxNames.categoryIdCounter) as int?) ?? 0;
    final next = current + 1;
    await box.put(HiveBoxNames.categoryIdCounter, next);
    return next.toString();
  }

  FinanceCategory _fromStored(Map<String, dynamic> json) {
    return FinanceCategory(
      id: json['id'].toString(),
      name: (json['name'] ?? '').toString(),
      type: CategoryType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => CategoryType.EXPENSE,
      ),
      active: json['active'] as bool? ?? true,
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> _toStored(FinanceCategory category) {
    return {
      'id': category.id,
      'name': category.name,
      'type': category.type.name,
      'active': category.active,
      'created_at': category.createdAt.toIso8601String(),
      'description': category.description,
    };
  }

  void _emitCache() {
    try {
      _controller.add(List.unmodifiable(_cache));
    } catch (_) {}
  }

  @override
  Future<List<FinanceCategory>> getUserCategories() async {
    try {
      final box = await _categoriesBox();
      final categories =
          box.values
              .whereType<Map>()
              .map((raw) => _fromStored(Map<String, dynamic>.from(raw)))
              .toList();

      categories.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _cache
        ..clear()
        ..addAll(categories);
      _emitCache();

      return List.unmodifiable(_cache);
    } on CategoryException {
      rethrow;
    } catch (_) {
      throw CouldnotFetchCategories();
    }
  }

  @override
  Future<FinanceCategory> createCategory(CategoryCreate create) async {
    try {
      final box = await _categoriesBox();
      final created = FinanceCategory(
        id: await _nextCategoryId(),
        name: create.name,
        type: create.type,
        active: true,
        createdAt: DateTime.now(),
        description: create.description,
      );

      await box.put(created.id, _toStored(created));

      _cache.insert(0, created);
      _emitCache();

      return created;
    } on CategoryException {
      rethrow;
    } catch (_) {
      throw CouldnotCreateCategory();
    }
  }

  @override
  Future<FinanceCategory> getCategory(String id) async {
    try {
      final cached = _cache.where((c) => c.id == id);
      if (cached.isNotEmpty) {
        return cached.first;
      }

      final box = await _categoriesBox();
      final raw = box.get(id);
      if (raw is! Map) {
        throw CouldnotGetCategory();
      }

      final category = _fromStored(Map<String, dynamic>.from(raw));
      final idx = _cache.indexWhere((c) => c.id == category.id);
      if (idx == -1) {
        _cache.insert(0, category);
      } else {
        _cache[idx] = category;
      }
      _emitCache();

      return category;
    } on CategoryException {
      rethrow;
    } catch (_) {
      throw CouldnotGetCategory();
    }
  }

  @override
  Future<FinanceCategory> updateCategory(String id, CategoryPatch patch) async {
    try {
      final box = await _categoriesBox();
      final raw = box.get(id);
      if (raw is! Map) {
        throw CouldnotUpdateCategory();
      }

      final existing = _fromStored(Map<String, dynamic>.from(raw));
      final updated = FinanceCategory(
        id: existing.id,
        name: patch.name ?? existing.name,
        type: patch.type ?? existing.type,
        active: existing.active,
        createdAt: existing.createdAt,
        description: patch.description ?? existing.description,
      );

      await box.put(id, _toStored(updated));

      final idx = _cache.indexWhere((c) => c.id == updated.id);
      if (idx == -1) {
        _cache.insert(0, updated);
      } else {
        _cache[idx] = updated;
      }
      _emitCache();

      return updated;
    } on CategoryException {
      rethrow;
    } catch (_) {
      throw CouldnotUpdateCategory();
    }
  }

  @override
  Future<FinanceCategory> deactivateCategory(String id) async {
    try {
      final box = await _categoriesBox();
      final raw = box.get(id);
      if (raw is! Map) {
        throw CouldnotDeactivateCategory();
      }

      final existing = _fromStored(Map<String, dynamic>.from(raw));
      final updated = FinanceCategory(
        id: existing.id,
        name: existing.name,
        type: existing.type,
        active: false,
        createdAt: existing.createdAt,
        description: existing.description,
      );

      await box.put(id, _toStored(updated));

      final idx = _cache.indexWhere((c) => c.id == updated.id);
      if (idx == -1) {
        _cache.insert(0, updated);
      } else {
        _cache[idx] = updated;
      }
      _emitCache();

      return updated;
    } on CategoryException {
      rethrow;
    } catch (_) {
      throw CouldnotDeactivateCategory();
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    try {
      final txBox = await _transactionsBox();
      final hasRelatedTransactions = txBox.values.whereType<Map>().any(
        (raw) => raw['category_id']?.toString() == id,
      );

      if (hasRelatedTransactions) {
        throw CannotDeleteCategoryWithTransactions();
      }

      final box = await _categoriesBox();
      await box.delete(id);

      _cache.removeWhere((category) => category.id == id);
      _emitCache();
    } on CategoryException {
      rethrow;
    } catch (_) {
      throw CouldnotDeleteCategory();
    }
  }

  @override
  Future<FinanceCategory> restoreCategory(String id) async {
    try {
      final box = await _categoriesBox();
      final raw = box.get(id);
      if (raw is! Map) {
        throw CouldnotRestoreCategory();
      }

      final existing = _fromStored(Map<String, dynamic>.from(raw));
      final restored = FinanceCategory(
        id: existing.id,
        name: existing.name,
        type: existing.type,
        active: true,
        createdAt: existing.createdAt,
        description: existing.description,
      );

      await box.put(id, _toStored(restored));

      final idx = _cache.indexWhere((c) => c.id == restored.id);
      if (idx == -1) {
        _cache.insert(0, restored);
      } else {
        _cache[idx] = restored;
      }
      _emitCache();

      return restored;
    } on CategoryException {
      rethrow;
    } catch (_) {
      throw CouldnotRestoreCategory();
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
