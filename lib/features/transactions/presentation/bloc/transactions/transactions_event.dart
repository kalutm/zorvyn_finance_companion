import 'package:equatable/equatable.dart';
import 'package:finance_frontend/features/accounts/domain/entities/account.dart';
import 'package:finance_frontend/features/transactions/data/model/dtos/date_range.dart';
import 'package:finance_frontend/features/transactions/domain/entities/transaction.dart';
import 'package:flutter/foundation.dart';

@immutable
abstract class TransactionsEvent extends Equatable {
  const TransactionsEvent();
  @override
  List<Object?> get props => [];
}

class LoadTransactions extends TransactionsEvent {
  const LoadTransactions();
} // when ever the ui needs to load the current user's transactions (List<Transaction>)

class RefreshTransactions extends TransactionsEvent {
  const RefreshTransactions();
} // when ever the ui needs to refresh the current user's transactions (List<Transaction>)

class TransactionFilterChanged extends TransactionsEvent {
  final Account? account;
  const TransactionFilterChanged([this.account]);

  @override
  List<Object?> get props => [account];
}

class TransactionSearchChanged extends TransactionsEvent {
  final String query;
  const TransactionSearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class TransactionDateRangeChanged extends TransactionsEvent {
  final DateRange? range;
  const TransactionDateRangeChanged(this.range);

  @override
  List<Object?> get props => [range?.start, range?.end];
}

class TransactionFiltersCleared extends TransactionsEvent {
  const TransactionFiltersCleared();
}

class TransactionsUpdated extends TransactionsEvent {
  final List<Transaction> transactions;
  const TransactionsUpdated(this.transactions);

  @override
  List<Object?> get props => [transactions];
} // internal event fired when TransactionService emits new list
