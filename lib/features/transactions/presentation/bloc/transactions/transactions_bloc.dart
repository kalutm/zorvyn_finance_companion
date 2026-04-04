import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:finance_frontend/features/accounts/domain/entities/account.dart';
import 'package:finance_frontend/features/transactions/data/model/dtos/date_range.dart';
import 'package:finance_frontend/features/transactions/domain/exceptions/transaction_exceptions.dart';
import 'package:finance_frontend/features/transactions/domain/entities/transaction.dart';
import 'package:finance_frontend/features/transactions/domain/service/transaction_service.dart';
import 'package:finance_frontend/features/transactions/presentation/bloc/transactions/transactions_event.dart';
import 'package:finance_frontend/features/transactions/presentation/bloc/transactions/transactions_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TransactionsBloc extends Bloc<TransactionsEvent, TransactionsState> {
  final TransactionService transactionService;
  StreamSubscription<List<Transaction>>? _txSub;

  List<Transaction> _lastTransactions = [];
  Account? _selectedAccount;
  String _searchQuery = '';
  DateRange? _range;

  TransactionsBloc(this.transactionService)
    : super(const TransactionsInitial()) {
    on<LoadTransactions>(_onLoadTransactions, transformer: droppable());
    on<RefreshTransactions>(_onRefreshTransactions, transformer: droppable());
    on<TransactionsUpdated>(_onTransactionsUpdated);
    on<TransactionFilterChanged>(_onTransactionFilterChanged);
    on<TransactionSearchChanged>(_onTransactionSearchChanged);
    on<TransactionDateRangeChanged>(_onTransactionDateRangeChanged);
    on<TransactionFiltersCleared>(_onTransactionFiltersCleared);

    // subscribe to service stream
    _txSub = transactionService.transactionsStream.listen(
      (txs) => add(TransactionsUpdated(txs)),
      onError: (err, st) {
        developer.log(
          'TransactionService stream error',
          error: err,
          stackTrace: st,
        );
      },
    );

    add(const LoadTransactions());
  }

  Future<void> _onLoadTransactions(
    LoadTransactions event,
    Emitter<TransactionsState> emit,
  ) async {
    await _loadFromDataSource(emit, showLoading: true);
  }

  Future<void> _onRefreshTransactions(
    RefreshTransactions event,
    Emitter<TransactionsState> emit,
  ) async {
    await _loadFromDataSource(emit, showLoading: true);
  }

  Future<void> _onTransactionsUpdated(
    TransactionsUpdated event,
    Emitter<TransactionsState> emit,
  ) async {
    await _loadFromDataSource(emit, showLoading: false);
  }

  Future<void> _onTransactionFilterChanged(
    TransactionFilterChanged event,
    Emitter<TransactionsState> emit,
  ) async {
    _selectedAccount = event.account;
    await _loadFromDataSource(emit);
  }

  Future<void> _onTransactionSearchChanged(
    TransactionSearchChanged event,
    Emitter<TransactionsState> emit,
  ) async {
    _searchQuery = event.query.trim();
    await _loadFromDataSource(emit);
  }

  Future<void> _onTransactionDateRangeChanged(
    TransactionDateRangeChanged event,
    Emitter<TransactionsState> emit,
  ) async {
    _range = event.range;
    await _loadFromDataSource(emit);
  }

  Future<void> _onTransactionFiltersCleared(
    TransactionFiltersCleared event,
    Emitter<TransactionsState> emit,
  ) async {
    _searchQuery = '';
    _range = null;
    await _loadFromDataSource(emit);
  }

  Future<void> _loadFromDataSource(
    Emitter<TransactionsState> emit, {
    bool showLoading = false,
  }) async {
    if (showLoading) {
      emit(const TransactionsLoading());
    }

    try {
      final transactions = await transactionService.searchTransactions(
        accountId: _selectedAccount?.id,
        query: _searchQuery,
        range: _range,
      );

      _lastTransactions = transactions;

      emit(
        TransactionsLoaded(
          List.unmodifiable(transactions),
          _selectedAccount,
          _searchQuery,
          _range,
        ),
      );
    } catch (e, st) {
      developer.log('LoadTransactions error', error: e, stackTrace: st);
      emit(
        TransactionOperationFailure(
          transactions: List.unmodifiable(_lastTransactions),
          account: _selectedAccount,
          searchQuery: _searchQuery,
          range: _range,
          message: _mapErrorToMessage(e),
        ),
      );
    }
  }

  String _mapErrorToMessage(Object e) {
    if (e is CouldnotFetchTransactions) {
      return 'Couldnot fetch transactions, please try reloading the page';
    }
    if (e is SocketException) {
      return 'No Internet connection!, please try connecting to the internet';
    }
    return e.toString();
  }

  @override
  Future<void> close() {
    _txSub?.cancel();
    return super.close();
  }
}
