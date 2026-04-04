import 'package:decimal/decimal.dart';

class Budget {
  final String id;
  final String name;
  final String limitAmount;
  final String currency;
  final String? categoryId;
  final String? accountId;
  final int alertThreshold;
  final bool active;
  final DateTime createdAt;

  Decimal get limitAmountValue => Decimal.parse(limitAmount);

  Budget({
    required this.id,
    required this.name,
    required this.limitAmount,
    required this.currency,
    this.categoryId,
    this.accountId,
    required this.alertThreshold,
    required this.active,
    required this.createdAt,
  });

  factory Budget.fromFinance(Map<String, dynamic> json) {
    return Budget(
      id: (json['id'] as int).toString(),
      name: json['name'] as String,
      limitAmount: json['limit_amount'] as String,
      currency: json['currency'] as String,
      categoryId:
          json['category_id'] != null
              ? (json['category_id'] as int).toString()
              : null,
      accountId:
          json['account_id'] != null
              ? (json['account_id'] as int).toString()
              : null,
      alertThreshold: json['alert_threshold'] as int,
      active: json['active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toFinance() {
    return {
      'id': id,
      'name': name,
      'limit_amount': limitAmount,
      'currency': currency,
      'category_id': categoryId,
      'account_id': accountId,
      'alert_threshold': alertThreshold,
      'active': active,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
