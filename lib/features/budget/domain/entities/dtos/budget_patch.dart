class BudgetPatch {
  final String? name;
  final String? limitAmount;
  final String? currency;
  final String? categoryId;
  final String? accountId;
  final int? alertThreshold;

  const BudgetPatch({
    this.name,
    this.limitAmount,
    this.currency,
    this.categoryId,
    this.accountId,
    this.alertThreshold,
  });

  bool get isEmpty =>
      name == null &&
      limitAmount == null &&
      currency == null &&
      categoryId == null &&
      accountId == null &&
      alertThreshold == null;

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (limitAmount != null) 'limit_amount': limitAmount,
      if (currency != null) 'currency': currency,
      if (categoryId != null) 'category_id': categoryId,
      if (accountId != null) 'account_id': accountId,
      if (alertThreshold != null) 'alert_threshold': alertThreshold,
    };
  }
}
