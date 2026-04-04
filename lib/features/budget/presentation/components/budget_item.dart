import 'package:decimal/decimal.dart';
import 'package:finance_frontend/features/budget/domain/entities/budget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BudgetItem extends StatelessWidget {
  final Budget budget;
  final Decimal spent;
  final String categoryLabel;
  final String accountLabel;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const BudgetItem({
    required this.budget,
    required this.spent,
    required this.categoryLabel,
    required this.accountLabel,
    required this.onEdit,
    required this.onDeactivate,
    required this.onRestore,
    required this.onDelete,
    super.key,
  });

  Decimal get _limit => budget.limitAmountValue;

  Decimal get _remaining => _limit - spent;

  double get _progress {
    if (_limit <= Decimal.zero) return 0;
    final ratio = (spent / _limit).toDouble();
    if (ratio.isNaN || ratio.isInfinite) return 0;
    if (ratio < 0) return 0;
    if (ratio > 1) return 1;
    return ratio;
  }

  bool get _isOverLimit => spent > _limit;

  bool get _isWarning {
    if (_isOverLimit || _limit <= Decimal.zero) {
      return false;
    }
    return (spent * Decimal.fromInt(100)) >=
        (_limit * Decimal.fromInt(budget.alertThreshold));
  }

  Color _statusColor(ThemeData theme) {
    if (_isOverLimit) return theme.colorScheme.error;
    if (_isWarning) return Colors.orange;
    return Colors.green;
  }

  String _money(String value, String currency) {
    final parsed = double.tryParse(value) ?? 0;
    final formatter = NumberFormat.currency(symbol: '$currency ');
    return formatter.format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(theme);
    final isActive = budget.active;

    return Opacity(
      opacity: isActive ? 1 : 0.55,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      budget.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withAlpha(30),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Inactive',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      switch (v) {
                        case 'edit':
                          onEdit();
                          break;
                        case 'deactivate':
                          onDeactivate();
                          break;
                        case 'restore':
                          onRestore();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (ctx) {
                      return [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        if (budget.active)
                          const PopupMenuItem(
                            value: 'deactivate',
                            child: Text('Deactivate'),
                          ),
                        if (!budget.active)
                          const PopupMenuItem(
                            value: 'restore',
                            child: Text('Restore'),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ];
                    },
                  ),
                ],
              ),
              Text(
                'Category: $categoryLabel | Account: $accountLabel',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(178),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MoneyTile(
                      label: 'Limit',
                      value: _money(_limit.toString(), budget.currency),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MoneyTile(
                      label: 'Spent',
                      value: _money(spent.toString(), budget.currency),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MoneyTile(
                      label: _remaining >= Decimal.zero ? 'Left' : 'Over',
                      value: _money(
                        _remaining.abs().toString(),
                        budget.currency,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: _progress,
                  color: statusColor,
                  backgroundColor: theme.colorScheme.outlineVariant.withAlpha(
                    80,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isOverLimit
                    ? 'Over budget'
                    : _isWarning
                    ? 'Warning: passed ${budget.alertThreshold}%'
                    : 'On track',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoneyTile extends StatelessWidget {
  final String label;
  final String value;

  const _MoneyTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(170),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
