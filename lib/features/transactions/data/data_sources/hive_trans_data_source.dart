import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:finance_frontend/core/storage/hive_bootstrap.dart';
import 'package:finance_frontend/core/storage/hive_box_names.dart';
import 'package:finance_frontend/features/transactions/data/model/dtos/date_range.dart';
import 'package:finance_frontend/features/transactions/data/model/dtos/stats_in.dart';
import 'package:finance_frontend/features/transactions/data/model/dtos/time_series_in.dart';
import 'package:finance_frontend/features/transactions/data/model/dtos/transaction_create.dart';
import 'package:finance_frontend/features/transactions/data/model/dtos/transaction_update.dart';
import 'package:finance_frontend/features/transactions/data/model/dtos/transfer_transaction_create.dart';
import 'package:finance_frontend/features/transactions/data/model/list_transactions_in.dart';
import 'package:finance_frontend/features/transactions/data/model/transaction_bulk_result.dart';
import 'package:finance_frontend/features/transactions/data/model/transaction_model.dart';
import 'package:finance_frontend/features/transactions/domain/data_source/trans_data_source.dart';
import 'package:finance_frontend/features/transactions/domain/entities/filter_on_enum.dart';
import 'package:finance_frontend/features/transactions/domain/entities/granulity_enum.dart';
import 'package:finance_frontend/features/transactions/domain/entities/transaction_type.dart';
import 'package:finance_frontend/features/transactions/domain/exceptions/transaction_exceptions.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveTransDataSource implements TransDataSource {
  Future<Box<dynamic>> _transactionsBox() async {
    await HiveBootstrap.ensureInitialized();
    if (Hive.isBoxOpen(HiveBoxNames.transactions)) {
      return Hive.box<dynamic>(HiveBoxNames.transactions);
    }
    return Hive.openBox<dynamic>(HiveBoxNames.transactions);
  }

  Future<Box<dynamic>> _accountsBox() async {
    await HiveBootstrap.ensureInitialized();
    if (Hive.isBoxOpen(HiveBoxNames.accounts)) {
      return Hive.box<dynamic>(HiveBoxNames.accounts);
    }
    return Hive.openBox<dynamic>(HiveBoxNames.accounts);
  }

  Future<Box<dynamic>> _categoriesBox() async {
    await HiveBootstrap.ensureInitialized();
    if (Hive.isBoxOpen(HiveBoxNames.categories)) {
      return Hive.box<dynamic>(HiveBoxNames.categories);
    }
    return Hive.openBox<dynamic>(HiveBoxNames.categories);
  }

  Future<Box<dynamic>> _metaBox() async {
    await HiveBootstrap.ensureInitialized();
    if (Hive.isBoxOpen(HiveBoxNames.meta)) {
      return Hive.box<dynamic>(HiveBoxNames.meta);
    }
    return Hive.openBox<dynamic>(HiveBoxNames.meta);
  }

  Future<String> _nextTransactionId() async {
    final box = await _metaBox();
    final current = (box.get(HiveBoxNames.transactionIdCounter) as int?) ?? 0;
    final next = current + 1;
    await box.put(HiveBoxNames.transactionIdCounter, next);
    return next.toString();
  }

  Decimal _parsePositiveAmount(String value) {
    try {
      final parsed = Decimal.parse(value);
      if (parsed.compareTo(Decimal.zero) <= 0) {
        throw InvalidInputtedAmount();
      }
      return parsed;
    } catch (_) {
      throw InvalidInputtedAmount();
    }
  }

  Decimal _parseAmount(String value) {
    try {
      return Decimal.parse(value);
    } catch (_) {
      throw InvalidInputtedAmount();
    }
  }

  DateTime _toDate(dynamic value, [DateTime? fallback]) {
    return DateTime.tryParse(value?.toString() ?? '') ??
        fallback ??
        DateTime.now();
  }

  TransactionModel _fromStored(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'].toString(),
      amount: (json['amount'] ?? '0').toString(),
      isOutGoing: json['is_outgoing'] as bool?,
      accountId: json['account_id'].toString(),
      categoryId: json['category_id']?.toString(),
      currency: (json['currency'] ?? 'ETB').toString(),
      merchant: json['merchant']?.toString(),
      type: TransactionType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => TransactionType.EXPENSE,
      ),
      description: json['description']?.toString(),
      transferGroupId: json['transfer_group_id']?.toString(),
      createdAt: _toDate(json['created_at']).toIso8601String(),
      occuredAt: _toDate(json['occurred_at']).toIso8601String(),
    );
  }

  Future<Map<String, dynamic>> _requireAccount(
    String accountId,
    TransactionException exception,
  ) async {
    final box = await _accountsBox();
    final raw = box.get(accountId);
    if (raw is! Map) {
      throw exception;
    }
    return Map<String, dynamic>.from(raw);
  }

  Future<void> _saveAccount(Map<String, dynamic> account) async {
    final box = await _accountsBox();
    await box.put(account['id'].toString(), account);
  }

  Decimal _accountBalance(Map<String, dynamic> account) {
    return Decimal.parse((account['balance'] ?? '0').toString());
  }

  void _applyForward(
    Map<String, dynamic> account,
    TransactionType type,
    Decimal amount, {
    bool? isOutGoing,
  }) {
    final current = _accountBalance(account);
    Decimal next = current;

    if (type == TransactionType.INCOME) {
      next = current + amount;
    } else if (type == TransactionType.EXPENSE) {
      if (current.compareTo(amount) < 0) {
        throw AccountBalanceTnsufficient();
      }
      next = current - amount;
    } else {
      if (isOutGoing == true) {
        if (current.compareTo(amount) < 0) {
          throw AccountBalanceTnsufficient();
        }
        next = current - amount;
      } else {
        next = current + amount;
      }
    }

    account['balance'] = next.toString();
  }

  void _applyInverse(
    Map<String, dynamic> account,
    TransactionType type,
    Decimal amount, {
    bool? isOutGoing,
  }) {
    final current = _accountBalance(account);
    Decimal next = current;

    if (type == TransactionType.INCOME) {
      if (current.compareTo(amount) < 0) {
        throw AccountBalanceTnsufficient();
      }
      next = current - amount;
    } else if (type == TransactionType.EXPENSE) {
      next = current + amount;
    } else {
      if (isOutGoing == true) {
        next = current + amount;
      } else {
        if (current.compareTo(amount) < 0) {
          throw AccountBalanceTnsufficient();
        }
        next = current - amount;
      }
    }

    account['balance'] = next.toString();
  }

  List<TransactionModel> _sortedTransactions(
    Iterable<TransactionModel> source,
  ) {
    final list = source.toList();
    list.sort((a, b) => _toDate(b.occuredAt).compareTo(_toDate(a.occuredAt)));
    return list;
  }

  Future<List<TransactionModel>> _allTransactions() async {
    final box = await _transactionsBox();
    return _sortedTransactions(
      box.values.whereType<Map>().map(
        (raw) => _fromStored(Map<String, dynamic>.from(raw)),
      ),
    );
  }

  bool _inRange(DateTime date, DateRange? range) {
    if (range == null) return true;
    if (range.start != null && date.isBefore(range.start!)) {
      return false;
    }
    if (range.end != null && date.isAfter(range.end!)) {
      return false;
    }
    return true;
  }

  bool _isIncomeLike(TransactionModel model) {
    if (model.type == TransactionType.INCOME) return true;
    return model.type == TransactionType.TRANSFER && model.isOutGoing == false;
  }

  bool _isExpenseLike(TransactionModel model) {
    if (model.type == TransactionType.EXPENSE) return true;
    return model.type == TransactionType.TRANSFER && model.isOutGoing == true;
  }

  bool _matchesQuery(TransactionModel transaction, String normalizedQuery) {
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final description = (transaction.description ?? '').toLowerCase();
    final merchant = (transaction.merchant ?? '').toLowerCase();
    final amount = transaction.amount.toLowerCase();

    if (description.contains(normalizedQuery) ||
        merchant.contains(normalizedQuery) ||
        amount.contains(normalizedQuery)) {
      return true;
    }

    try {
      final queryAmount = Decimal.parse(normalizedQuery.replaceAll(',', ''));
      return _parseAmount(transaction.amount) == queryAmount;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _summaryFromTransactions(
    List<TransactionModel> transactions,
  ) {
    Decimal income = Decimal.zero;
    Decimal expense = Decimal.zero;

    for (final tx in transactions) {
      final amount = _parseAmount(tx.amount);
      if (_isIncomeLike(tx)) {
        income += amount;
      } else if (_isExpenseLike(tx)) {
        expense += amount;
      }
    }

    return {
      'total_income': income.toString(),
      'total_expense': expense.toString(),
      'net_savings': (income - expense).toString(),
      'transactions_count': transactions.length,
    };
  }

  @override
  Future<TransactionModel> createTransaction(TransactionCreate create) async {
    try {
      final amount = _parsePositiveAmount(create.amount);
      final account = await _requireAccount(
        create.accountId,
        CouldnotCreateTransaction(),
      );

      _applyForward(account, create.type, amount);

      final model = TransactionModel(
        id: await _nextTransactionId(),
        amount: create.amount,
        accountId: create.accountId,
        categoryId: create.categoryId,
        currency: create.currency,
        merchant: create.merchant,
        type: create.type,
        description: create.description,
        transferGroupId: null,
        isOutGoing: null,
        createdAt: DateTime.now().toIso8601String(),
        occuredAt: create.occuredAt.toIso8601String(),
      );

      final txBox = await _transactionsBox();
      await txBox.put(model.id, model.toJson());
      await _saveAccount(account);

      return model;
    } on TransactionException {
      rethrow;
    } catch (_) {
      throw CouldnotCreateTransaction();
    }
  }

  @override
  Future<(TransactionModel, TransactionModel)> createTransferTransaction(
    TransferTransactionCreate create,
  ) async {
    try {
      final amount = _parsePositiveAmount(create.amount);
      if (create.accountId == create.toAccountId) {
        throw InvalidTransferTransaction();
      }

      final from = await _requireAccount(
        create.accountId,
        CouldnotCreateTransferTransaction(),
      );
      final to = await _requireAccount(
        create.toAccountId,
        CouldnotCreateTransferTransaction(),
      );

      final fromNext = Map<String, dynamic>.from(from);
      final toNext = Map<String, dynamic>.from(to);

      _applyForward(
        fromNext,
        TransactionType.TRANSFER,
        amount,
        isOutGoing: true,
      );
      _applyForward(
        toNext,
        TransactionType.TRANSFER,
        amount,
        isOutGoing: false,
      );

      final transferGroupId =
          'transfer_${DateTime.now().microsecondsSinceEpoch}_${create.accountId}_${create.toAccountId}';
      final occurredAt =
          (create.occurredAt ?? DateTime.now()).toIso8601String();
      final createdAt = DateTime.now().toIso8601String();

      final outgoing = TransactionModel(
        id: await _nextTransactionId(),
        amount: create.amount,
        accountId: create.accountId,
        categoryId: null,
        currency: create.currency,
        merchant: null,
        type: create.type,
        description: create.description,
        transferGroupId: transferGroupId,
        isOutGoing: true,
        createdAt: createdAt,
        occuredAt: occurredAt,
      );

      final incoming = TransactionModel(
        id: await _nextTransactionId(),
        amount: create.amount,
        accountId: create.toAccountId,
        categoryId: null,
        currency: create.currency,
        merchant: null,
        type: create.type,
        description: create.description,
        transferGroupId: transferGroupId,
        isOutGoing: false,
        createdAt: createdAt,
        occuredAt: occurredAt,
      );

      final txBox = await _transactionsBox();
      await txBox.put(outgoing.id, outgoing.toJson());
      await txBox.put(incoming.id, incoming.toJson());

      await _saveAccount(fromNext);
      await _saveAccount(toNext);

      return (outgoing, incoming);
    } on TransactionException {
      rethrow;
    } catch (_) {
      throw CouldnotCreateTransferTransaction();
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    try {
      final txBox = await _transactionsBox();
      final raw = txBox.get(id);
      if (raw is! Map) {
        throw CouldnotDeleteTransaction();
      }

      final tx = _fromStored(Map<String, dynamic>.from(raw));
      final account = await _requireAccount(
        tx.accountId,
        CouldnotDeleteTransaction(),
      );

      _applyInverse(
        account,
        tx.type,
        _parseAmount(tx.amount),
        isOutGoing: tx.isOutGoing,
      );

      await _saveAccount(account);
      await txBox.delete(id);
    } on TransactionException {
      rethrow;
    } catch (_) {
      throw CouldnotDeleteTransaction();
    }
  }

  @override
  Future<void> deleteTransferTransaction(String transferGroupId) async {
    try {
      final txBox = await _transactionsBox();
      final entries =
          txBox.values
              .whereType<Map>()
              .map((raw) => _fromStored(Map<String, dynamic>.from(raw)))
              .where((tx) => tx.transferGroupId == transferGroupId)
              .toList();

      if (entries.isEmpty) {
        throw InvalidTransferTransaction();
      }

      final accountUpdates = <String, Map<String, dynamic>>{};
      for (final tx in entries) {
        final base =
            accountUpdates[tx.accountId] ??
            await _requireAccount(
              tx.accountId,
              CouldnotDeleteTransferTransaction(),
            );
        final working = Map<String, dynamic>.from(base);
        _applyInverse(
          working,
          tx.type,
          _parseAmount(tx.amount),
          isOutGoing: tx.isOutGoing,
        );
        accountUpdates[tx.accountId] = working;
      }

      for (final account in accountUpdates.values) {
        await _saveAccount(account);
      }
      for (final tx in entries) {
        await txBox.delete(tx.id);
      }
    } on TransactionException {
      rethrow;
    } catch (_) {
      throw CouldnotDeleteTransferTransaction();
    }
  }

  @override
  Future<TransactionModel> getTransaction(String id) async {
    try {
      final box = await _transactionsBox();
      final raw = box.get(id);
      if (raw is! Map) {
        throw CouldnotGetTransaction();
      }
      return _fromStored(Map<String, dynamic>.from(raw));
    } on TransactionException {
      rethrow;
    } catch (_) {
      throw CouldnotGetTransaction();
    }
  }

  @override
  Future<List<TransactionModel>> getUserTransactions() async {
    try {
      return await _allTransactions();
    } on TransactionException {
      rethrow;
    } catch (_) {
      throw CouldnotFetchTransactions();
    }
  }

  @override
  Future<List<TransactionModel>> searchTransactions({
    String? accountId,
    String? query,
    DateRange? range,
  }) async {
    try {
      final normalizedQuery = (query ?? '').trim().toLowerCase();

      final filtered =
          (await _allTransactions()).where((transaction) {
            if (accountId != null && transaction.accountId != accountId) {
              return false;
            }

            if (range != null &&
                !_inRange(_toDate(transaction.occuredAt), range)) {
              return false;
            }

            return _matchesQuery(transaction, normalizedQuery);
          }).toList();

      return _sortedTransactions(filtered);
    } on TransactionException {
      rethrow;
    } catch (_) {
      throw CouldnotFetchTransactions();
    }
  }

  @override
  Future<TransactionModel> updateTransaction(
    String id,
    TransactionPatch patch,
  ) async {
    try {
      final txBox = await _transactionsBox();
      final raw = txBox.get(id);
      if (raw is! Map) {
        throw CouldnotUpdateTransaction();
      }

      final existing = _fromStored(Map<String, dynamic>.from(raw));
      if (existing.type == TransactionType.TRANSFER) {
        throw CannotUpdateTransferTransactions();
      }

      final updated = TransactionModel(
        id: existing.id,
        amount: patch.amount ?? existing.amount,
        isOutGoing: existing.isOutGoing,
        accountId: existing.accountId,
        categoryId: patch.categoryId ?? existing.categoryId,
        currency: existing.currency,
        merchant: patch.merchant ?? existing.merchant,
        type: existing.type,
        description: patch.description ?? existing.description,
        transferGroupId: existing.transferGroupId,
        createdAt: existing.createdAt,
        occuredAt:
            (patch.occuredAt ?? _toDate(existing.occuredAt)).toIso8601String(),
      );

      final account = await _requireAccount(
        existing.accountId,
        CouldnotUpdateTransaction(),
      );
      final nextAccount = Map<String, dynamic>.from(account);

      _applyInverse(
        nextAccount,
        existing.type,
        _parseAmount(existing.amount),
        isOutGoing: existing.isOutGoing,
      );
      _applyForward(
        nextAccount,
        updated.type,
        _parsePositiveAmount(updated.amount),
        isOutGoing: updated.isOutGoing,
      );

      await _saveAccount(nextAccount);
      await txBox.put(updated.id, updated.toJson());

      return updated;
    } on TransactionException {
      rethrow;
    } catch (_) {
      throw CouldnotUpdateTransaction();
    }
  }

  @override
  Future<BulkResult> createBulkTransactions(
    List<TransactionCreate> transactions,
  ) async {
    int inserted = 0;
    int skipped = 0;
    final skippedReasons = <String, int>{};

    for (final create in transactions) {
      try {
        await createTransaction(create);
        inserted += 1;
      } on InvalidInputtedAmount {
        skipped += 1;
        skippedReasons['invalid_amount'] =
            (skippedReasons['invalid_amount'] ?? 0) + 1;
      } on AccountBalanceTnsufficient {
        skipped += 1;
        skippedReasons['insufficient_balance'] =
            (skippedReasons['insufficient_balance'] ?? 0) + 1;
      } catch (_) {
        skipped += 1;
        skippedReasons['unknown_error'] =
            (skippedReasons['unknown_error'] ?? 0) + 1;
      }
    }

    return BulkResult(
      statusCode: 201,
      success: true,
      inserted: inserted,
      skipped: skipped,
      skippedReasons: skippedReasons,
    );
  }

  @override
  Future<List<TransactionModel>> listTransactionsForReport(
    ListTransactionsIn listTransactionsIn,
  ) async {
    try {
      var filtered =
          (await _allTransactions()).where((tx) {
            final date = _toDate(tx.occuredAt);
            if (!_inRange(date, listTransactionsIn.range)) {
              return false;
            }
            if (listTransactionsIn.categoryId != null &&
                tx.categoryId != listTransactionsIn.categoryId) {
              return false;
            }
            if (listTransactionsIn.accountId != null &&
                tx.accountId != listTransactionsIn.accountId) {
              return false;
            }
            if (listTransactionsIn.type != null &&
                tx.type != listTransactionsIn.type) {
              return false;
            }
            return true;
          }).toList();

      filtered = _sortedTransactions(filtered);

      final page = listTransactionsIn.page;
      final perPage = listTransactionsIn.perPage;
      if (page != null && perPage != null && page > 0 && perPage > 0) {
        final start = (page - 1) * perPage;
        if (start >= filtered.length) {
          return <TransactionModel>[];
        }
        final end = min(start + perPage, filtered.length);
        filtered = filtered.sublist(start, end);
      }

      return filtered;
    } on TransactionException {
      rethrow;
    } catch (_) {
      throw CouldnotListTransactionsForReport();
    }
  }

  @override
  Future<Map<String, dynamic>> getTransactionSummaryFromMonth(
    String month,
  ) async {
    try {
      final parts = month.split('-');
      if (parts.length != 2) {
        throw CouldnotGenerateTransactionsSummary();
      }

      final year = int.parse(parts[0]);
      final monthValue = int.parse(parts[1]);
      final start = DateTime(year, monthValue, 1);
      final end = DateTime(year, monthValue + 1, 0, 23, 59, 59, 999);

      final transactions =
          (await _allTransactions())
              .where(
                (tx) => _inRange(
                  _toDate(tx.occuredAt),
                  DateRange(start: start, end: end),
                ),
              )
              .toList();
      return _summaryFromTransactions(transactions);
    } on TransactionException {
      rethrow;
    } catch (_) {
      throw CouldnotGenerateTransactionsSummary();
    }
  }

  @override
  Future<Map<String, dynamic>> getTransactionSummaryFromDateRange(
    DateRange range,
  ) async {
    try {
      final transactions =
          (await _allTransactions())
              .where((tx) => _inRange(_toDate(tx.occuredAt), range))
              .toList();
      return _summaryFromTransactions(transactions);
    } on TransactionException {
      rethrow;
    } catch (_) {
      throw CouldnotGenerateTransactionsSummary();
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getTransactionStats(
    StatsIn statsIn,
  ) async {
    try {
      final categoriesBox = await _categoriesBox();
      final accountsBox = await _accountsBox();

      final categoryNames = <String, String>{};
      for (final raw in categoriesBox.values.whereType<Map>()) {
        final map = Map<String, dynamic>.from(raw);
        categoryNames[map['id'].toString()] = (map['name'] ?? '').toString();
      }

      final accountNames = <String, String>{};
      for (final raw in accountsBox.values.whereType<Map>()) {
        final map = Map<String, dynamic>.from(raw);
        accountNames[map['id'].toString()] = (map['name'] ?? '').toString();
      }

      var transactions =
          (await _allTransactions())
              .where((tx) => _inRange(_toDate(tx.occuredAt), statsIn.range))
              .toList();

      if (statsIn.onlyExpense) {
        transactions = transactions.where(_isExpenseLike).toList();
      }

      final groupedTotals = <String, Decimal>{};
      final groupedCount = <String, int>{};
      Decimal total = Decimal.zero;

      for (final tx in transactions) {
        final amount = _parseAmount(tx.amount);

        late final String key;
        if (statsIn.filterOn == FilterOn.category) {
          key =
              tx.categoryId != null
                  ? (categoryNames[tx.categoryId!] ?? 'Uncategorized')
                  : 'Uncategorized';
        } else if (statsIn.filterOn == FilterOn.account) {
          key = accountNames[tx.accountId] ?? 'Unknown Account';
        } else {
          key = tx.type.name;
        }

        groupedTotals[key] = (groupedTotals[key] ?? Decimal.zero) + amount;
        groupedCount[key] = (groupedCount[key] ?? 0) + 1;
        total += amount;
      }

      final totalDouble = double.tryParse(total.toString()) ?? 0;
      final stats =
          groupedTotals.entries.map((entry) {
            final amountDouble = double.tryParse(entry.value.toString()) ?? 0;
            final percentage =
                totalDouble == 0
                    ? '0'
                    : ((amountDouble / totalDouble) * 100).toStringAsFixed(2);
            return {
              'name': entry.key,
              'total': entry.value.toString(),
              'percentage': percentage,
              'transaction_count': groupedCount[entry.key] ?? 0,
            };
          }).toList();

      stats.sort((a, b) {
        final aVal = Decimal.parse((a['total'] ?? '0').toString());
        final bVal = Decimal.parse((b['total'] ?? '0').toString());
        return bVal.compareTo(aVal);
      });

      return stats;
    } on TransactionException {
      rethrow;
    } catch (_) {
      throw CouldnotGenerateTransactionsStats();
    }
  }

  String _bucketKey(DateTime date, Granulity granulity) {
    if (granulity == Granulity.day) {
      return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
    if (granulity == Granulity.month) {
      return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-01';
    }
    final day = DateTime(date.year, date.month, date.day);
    final weekStart = day.subtract(Duration(days: day.weekday - 1));
    return '${weekStart.year.toString().padLeft(4, '0')}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<List<Map<String, dynamic>>> getTransactionTimeSeries(
    TimeSeriesIn timeSeriesIn,
  ) async {
    try {
      final buckets = <String, Map<String, Decimal>>{};

      final transactions =
          (await _allTransactions())
              .where(
                (tx) => _inRange(_toDate(tx.occuredAt), timeSeriesIn.range),
              )
              .toList();

      for (final tx in transactions) {
        final date = _toDate(tx.occuredAt);
        final bucket = _bucketKey(date, timeSeriesIn.granulity);
        final amount = _parseAmount(tx.amount);

        final current =
            buckets[bucket] ??
            {'income': Decimal.zero, 'expense': Decimal.zero};

        if (_isIncomeLike(tx)) {
          current['income'] = (current['income'] ?? Decimal.zero) + amount;
        } else if (_isExpenseLike(tx)) {
          current['expense'] = (current['expense'] ?? Decimal.zero) + amount;
        }

        buckets[bucket] = current;
      }

      final keys = buckets.keys.toList()..sort();
      return keys.map((key) {
        final row = buckets[key]!;
        final income = row['income'] ?? Decimal.zero;
        final expense = row['expense'] ?? Decimal.zero;
        return {
          'date': DateTime.parse(key).toIso8601String(),
          'income': income.toString(),
          'expense': expense.toString(),
          'net': (income - expense).toString(),
        };
      }).toList();
    } on TransactionException {
      rethrow;
    } catch (_) {
      throw CouldnotGenerateTimeSeries();
    }
  }

  @override
  Future<(String, List<Map<String, dynamic>>)> getAccountBalances() async {
    try {
      final accountsBox = await _accountsBox();

      Decimal total = Decimal.zero;
      final accounts = <Map<String, dynamic>>[];

      for (final raw in accountsBox.values.whereType<Map>()) {
        final map = Map<String, dynamic>.from(raw);
        final balance = Decimal.parse((map['balance'] ?? '0').toString());
        total += balance;

        accounts.add({
          'id': int.tryParse(map['id'].toString()) ?? 0,
          'name': (map['name'] ?? '').toString(),
          'balance': balance.toString(),
        });
      }

      return (total.toString(), accounts);
    } on TransactionException {
      rethrow;
    } catch (_) {
      throw CouldnotGetAccountBalances();
    }
  }
}
