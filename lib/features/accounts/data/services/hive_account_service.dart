import 'dart:async';

import 'package:finance_frontend/core/storage/hive_bootstrap.dart';
import 'package:finance_frontend/core/storage/hive_box_names.dart';
import 'package:finance_frontend/features/accounts/domain/entities/account.dart';
import 'package:finance_frontend/features/accounts/domain/entities/account_type_enum.dart';
import 'package:finance_frontend/features/accounts/domain/entities/dtos/account_create.dart';
import 'package:finance_frontend/features/accounts/domain/entities/dtos/account_patch.dart';
import 'package:finance_frontend/features/accounts/domain/exceptions/account_exceptions.dart';
import 'package:finance_frontend/features/accounts/domain/service/account_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveAccountService implements AccountService {
  final List<Account> _cachedAccounts = [];
  final StreamController<List<Account>> _controller =
      StreamController<List<Account>>.broadcast();

  @override
  Stream<List<Account>> get accountsStream => _controller.stream;

  Future<Box<dynamic>> _accountsBox() async {
    await HiveBootstrap.ensureInitialized();
    if (Hive.isBoxOpen(HiveBoxNames.accounts)) {
      return Hive.box<dynamic>(HiveBoxNames.accounts);
    }
    return Hive.openBox<dynamic>(HiveBoxNames.accounts);
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

  Future<String> _nextAccountId() async {
    final box = await _metaBox();
    final current = (box.get(HiveBoxNames.accountIdCounter) as int?) ?? 0;
    final next = current + 1;
    await box.put(HiveBoxNames.accountIdCounter, next);
    return next.toString();
  }

  Account _fromStored(Map<String, dynamic> json) {
    return Account(
      id: json['id'].toString(),
      balance: (json['balance'] ?? '0').toString(),
      name: (json['name'] ?? '').toString(),
      type: AccountType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => AccountType.CASH,
      ),
      currency: (json['currency'] ?? 'ETB').toString(),
      active: json['active'] as bool? ?? true,
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> _toStored(Account account) {
    return {
      'id': account.id,
      'balance': account.balance,
      'name': account.name,
      'type': account.type.name,
      'currency': account.currency,
      'active': account.active,
      'created_at': account.createdAt.toIso8601String(),
    };
  }

  void _emitCache() {
    try {
      _controller.add(List.unmodifiable(_cachedAccounts));
    } catch (_) {}
  }

  @override
  Future<List<Account>> getUserAccounts() async {
    try {
      final box = await _accountsBox();
      final accounts =
          box.values
              .whereType<Map>()
              .map((raw) => _fromStored(Map<String, dynamic>.from(raw)))
              .toList();

      accounts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _cachedAccounts
        ..clear()
        ..addAll(accounts);
      _emitCache();

      return List.unmodifiable(_cachedAccounts);
    } on AccountException {
      rethrow;
    } catch (_) {
      throw CouldnotFetchAccounts();
    }
  }

  @override
  Future<Account> createAccount(AccountCreate create) async {
    try {
      final box = await _accountsBox();
      final created = Account(
        id: await _nextAccountId(),
        balance: '0',
        name: create.name,
        type: create.type,
        currency: create.currency,
        active: true,
        createdAt: DateTime.now(),
      );

      await box.put(created.id, _toStored(created));

      _cachedAccounts.insert(0, created);
      _emitCache();

      return created;
    } on AccountException {
      rethrow;
    } catch (_) {
      throw CouldnotCreateAccount();
    }
  }

  @override
  Future<Account> getAccount(String id) async {
    try {
      final cached = _cachedAccounts.where((a) => a.id == id);
      if (cached.isNotEmpty) {
        return cached.first;
      }

      final box = await _accountsBox();
      final raw = box.get(id);
      if (raw is! Map) {
        throw CouldnotGetAccont();
      }

      final account = _fromStored(Map<String, dynamic>.from(raw));
      final idx = _cachedAccounts.indexWhere((a) => a.id == account.id);
      if (idx == -1) {
        _cachedAccounts.insert(0, account);
      } else {
        _cachedAccounts[idx] = account;
      }
      _emitCache();

      return account;
    } on AccountException {
      rethrow;
    } catch (_) {
      throw CouldnotGetAccont();
    }
  }

  @override
  Future<Account> updateAccount(String id, AccountPatch patch) async {
    try {
      final box = await _accountsBox();
      final raw = box.get(id);
      if (raw is! Map) {
        throw CouldnotUpdateAccount();
      }

      final existing = _fromStored(Map<String, dynamic>.from(raw));
      final updated = Account(
        id: existing.id,
        balance: existing.balance,
        name: patch.name ?? existing.name,
        type: patch.type ?? existing.type,
        currency: existing.currency,
        active: existing.active,
        createdAt: existing.createdAt,
      );

      await box.put(id, _toStored(updated));

      final idx = _cachedAccounts.indexWhere((a) => a.id == updated.id);
      if (idx == -1) {
        _cachedAccounts.insert(0, updated);
      } else {
        _cachedAccounts[idx] = updated;
      }
      _emitCache();

      return updated;
    } on AccountException {
      rethrow;
    } catch (_) {
      throw CouldnotUpdateAccount();
    }
  }

  @override
  Future<Account> deactivateAccount(String id) async {
    try {
      final box = await _accountsBox();
      final raw = box.get(id);
      if (raw is! Map) {
        throw CouldnotDeactivateAccount();
      }

      final existing = _fromStored(Map<String, dynamic>.from(raw));
      final updated = Account(
        id: existing.id,
        balance: existing.balance,
        name: existing.name,
        type: existing.type,
        currency: existing.currency,
        active: false,
        createdAt: existing.createdAt,
      );

      await box.put(id, _toStored(updated));

      final idx = _cachedAccounts.indexWhere((a) => a.id == updated.id);
      if (idx == -1) {
        _cachedAccounts.insert(0, updated);
      } else {
        _cachedAccounts[idx] = updated;
      }
      _emitCache();

      return updated;
    } on AccountException {
      rethrow;
    } catch (_) {
      throw CouldnotDeactivateAccount();
    }
  }

  @override
  Future<void> deleteAccount(String id) async {
    try {
      final txBox = await _transactionsBox();
      final hasRelatedTransactions = txBox.values.whereType<Map>().any(
        (raw) => raw['account_id']?.toString() == id,
      );

      if (hasRelatedTransactions) {
        throw CannotDeleteAccountWithTransactions();
      }

      final box = await _accountsBox();
      await box.delete(id);

      _cachedAccounts.removeWhere((account) => account.id == id);
      _emitCache();
    } on AccountException {
      rethrow;
    } catch (_) {
      throw CouldnotDeleteAccount();
    }
  }

  @override
  Future<Account> restoreAccount(String id) async {
    try {
      final box = await _accountsBox();
      final raw = box.get(id);
      if (raw is! Map) {
        throw CouldnotRestoreAccount();
      }

      final existing = _fromStored(Map<String, dynamic>.from(raw));
      final restored = Account(
        id: existing.id,
        balance: existing.balance,
        name: existing.name,
        type: existing.type,
        currency: existing.currency,
        active: true,
        createdAt: existing.createdAt,
      );

      await box.put(id, _toStored(restored));

      final idx = _cachedAccounts.indexWhere((a) => a.id == restored.id);
      if (idx == -1) {
        _cachedAccounts.insert(0, restored);
      } else {
        _cachedAccounts[idx] = restored;
      }
      _emitCache();

      return restored;
    } on AccountException {
      rethrow;
    } catch (_) {
      throw CouldnotRestoreAccount();
    }
  }

  @override
  Future<void> clearCache() async {
    _cachedAccounts.clear();
    _emitCache();
  }

  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
