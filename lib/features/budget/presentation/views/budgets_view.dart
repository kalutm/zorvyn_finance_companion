import 'package:decimal/decimal.dart';
import 'package:finance_frontend/core/provider/providers.dart';
import 'package:finance_frontend/features/accounts/domain/entities/account.dart';
import 'package:finance_frontend/features/budget/domain/entities/budget.dart';
import 'package:finance_frontend/features/budget/presentation/blocs/budget_form/budget_form_bloc.dart';
import 'package:finance_frontend/features/budget/presentation/blocs/budget_form/budget_form_event.dart';
import 'package:finance_frontend/features/budget/presentation/blocs/budget_form/budget_form_state.dart';
import 'package:finance_frontend/features/budget/presentation/blocs/budgets/budgets_bloc.dart';
import 'package:finance_frontend/features/budget/presentation/blocs/budgets/budgets_event.dart';
import 'package:finance_frontend/features/budget/presentation/blocs/budgets/budgets_state.dart';
import 'package:finance_frontend/features/budget/presentation/components/budget_form_failure_dialog.dart';
import 'package:finance_frontend/features/budget/presentation/components/budget_form_sheet.dart';
import 'package:finance_frontend/features/budget/presentation/components/budget_list_view.dart';
import 'package:finance_frontend/features/categories/domain/entities/category.dart';
import 'package:finance_frontend/features/transactions/data/model/dtos/date_range.dart';
import 'package:finance_frontend/features/transactions/data/model/list_transactions_in.dart';
import 'package:finance_frontend/features/transactions/domain/entities/transaction.dart';
import 'package:finance_frontend/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class BudgetsView extends ConsumerStatefulWidget {
  const BudgetsView({super.key});

  @override
  ConsumerState<BudgetsView> createState() => _BudgetsViewState();
}

class _BudgetsViewState extends ConsumerState<BudgetsView> {
  String _filter = '';
  DateTime _selectedMonth = DateTime.now();
  Future<_BudgetComputedData>? _computedFuture;
  String _computedKey = '';
  List<FinanceCategory> _latestCategories = const [];
  List<Account> _latestAccounts = const [];

  @override
  void initState() {
    super.initState();
    _computedFuture = Future.value(_BudgetComputedData.empty());
  }

  DateRange _monthRange(DateTime date) {
    return DateRange(
      start: DateTime(date.year, date.month, 1),
      end: DateTime(date.year, date.month + 1, 0, 23, 59, 59),
    );
  }

  String _monthLabel(DateTime date) => DateFormat.yMMMM().format(date);

  String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  Decimal _safeDecimal(String value) {
    try {
      return Decimal.parse(value);
    } catch (_) {
      return Decimal.zero;
    }
  }

  bool _txMatchesBudget(Budget budget, Transaction tx) {
    if (budget.categoryId != null && tx.categoryId != budget.categoryId) {
      return false;
    }
    if (budget.accountId != null && tx.accountId != budget.accountId) {
      return false;
    }
    if (tx.currency.toUpperCase() != budget.currency.toUpperCase()) {
      return false;
    }
    return true;
  }

  void _scheduleComputation(List<Budget> budgets) {
    final fingerprint = budgets
        .map(
          (b) =>
              '${b.id}:${b.name}:${b.limitAmount}:${b.active}:${b.categoryId ?? ''}:${b.accountId ?? ''}:${b.alertThreshold}',
        )
        .join('|');
    final nextKey = '${_monthKey(_selectedMonth)}|$fingerprint';

    if (nextKey == _computedKey) {
      return;
    }

    _computedKey = nextKey;
    _computedFuture = _buildComputedData(budgets);
  }

  Future<_BudgetComputedData> _buildComputedData(List<Budget> budgets) async {
    final transactionService = ref.read(transactionServiceProvider);
    final categoryService = ref.read(categoryServiceProvider);
    final accountService = ref.read(accountServiceProvider);

    final range = _monthRange(_selectedMonth);

    final results = await Future.wait([
      transactionService.listTransactionsForReport(
        ListTransactionsIn(range: range),
      ),
      categoryService.getUserCategories(),
      accountService.getUserAccounts(),
    ]);

    final transactions = results[0] as List<Transaction>;
    final categories = results[1] as List<FinanceCategory>;
    final accounts = results[2] as List<Account>;

    final spentByBudgetId = <String, Decimal>{
      for (final budget in budgets) budget.id: Decimal.zero,
    };

    final monthlyExpenses =
        transactions.where((t) => t.type == TransactionType.EXPENSE).toList();

    for (final tx in monthlyExpenses) {
      final txAmount = _safeDecimal(tx.amount);
      for (final budget in budgets) {
        if (!budget.active) {
          continue;
        }
        if (!_txMatchesBudget(budget, tx)) {
          continue;
        }
        spentByBudgetId[budget.id] =
            (spentByBudgetId[budget.id] ?? Decimal.zero) + txAmount;
      }
    }

    final totalBudgetLimitByCurrency = <String, Decimal>{};
    final totalMonthlyExpenseByCurrency = <String, Decimal>{};
    int overLimitCount = 0;
    int warningCount = 0;

    for (final tx in monthlyExpenses) {
      final txCurrency = tx.currency.toUpperCase();
      final txAmount = _safeDecimal(tx.amount);
      totalMonthlyExpenseByCurrency[txCurrency] =
          (totalMonthlyExpenseByCurrency[txCurrency] ?? Decimal.zero) +
          txAmount;
    }

    for (final budget in budgets.where((b) => b.active)) {
      final limit = _safeDecimal(budget.limitAmount);
      final spent = spentByBudgetId[budget.id] ?? Decimal.zero;
      final budgetCurrency = budget.currency.toUpperCase();

      totalBudgetLimitByCurrency[budgetCurrency] =
          (totalBudgetLimitByCurrency[budgetCurrency] ?? Decimal.zero) + limit;
      if (limit <= Decimal.zero) {
        continue;
      }

      if (spent > limit) {
        overLimitCount += 1;
        continue;
      }

      if ((spent * Decimal.fromInt(100)) >=
          (limit * Decimal.fromInt(budget.alertThreshold))) {
        warningCount += 1;
      }
    }

    return _BudgetComputedData(
      spentByBudgetId: spentByBudgetId,
      categoryLabelById: {for (final c in categories) c.id: c.name},
      accountLabelById: {for (final a in accounts) a.id: a.name},
      totalMonthlyExpenseByCurrency: totalMonthlyExpenseByCurrency,
      totalBudgetLimitByCurrency: totalBudgetLimitByCurrency,
      overLimitCount: overLimitCount,
      warningCount: warningCount,
      categories: categories,
      accounts: accounts,
    );
  }

  List<Budget> _applyFilter(List<Budget> budgets, String filter) {
    if (filter.isEmpty) {
      return budgets;
    }

    final lower = filter.toLowerCase();
    return budgets.where((b) => b.name.toLowerCase().contains(lower)).toList();
  }

  Future<void> _refreshBudgets() async {
    _computedKey = '';
    context.read<BudgetsBloc>().add(const RefreshBudgets());
    await Future.delayed(const Duration(milliseconds: 350));
  }

  void _openCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return BlocProvider.value(
          value: context.read<BudgetFormBloc>(),
          child: BudgetFormSheet(
            categories: _latestCategories,
            accounts: _latestAccounts,
          ),
        );
      },
    );
  }

  void _openEditSheet(BuildContext context, Budget budget) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return BlocProvider.value(
          value: context.read<BudgetFormBloc>(),
          child: BudgetFormSheet(
            initialBudget: budget,
            categories: _latestCategories,
            accounts: _latestAccounts,
          ),
        );
      },
    );
  }

  void _confirmDeactivate(BuildContext context, Budget budget) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Deactivate budget'),
          content: Text(
            'Are you sure you want to deactivate "${budget.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.read<BudgetFormBloc>().add(DeactivateBudget(budget.id));
              },
              child: const Text('Deactivate'),
            ),
          ],
        );
      },
    );
  }

  void _confirmRestore(BuildContext context, Budget budget) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Restore budget'),
          content: Text('Restore "${budget.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.read<BudgetFormBloc>().add(RestoreBudget(budget.id));
              },
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete budget'),
          content: const Text(
            'This will permanently delete the budget. Are you sure?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                context.read<BudgetFormBloc>().add(DeleteBudget(id));
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  String _money(Decimal value, String currency) {
    final formatter = NumberFormat.currency(symbol: '$currency ');
    return formatter.format(value.toDouble());
  }

  Widget _buildMonthSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month - 1,
                );
                _computedKey = '';
              });
            },
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          ),
          Expanded(
            child: Text(
              _monthLabel(_selectedMonth),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month + 1,
                );
                _computedKey = '';
              });
            },
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(_BudgetComputedData data, int activeCount) {
    final theme = Theme.of(context);
    final monthlyExpenseChips = _buildCurrencySummaryChips(
      baseLabel: 'Monthly expense',
      totalsByCurrency: data.totalMonthlyExpenseByCurrency,
    );
    final budgetLimitChips = _buildCurrencySummaryChips(
      baseLabel: 'Budgeted limit',
      totalsByCurrency: data.totalBudgetLimitByCurrency,
    );

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budget Tracker',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                ...monthlyExpenseChips,
                ...budgetLimitChips,
                _SummaryChip(label: 'Active budgets', value: '$activeCount'),
                _SummaryChip(
                  label: 'Near threshold',
                  value: '${data.warningCount}',
                ),
                _SummaryChip(
                  label: 'Over limit',
                  value: '${data.overLimitCount}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCurrencySummaryChips({
    required String baseLabel,
    required Map<String, Decimal> totalsByCurrency,
  }) {
    if (totalsByCurrency.isEmpty) {
      return [_SummaryChip(label: baseLabel, value: 'No data')];
    }

    final keys = totalsByCurrency.keys.toList()..sort();
    return keys
        .map(
          (currency) => _SummaryChip(
            label: '$baseLabel ($currency)',
            value: _money(totalsByCurrency[currency] ?? Decimal.zero, currency),
          ),
        )
        .toList();
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
      child: TextField(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded),
          hintText: 'Search budgets',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _filter = value.trim();
          });
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return BlocBuilder<BudgetsBloc, BudgetsState>(
      builder: (context, state) {
        if (state is BudgetsLoading || state is BudgetsInitial) {
          return const Center(child: CircularProgressIndicator());
        }

        final allBudgets =
            state is BudgetsLoaded
                ? state.budgets
                : (state as BudgetsOperationFailure).budgets;
        final filtered = _applyFilter(allBudgets, _filter);

        _scheduleComputation(allBudgets);

        return FutureBuilder<_BudgetComputedData>(
          future: _computedFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data ?? _BudgetComputedData.empty();
            _latestCategories = data.categories;
            _latestAccounts = data.accounts;

            final activeCount = allBudgets.where((b) => b.active).length;

            return RefreshIndicator(
              onRefresh: _refreshBudgets,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildMonthSelector()),
                  SliverToBoxAdapter(
                    child: _buildSummaryCard(data, activeCount),
                  ),
                  SliverToBoxAdapter(child: _buildSearchBar()),
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          allBudgets.isEmpty
                              ? 'No budgets found. Tap + to create one.'
                              : 'No budgets match your search.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      sliver: BudgetListView(
                        budgets: filtered,
                        spentByBudgetId: data.spentByBudgetId,
                        categoryLabelById: data.categoryLabelById,
                        accountLabelById: data.accountLabelById,
                        onEdit: _openEditSheet,
                        onDeactivate: _confirmDeactivate,
                        onRestore: _confirmRestore,
                        onDelete: _confirmDelete,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 90)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<BudgetsBloc, BudgetsState>(
          listener: (context, state) {
            if (state is BudgetsOperationFailure) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message)));
            }
          },
        ),
        BlocListener<BudgetFormBloc, BudgetFormState>(
          listener: (context, state) {
            if (state is BudgetOperationSuccess) {
              final op = state.operationType;
              final opName = op.toString().split('.').last;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Budget ${opName}d successfully')),
              );
            } else if (state is BudgetDeleteOperationSuccess) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Budget deleted')));
            } else if (state is BudgetOperationFailure) {
              showDialog(
                context: context,
                builder: (_) => BudgetFailureDialog(message: state.message),
              );
            }
          },
        ),
      ],
      child: Scaffold(
        body: SafeArea(child: _buildBody(context)),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openCreateSheet(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Budget'),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: theme.colorScheme.primary.withAlpha(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(170),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetComputedData {
  final Map<String, Decimal> spentByBudgetId;
  final Map<String, String> categoryLabelById;
  final Map<String, String> accountLabelById;
  final Map<String, Decimal> totalMonthlyExpenseByCurrency;
  final Map<String, Decimal> totalBudgetLimitByCurrency;
  final int overLimitCount;
  final int warningCount;
  final List<FinanceCategory> categories;
  final List<Account> accounts;

  _BudgetComputedData({
    required this.spentByBudgetId,
    required this.categoryLabelById,
    required this.accountLabelById,
    required this.totalMonthlyExpenseByCurrency,
    required this.totalBudgetLimitByCurrency,
    required this.overLimitCount,
    required this.warningCount,
    required this.categories,
    required this.accounts,
  });

  factory _BudgetComputedData.empty() {
    return _BudgetComputedData(
      spentByBudgetId: {},
      categoryLabelById: {},
      accountLabelById: {},
      totalMonthlyExpenseByCurrency: {},
      totalBudgetLimitByCurrency: {},
      overLimitCount: 0,
      warningCount: 0,
      categories: [],
      accounts: [],
    );
  }
}
