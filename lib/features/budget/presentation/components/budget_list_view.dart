import 'package:decimal/decimal.dart';
import 'package:finance_frontend/features/budget/domain/entities/budget.dart';
import 'package:finance_frontend/features/budget/presentation/components/budget_item.dart';
import 'package:flutter/material.dart';

typedef BudgetFormCallback = void Function(BuildContext context, Budget budget);
typedef DeleteFormCallback = void Function(BuildContext context, String id);

class BudgetListView extends StatelessWidget {
  final List<Budget> budgets;
  final Map<String, Decimal> spentByBudgetId;
  final Map<String, String> categoryLabelById;
  final Map<String, String> accountLabelById;
  final BudgetFormCallback onEdit;
  final BudgetFormCallback onDeactivate;
  final BudgetFormCallback onRestore;
  final DeleteFormCallback onDelete;

  const BudgetListView({
    super.key,
    required this.budgets,
    required this.spentByBudgetId,
    required this.categoryLabelById,
    required this.accountLabelById,
    required this.onEdit,
    required this.onDeactivate,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, idx) {
        final budget = budgets[idx];
        final spent = spentByBudgetId[budget.id] ?? Decimal.zero;
        final categoryLabel =
            budget.categoryId == null
                ? 'All categories'
                : (categoryLabelById[budget.categoryId] ?? 'Unknown category');
        final accountLabel =
            budget.accountId == null
                ? 'All accounts'
                : (accountLabelById[budget.accountId] ?? 'Unknown account');

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: BudgetItem(
            budget: budget,
            spent: spent,
            categoryLabel: categoryLabel,
            accountLabel: accountLabel,
            onEdit: () => onEdit(context, budget),
            onDeactivate: () => onDeactivate(context, budget),
            onRestore: () => onRestore(context, budget),
            onDelete: () => onDelete(context, budget.id),
          ),
        );
      }, childCount: budgets.length),
    );
  }
}
