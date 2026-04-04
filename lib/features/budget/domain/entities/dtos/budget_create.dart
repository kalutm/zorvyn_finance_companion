class BudgetCreate {
  final String name;
  final String limitAmount;
  final String currency;
  final String? categoryId;
  final String? accountId;
  final int alertThreshold;

  const BudgetCreate({
    required this.name,
    required this.limitAmount,
    required this.currency,
    this.categoryId,
    this.accountId,
    this.alertThreshold = 80,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'limit_amount': limitAmount,
      'currency': currency,
      'category_id': categoryId,
      'account_id': accountId,
      'alert_threshold': alertThreshold,
    };
  }
}
