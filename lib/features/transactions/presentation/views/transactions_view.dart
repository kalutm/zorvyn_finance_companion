import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:finance_frontend/features/accounts/domain/entities/account.dart';
import 'package:finance_frontend/features/accounts/domain/utils/account_icom_map.dart';
import 'package:finance_frontend/features/accounts/presentation/blocs/accounts/accounts_bloc.dart';
import 'package:finance_frontend/features/accounts/presentation/blocs/accounts/accounts_state.dart';
import 'package:finance_frontend/features/categories/presentation/blocs/categories/categories_bloc.dart';
import 'package:finance_frontend/features/categories/presentation/blocs/categories/categories_state.dart';
import 'package:finance_frontend/features/transactions/data/model/dtos/date_range.dart';
import 'package:finance_frontend/features/transactions/domain/entities/transaction.dart';
import 'package:finance_frontend/features/transactions/domain/entities/transaction_type.dart';
import 'package:finance_frontend/features/transactions/presentation/bloc/transaction_form/transaction_form_bloc.dart';
import 'package:finance_frontend/features/transactions/presentation/bloc/transactions/transactions_bloc.dart';
import 'package:finance_frontend/features/transactions/presentation/bloc/transactions/transactions_event.dart';
import 'package:finance_frontend/features/transactions/presentation/bloc/transactions/transactions_state.dart';
import 'package:finance_frontend/features/transactions/presentation/components/balance_card.dart';
import 'package:finance_frontend/features/transactions/presentation/components/transaction_list_item.dart';
import 'package:finance_frontend/features/transactions/presentation/views/transaction_form_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class TransactionsView extends StatefulWidget {
  const TransactionsView({super.key});

  @override
  State<TransactionsView> createState() => _TransactionsViewState();
}

class _TransactionsViewState extends State<TransactionsView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  int _selectedInsightIndex = 0;
  bool _showAllRecent = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      context.read<TransactionsBloc>().add(TransactionSearchChanged(query));
    });
  }

  Future<void> _pickDateRange(DateRange? currentRange) async {
    final now = DateTime.now();
    final initial =
        currentRange != null &&
                currentRange.start != null &&
                currentRange.end != null
            ? DateTimeRange(start: currentRange.start!, end: currentRange.end!)
            : null;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDateRange: initial,
      helpText: 'Filter Transactions',
      saveText: 'Apply',
    );

    if (!mounted || picked == null) {
      return;
    }

    context.read<TransactionsBloc>().add(
      TransactionDateRangeChanged(
        DateRange(start: picked.start, end: picked.end),
      ),
    );
  }

  void _showTransactionForm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (modalContext) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: context.read<TransactionFormBloc>()),
                BlocProvider.value(value: context.read<AccountsBloc>()),
                BlocProvider.value(value: context.read<CategoriesBloc>()),
              ],
              child: const TransactionFormModal(),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: _buildAccountSelector(context, theme),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Transactions',
            onPressed: () {
              context.read<TransactionsBloc>().add(const RefreshTransactions());
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocConsumer<TransactionsBloc, TransactionsState>(
        listener: (context, state) {
          if (state is TransactionOperationFailure) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          if (state is TransactionsInitial || state is TransactionsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          List<Transaction> transactions = [];
          Account? selectedAccount;
          String searchQuery = '';
          DateRange? selectedRange;

          if (state is TransactionsLoaded) {
            transactions = state.transactions;
            selectedAccount = state.account;
            searchQuery = state.searchQuery;
            selectedRange = state.range;
          } else if (state is TransactionOperationFailure) {
            transactions = state.transactions;
            selectedAccount = state.account;
            searchQuery = state.searchQuery;
            selectedRange = state.range;
          }

          if (_searchController.text != searchQuery) {
            _searchController.value = TextEditingValue(
              text: searchQuery,
              selection: TextSelection.collapsed(offset: searchQuery.length),
            );
          }

          final metrics = _buildMetrics(transactions);
          final trend = _buildWeeklyTrend(transactions);

          return RefreshIndicator(
            onRefresh: () async {
              context.read<TransactionsBloc>().add(const RefreshTransactions());
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
              children: [
                _buildSearchAndFilters(theme, searchQuery, selectedRange),
                const SizedBox(height: 14),
                BlocBuilder<AccountsBloc, AccountsState>(
                  builder: (accountsContext, accountsState) {
                    final balanceData = _calculateTotalBalanceFromState(
                      accountsState,
                      selectedAccount,
                    );

                    return BalanceCard(
                      accountName: selectedAccount?.name ?? 'All Accounts',
                      currentBalance: balanceData['balance']!,
                      currency: balanceData['currency']!,
                      isTotalBalance: selectedAccount == null,
                    );
                  },
                ),
                _OverviewMetricsSection(metrics: metrics),
                const SizedBox(height: 16),
                BlocBuilder<CategoriesBloc, CategoriesState>(
                  builder: (context, categoriesState) {
                    final categoryNames = _categoryNames(categoriesState);
                    final breakdown = _buildCategoryBreakdown(
                      transactions,
                      categoryNames,
                    );
                    return _InsightsSection(
                      selectedIndex: _selectedInsightIndex,
                      onSelected: (index) {
                        setState(() {
                          _selectedInsightIndex = index;
                        });
                      },
                      trendPoints: trend,
                      breakdownItems: breakdown,
                      currency: metrics.currency,
                    );
                  },
                ),
                const SizedBox(height: 20),
                _RecentActivitySection(
                  transactions: transactions,
                  selectedAccount: selectedAccount,
                  showAll: _showAllRecent,
                  onToggle: () {
                    setState(() {
                      _showAllRecent = !_showAllRecent;
                    });
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTransactionForm(context),
        label: const Text('New Transaction'),
        icon: const Icon(Icons.add),
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: theme.colorScheme.onSecondary,
      ),
    );
  }

  Widget _buildSearchAndFilters(
    ThemeData theme,
    String searchQuery,
    DateRange? selectedRange,
  ) {
    final hasFilters = searchQuery.isNotEmpty || selectedRange != null;
    final rangeLabel =
        selectedRange == null
            ? 'Any Date'
            : '${DateFormat.yMd().format(selectedRange.start!)} - ${DateFormat.yMd().format(selectedRange.end!)}';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'description, merchant, or amount',
                suffixIcon:
                    searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchController.clear();
                            context.read<TransactionsBloc>().add(
                              const TransactionSearchChanged(''),
                            );
                          },
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDateRange(selectedRange),
                    icon: const Icon(Icons.date_range_rounded),
                    label: Text(rangeLabel, overflow: TextOverflow.ellipsis),
                  ),
                ),
                if (selectedRange != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Clear date range',
                    onPressed: () {
                      context.read<TransactionsBloc>().add(
                        const TransactionDateRangeChanged(null),
                      );
                    },
                    icon: const Icon(Icons.event_busy_rounded),
                  ),
                ],
                if (hasFilters) ...[
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                      context.read<TransactionsBloc>().add(
                        const TransactionFiltersCleared(),
                      );
                    },
                    child: const Text('Clear All'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSelector(BuildContext context, ThemeData theme) {
    return BlocBuilder<AccountsBloc, AccountsState>(
      builder: (accountsContext, accountsState) {
        if (accountsState is AccountsLoaded) {
          final allAccounts = accountsState.accounts;
          final List<Account?> displayAccounts = [null, ...allAccounts];

          return BlocBuilder<TransactionsBloc, TransactionsState>(
            buildWhen: (p, c) {
              final pId = (p is TransactionsLoaded ? p.account?.id : null);
              final cId = (c is TransactionsLoaded ? c.account?.id : null);
              if (p.runtimeType != c.runtimeType) return true;
              return pId != cId;
            },
            builder: (txContext, txState) {
              Account? selectedAccountFromTx;
              if (txState is TransactionsLoaded) {
                selectedAccountFromTx = txState.account;
              } else if (txState is TransactionOperationFailure) {
                selectedAccountFromTx = txState.account;
              }

              Account? dropdownValue = displayAccounts.firstWhere(
                (a) => a?.id == selectedAccountFromTx?.id,
                orElse: () => selectedAccountFromTx,
              );

              if (!displayAccounts.contains(dropdownValue)) {
                dropdownValue = null;
              }

              return DropdownButtonHideUnderline(
                child: DropdownButton<Account?>(
                  value: dropdownValue,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: theme.colorScheme.onPrimary,
                  ),
                  dropdownColor: theme.colorScheme.surface,
                  hint: Text(
                    'All Accounts',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  selectedItemBuilder: (_) {
                    return displayAccounts.map((account) {
                      final name = account?.name ?? 'All Accounts';
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            account?.displayIcon ??
                                Icons.account_balance_wallet_rounded,
                            color: theme.colorScheme.onPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                  onChanged: (Account? newAccount) {
                    txContext.read<TransactionsBloc>().add(
                      TransactionFilterChanged(newAccount),
                    );
                  },
                  items:
                      displayAccounts.map((account) {
                        final name = account?.name ?? 'All Accounts';
                        final bool isSelected =
                            account?.id == selectedAccountFromTx?.id;

                        return DropdownMenuItem<Account?>(
                          value: account,
                          child: Row(
                            children: [
                              Icon(
                                account?.displayIcon ??
                                    Icons.account_balance_wallet_rounded,
                                color:
                                    isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface.withAlpha(
                                          178,
                                        ),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color:
                                      isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                ),
              );
            },
          );
        }
        return Text(
          'All Accounts',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }

  Map<String, String> _calculateTotalBalanceFromState(
    AccountsState accountsState,
    Account? selectedAccount,
  ) {
    Decimal totalBalance = Decimal.zero;
    String currency = 'MIX';

    List<Account> accountsList = [];
    if (accountsState is AccountsLoaded) {
      accountsList = accountsState.accounts;
    } else if (accountsState is AccountOperationFailure) {
      accountsList = accountsState.accounts;
    }

    if (selectedAccount != null) {
      try {
        final currAccount = accountsList.firstWhere(
          (a) => a.id == selectedAccount.id,
        );
        totalBalance = currAccount.balanceValue;
        currency = currAccount.currency;
      } catch (_) {
        try {
          totalBalance = selectedAccount.balanceValue;
          currency = selectedAccount.currency;
        } catch (_) {
          return {'balance': 'Error', 'currency': selectedAccount.currency};
        }
      }
    } else {
      if (accountsList.isNotEmpty) {
        currency = accountsList.first.currency;
      }
      for (final account in accountsList) {
        totalBalance += account.balanceValue;
      }
    }

    return {'balance': totalBalance.toStringAsFixed(2), 'currency': currency};
  }

  _DashboardMetrics _buildMetrics(List<Transaction> transactions) {
    Decimal income = Decimal.zero;
    Decimal expense = Decimal.zero;
    String currency =
        transactions.isNotEmpty ? transactions.first.currency : 'ETB';

    for (final tx in transactions) {
      if (tx.type == TransactionType.INCOME) {
        income += tx.amountValue;
      } else if (tx.type == TransactionType.EXPENSE) {
        expense += tx.amountValue;
      }
    }

    return _DashboardMetrics(
      income: income,
      expense: expense,
      currency: currency,
      transactionsCount: transactions.length,
    );
  }

  List<_TrendPoint> _buildWeeklyTrend(List<Transaction> transactions) {
    final now = DateTime.now();
    final days = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day - (6 - i)),
    );

    final incomeByDay = <DateTime, Decimal>{
      for (final day in days) day: Decimal.zero,
    };
    final expenseByDay = <DateTime, Decimal>{
      for (final day in days) day: Decimal.zero,
    };

    for (final tx in transactions) {
      final day = DateTime(
        tx.occuredAt.year,
        tx.occuredAt.month,
        tx.occuredAt.day,
      );
      if (!incomeByDay.containsKey(day)) {
        continue;
      }

      if (tx.type == TransactionType.INCOME) {
        incomeByDay[day] = (incomeByDay[day] ?? Decimal.zero) + tx.amountValue;
      } else if (tx.type == TransactionType.EXPENSE) {
        expenseByDay[day] =
            (expenseByDay[day] ?? Decimal.zero) + tx.amountValue;
      }
    }

    return days.map((day) {
      final income = incomeByDay[day] ?? Decimal.zero;
      final expense = expenseByDay[day] ?? Decimal.zero;
      return _TrendPoint(
        date: day,
        income: double.tryParse(income.toString()) ?? 0,
        expense: double.tryParse(expense.toString()) ?? 0,
      );
    }).toList();
  }

  Map<String, String> _categoryNames(CategoriesState state) {
    if (state is CategoriesLoaded) {
      return {for (final c in state.categories) c.id: c.name};
    }
    if (state is CategoriesOperationFailure) {
      return {for (final c in state.categories) c.id: c.name};
    }
    return {};
  }

  List<_BreakdownItem> _buildCategoryBreakdown(
    List<Transaction> transactions,
    Map<String, String> categoryNames,
  ) {
    final totals = <String, Decimal>{};
    final counts = <String, int>{};

    for (final tx in transactions) {
      if (tx.type != TransactionType.EXPENSE) {
        continue;
      }

      final label =
          tx.categoryId != null
              ? (categoryNames[tx.categoryId!] ?? 'Category ${tx.categoryId}')
              : 'Uncategorized';

      totals[label] = (totals[label] ?? Decimal.zero) + tx.amountValue;
      counts[label] = (counts[label] ?? 0) + 1;
    }

    final items =
        totals.entries
            .map(
              (entry) => _BreakdownItem(
                label: entry.key,
                total: entry.value,
                count: counts[entry.key] ?? 0,
              ),
            )
            .toList();

    items.sort((a, b) => b.total.compareTo(a.total));
    return items.take(5).toList();
  }
}

class _OverviewMetricsSection extends StatelessWidget {
  final _DashboardMetrics metrics;

  const _OverviewMetricsSection({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final savingsColor =
        metrics.savings.sign >= 0 ? Colors.green : Colors.redAccent;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _MiniMetric(
                    label: 'Income',
                    value: _formatMoney(metrics.income, metrics.currency),
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniMetric(
                    label: 'Expense',
                    value: _formatMoney(metrics.expense, metrics.currency),
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniMetric(
                    label: 'Savings',
                    value: _formatMoney(metrics.savings, metrics.currency),
                    color: savingsColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurface.withAlpha(170),
                ),
                const SizedBox(width: 6),
                Text(
                  '${metrics.transactionsCount} transactions',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(178),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: metrics.savingsRate,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsSection extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<_TrendPoint> trendPoints;
  final List<_BreakdownItem> breakdownItems;
  final String currency;

  const _InsightsSection({
    required this.selectedIndex,
    required this.onSelected,
    required this.trendPoints,
    required this.breakdownItems,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Trend')),
            ButtonSegment(value: 1, label: Text('Categories')),
          ],
          selected: {selectedIndex},
          onSelectionChanged: (selected) {
            onSelected(selected.first);
          },
        ),
        const SizedBox(height: 10),
        if (selectedIndex == 0)
          _WeeklyTrendSection(points: trendPoints, currency: currency)
        else
          _CategoryBreakdownSection(items: breakdownItems, currency: currency),
      ],
    );
  }
}

class _WeeklyTrendSection extends StatelessWidget {
  final List<_TrendPoint> points;
  final String currency;

  const _WeeklyTrendSection({required this.points, required this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Trend',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Income vs expenses for the last 7 days',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(178),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 210,
              child: SfCartesianChart(
                margin: EdgeInsets.zero,
                plotAreaBorderWidth: 0,
                legend: const Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                ),
                primaryXAxis: DateTimeAxis(
                  intervalType: DateTimeIntervalType.days,
                  dateFormat: DateFormat.E(),
                  majorGridLines: const MajorGridLines(width: 0),
                ),
                primaryYAxis: NumericAxis(
                  numberFormat: NumberFormat.compactCurrency(
                    symbol: '$currency ',
                  ),
                  majorGridLines: MajorGridLines(
                    width: 0.7,
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                series: <CartesianSeries<_TrendPoint, DateTime>>[
                  ColumnSeries<_TrendPoint, DateTime>(
                    dataSource: points,
                    xValueMapper: (p, _) => p.date,
                    yValueMapper: (p, _) => p.income,
                    name: 'Income',
                    color: Colors.green.withAlpha(178),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                  ColumnSeries<_TrendPoint, DateTime>(
                    dataSource: points,
                    xValueMapper: (p, _) => p.date,
                    yValueMapper: (p, _) => p.expense,
                    name: 'Expense',
                    color: Colors.redAccent.withAlpha(178),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                  SplineSeries<_TrendPoint, DateTime>(
                    dataSource: points,
                    xValueMapper: (p, _) => p.date,
                    yValueMapper: (p, _) => p.net,
                    name: 'Net',
                    color: theme.colorScheme.primary,
                    width: 2,
                    markerSettings: const MarkerSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBreakdownSection extends StatelessWidget {
  final List<_BreakdownItem> items;
  final String currency;

  const _CategoryBreakdownSection({
    required this.items,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No expense category data yet.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final total = items.fold(Decimal.zero, (sum, item) => sum + item.total);
    final totalDouble = double.tryParse(total.toString()) ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spending Breakdown',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ...items.map((item) {
              final value = double.tryParse(item.total.toString()) ?? 0;
              final ratio = totalDouble == 0 ? 0.0 : (value / totalDouble);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatMoney(item.total, currency),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: ratio,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  final List<Transaction> transactions;
  final Account? selectedAccount;
  final bool showAll;
  final VoidCallback onToggle;

  const _RecentActivitySection({
    required this.transactions,
    required this.selectedAccount,
    required this.showAll,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                selectedAccount == null
                    ? 'Recent Activity'
                    : 'Recent Activity • ${selectedAccount!.name}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (transactions.length > 3)
              TextButton(
                onPressed: onToggle,
                child: Text(showAll ? 'Show less' : 'Show more'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          showAll ? 'All matching transactions' : 'Latest 3 transactions',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(170),
          ),
        ),
        const SizedBox(height: 10),
        if (transactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  color: theme.colorScheme.onSurface.withAlpha(178),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No transactions yet. Tap New Transaction to record one.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          )
        else
          ...transactions
              .take(showAll ? 8 : 3)
              .map((tx) => TransactionListItem(transaction: tx)),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DashboardMetrics {
  final Decimal income;
  final Decimal expense;
  final String currency;
  final int transactionsCount;

  const _DashboardMetrics({
    required this.income,
    required this.expense,
    required this.currency,
    required this.transactionsCount,
  });

  Decimal get savings => income - expense;

  double get savingsRate {
    final incomeValue = double.tryParse(income.toString()) ?? 0;
    if (incomeValue <= 0) {
      return 0;
    }
    final savingsValue = double.tryParse(savings.toString()) ?? 0;
    final ratio = savingsValue / incomeValue;
    if (ratio < 0) {
      return 0;
    }
    if (ratio > 1) {
      return 1;
    }
    return ratio;
  }
}

class _TrendPoint {
  final DateTime date;
  final double income;
  final double expense;

  const _TrendPoint({
    required this.date,
    required this.income,
    required this.expense,
  });

  double get net => income - expense;
}

class _BreakdownItem {
  final String label;
  final Decimal total;
  final int count;

  const _BreakdownItem({
    required this.label,
    required this.total,
    required this.count,
  });
}

String _formatMoney(Decimal value, String currency) {
  final formatter = NumberFormat.currency(
    symbol: '$currency ',
    decimalDigits: 2,
  );
  final parsed = double.tryParse(value.toString()) ?? 0;
  return formatter.format(parsed);
}
