import 'package:equatable/equatable.dart';
import 'package:finance_frontend/features/accounts/domain/entities/account.dart';
import 'package:finance_frontend/features/transactions/data/model/dtos/date_range.dart';
import 'package:finance_frontend/features/transactions/domain/entities/transaction.dart';
import 'package:flutter/foundation.dart';

@immutable
abstract class TransactionsState extends Equatable {
  const TransactionsState();
  @override
  List<Object?> get props => [];
}

class TransactionsInitial extends TransactionsState {
  const TransactionsInitial();
} // when the transaction(home) page is loading before any operation

class TransactionsLoading extends TransactionsState {
  const TransactionsLoading();
} // when the service is loading current user's transactions (List<Transaction>)

class TransactionsLoaded extends TransactionsState {
  final Account? account; // keep for convenience in UI
  final List<Transaction> transactions;
  final String searchQuery;
  final DateRange? range;

  const TransactionsLoaded(
    this.transactions, [
    this.account,
    this.searchQuery = '',
    this.range,
  ]);

  @override
  List<Object?> get props => [
    transactions,
    // use account id and balance so changes to the account's balance are detected
    account?.id,
    account?.balance,
    searchQuery,
    range?.start,
    range?.end,
  ];
} // when the service has finished loading the current user's transactions (List<Transaction>)

class TransactionOperationFailure extends TransactionsState {
  final List<Transaction> transactions;
  final String message;
  final Account? account;
  final String searchQuery;
  final DateRange? range;

  const TransactionOperationFailure({
    required this.message,
    required this.transactions,
    this.account,
    this.searchQuery = '',
    this.range,
  });

  @override
  List<Object?> get props => [
    message,
    transactions,
    account?.id,
    account?.balance,
    searchQuery,
    range?.start,
    range?.end,
  ];
} // when any operation has failed
