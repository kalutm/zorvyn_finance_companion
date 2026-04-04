import 'package:finance_frontend/features/transactions/data/model/dtos/date_range.dart';
import 'package:finance_frontend/features/transactions/data/model/dtos/stats_in.dart';
import 'package:finance_frontend/features/transactions/data/model/dtos/time_series_in.dart';
import 'package:finance_frontend/features/transactions/data/model/list_transactions_in.dart';
import 'package:finance_frontend/features/transactions/data/model/report_analytics.dart';
import 'package:finance_frontend/features/transactions/data/model/transaction_stats.dart';
import 'package:finance_frontend/features/transactions/data/model/transaction_time_series.dart';
import 'package:finance_frontend/features/transactions/domain/entities/filter_on_enum.dart';
import 'package:finance_frontend/features/transactions/domain/entities/granulity_enum.dart';
import 'package:finance_frontend/features/transactions/domain/entities/transaction.dart';
import 'package:finance_frontend/features/transactions/domain/entities/transaction_type.dart';
import 'package:finance_frontend/features/transactions/presentation/cubits/report_analytics_cubit.dart';
import 'package:finance_frontend/features/transactions/presentation/cubits/report_analytics_loading_enum.dart';
import 'package:finance_frontend/features/transactions/presentation/cubits/report_analytics_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ReportAndAnlyticsView extends StatefulWidget {
  const ReportAndAnlyticsView({super.key});

  @override
  State<ReportAndAnlyticsView> createState() => _ReportAndAnlyticsViewState();
}

class _ReportAndAnlyticsViewState extends State<ReportAndAnlyticsView> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    _selectedMonth = context.read<ReportAnalyticsCubit>().today;
    super.initState();
  }

  String _formatMonthParam(DateTime date) => DateFormat('yyyy-MM').format(date);

  DateRange _monthRange(DateTime date) {
    return DateRange(
      start: DateTime(date.year, date.month, 1),
      end: DateTime(date.year, date.month + 1, 0, 23, 59, 59),
    );
  }

  Future<void> _refreshInsightsForMonth() async {
    final cubit = context.read<ReportAnalyticsCubit>();
    if (cubit.state is ReportAnalyticsPartLoading) {
      return;
    }

    final range = _monthRange(_selectedMonth);
    cubit.getTransactionSummary(_formatMonthParam(_selectedMonth), range);
    cubit.getTransactionStats(
      StatsIn(filterOn: FilterOn.category, range: range, onlyExpense: true),
    );
    cubit.getTransactionTimeSeries(
      TimeSeriesIn(granulity: Granulity.day, range: range),
    );
    cubit.getTransactionsForReport(ListTransactionsIn(range: range));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _MonthSelector(
          selectedDate: _selectedMonth,
          onChanged: (date) {
            setState(() {
              _selectedMonth = date;
            });
            _refreshInsightsForMonth();
          },
        ),
      ),
      body: BlocBuilder<ReportAnalyticsCubit, ReportAnalyticsState>(
        builder: (context, state) {
          ReportAnalytics? data;
          bool isLoading = false;

          if (state is ReportAnalyticsLoaded) {
            data = state.data;
          } else if (state is ReportAnalyticsPartLoading) {
            data = state.existing;
            isLoading = state.partial == ReportAnalyticsIsLoading.all;
          }

          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final currency = _currencyFromTransactions(data.transactions);
          final topCategory = _highestSpendingCategory(data.transactionStats);
          final frequentType = _mostFrequentType(data.transactions);
          final weekComparison = _thisWeekVsLastWeek(
            data.transactions,
            _selectedMonth,
          );

          return RefreshIndicator(
            onRefresh: _refreshInsightsForMonth,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                if (isLoading) const LinearProgressIndicator(),
                Row(
                  children: [
                    Expanded(
                      child: _HighlightCard(
                        title: 'Highest Category',
                        icon: Icons.workspace_premium_rounded,
                        primaryText: topCategory?.name ?? 'No data',
                        secondaryText:
                            topCategory == null
                                ? 'Add expense data'
                                : '${_money(topCategory.total, currency)} • ${topCategory.sharePct.toStringAsFixed(1)}%',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HighlightCard(
                        title: 'Frequent Type',
                        icon: Icons.repeat_rounded,
                        primaryText: frequentType?.label ?? 'No data',
                        secondaryText:
                            frequentType == null
                                ? 'Add transactions'
                                : '${frequentType.count} transactions',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _WeekComparisonCard(
                  weekComparison: weekComparison,
                  currency: currency,
                ),
                const SizedBox(height: 12),
                _MonthlyTrendCard(
                  points: data.transactionTimeSeriess,
                  currency: currency,
                ),
                const SizedBox(height: 12),
                _CategoryInsightsCard(
                  stats: data.transactionStats,
                  currency: currency,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;

  const _MonthSelector({required this.selectedDate, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () {
            onChanged(DateTime(selectedDate.year, selectedDate.month - 1));
          },
        ),
        Text(
          DateFormat.yMMMM().format(selectedDate),
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 18),
          onPressed: () {
            onChanged(DateTime(selectedDate.year, selectedDate.month + 1));
          },
        ),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String primaryText;
  final String secondaryText;

  const _HighlightCard({
    required this.title,
    required this.icon,
    required this.primaryText,
    required this.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(170),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            primaryText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            secondaryText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _WeekComparisonCard extends StatelessWidget {
  final _WeekComparisonInsight? weekComparison;
  final String currency;

  const _WeekComparisonCard({
    required this.weekComparison,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (weekComparison == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            'Week comparison appears once enough transactions exist.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final color = weekComparison!.isIncrease ? Colors.redAccent : Colors.green;
    final icon =
        weekComparison!.isIncrease
            ? Icons.trending_up_rounded
            : Icons.trending_down_rounded;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This Week vs Last Week',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _WeekValue(
                    label: 'This week',
                    value: _money(weekComparison!.thisWeekExpense, currency),
                  ),
                ),
                Expanded(
                  child: _WeekValue(
                    label: 'Last week',
                    value: _money(weekComparison!.lastWeekExpense, currency),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${weekComparison!.deltaPct.abs().toStringAsFixed(1)}% ${weekComparison!.isIncrease ? 'higher' : 'lower'} expense than last week',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekValue extends StatelessWidget {
  final String label;
  final String value;

  const _WeekValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(170),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MonthlyTrendCard extends StatelessWidget {
  final List<TransactionTimeSeries> points;
  final String currency;

  const _MonthlyTrendCard({required this.points, required this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (points.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            'No monthly trend data for this period.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Trend',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Net flow over the selected month',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(170),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 210,
              child: SfCartesianChart(
                margin: EdgeInsets.zero,
                plotAreaBorderWidth: 0,
                primaryXAxis: DateTimeAxis(
                  intervalType: DateTimeIntervalType.days,
                  dateFormat: DateFormat.d(),
                  majorGridLines: const MajorGridLines(width: 0),
                ),
                primaryYAxis: NumericAxis(
                  numberFormat: NumberFormat.compactCurrency(
                    symbol: '$currency ',
                  ),
                ),
                series: <CartesianSeries<TransactionTimeSeries, DateTime>>[
                  SplineAreaSeries<TransactionTimeSeries, DateTime>(
                    dataSource: points,
                    xValueMapper: (point, _) => point.date,
                    yValueMapper: (point, _) => double.tryParse(point.net) ?? 0,
                    color: Theme.of(context).colorScheme.primary.withAlpha(60),
                    borderColor: Theme.of(context).colorScheme.primary,
                    borderWidth: 2,
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

class _CategoryInsightsCard extends StatelessWidget {
  final List<TransactionStats> stats;
  final String currency;

  const _CategoryInsightsCard({required this.stats, required this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (stats.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            'No category breakdown data for this period.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final top = _highestSpendingCategory(stats);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spending by Category',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (top != null) ...[
              const SizedBox(height: 4),
              Text(
                'Top: ${top.name} (${top.sharePct.toStringAsFixed(1)}%)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(170),
                ),
              ),
            ],
            const SizedBox(height: 10),
            ...stats.take(6).map((s) {
              final pct = _safeDouble(s.percentage);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _money(_safeDouble(s.total), currency),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: (pct / 100).clamp(0.0, 1.0),
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

class _TopCategoryInsight {
  final String name;
  final double total;
  final double sharePct;

  const _TopCategoryInsight({
    required this.name,
    required this.total,
    required this.sharePct,
  });
}

class _TypeInsight {
  final String label;
  final int count;

  const _TypeInsight({required this.label, required this.count});
}

class _WeekComparisonInsight {
  final double thisWeekExpense;
  final double lastWeekExpense;
  final double deltaPct;
  final bool isIncrease;

  const _WeekComparisonInsight({
    required this.thisWeekExpense,
    required this.lastWeekExpense,
    required this.deltaPct,
    required this.isIncrease,
  });
}

String _currencyFromTransactions(List<Transaction> txs) {
  if (txs.isNotEmpty) {
    return txs.first.currency;
  }
  return 'ETB';
}

_TopCategoryInsight? _highestSpendingCategory(List<TransactionStats> stats) {
  if (stats.isEmpty) {
    return null;
  }

  final sorted = List<TransactionStats>.from(stats);
  sorted.sort((a, b) => _safeDouble(b.total).compareTo(_safeDouble(a.total)));

  final top = sorted.first;
  return _TopCategoryInsight(
    name: top.name,
    total: _safeDouble(top.total),
    sharePct: _safeDouble(top.percentage),
  );
}

_TypeInsight? _mostFrequentType(List<Transaction> txs) {
  if (txs.isEmpty) {
    return null;
  }

  final counts = <TransactionType, int>{};
  for (final tx in txs) {
    counts[tx.type] = (counts[tx.type] ?? 0) + 1;
  }

  final sorted =
      counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final top = sorted.first;

  return _TypeInsight(label: _typeLabel(top.key), count: top.value);
}

_WeekComparisonInsight? _thisWeekVsLastWeek(
  List<Transaction> txs,
  DateTime selectedMonth,
) {
  if (txs.isEmpty) {
    return null;
  }

  final now = DateTime.now();
  final monthEnd = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
  final anchor = monthEnd.isAfter(now) ? now : monthEnd;

  DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);

  final thisWeekEnd = endOfDay(anchor);
  final thisWeekStart = startOfDay(anchor.subtract(const Duration(days: 6)));
  final lastWeekEnd = endOfDay(thisWeekStart.subtract(const Duration(days: 1)));
  final lastWeekStart = startOfDay(
    lastWeekEnd.subtract(const Duration(days: 6)),
  );

  double sumExpense(DateTime start, DateTime end) {
    var sum = 0.0;
    for (final tx in txs) {
      if (tx.type != TransactionType.EXPENSE) {
        continue;
      }
      if (tx.occuredAt.isBefore(start) || tx.occuredAt.isAfter(end)) {
        continue;
      }
      sum += _safeDouble(tx.amount);
    }
    return sum;
  }

  final thisWeek = sumExpense(thisWeekStart, thisWeekEnd);
  final lastWeek = sumExpense(lastWeekStart, lastWeekEnd);

  final deltaPct =
      lastWeek == 0
          ? (thisWeek > 0 ? 100.0 : 0.0)
          : ((thisWeek - lastWeek) / lastWeek) * 100;

  return _WeekComparisonInsight(
    thisWeekExpense: thisWeek,
    lastWeekExpense: lastWeek,
    deltaPct: deltaPct,
    isIncrease: thisWeek >= lastWeek,
  );
}

String _typeLabel(TransactionType type) {
  if (type == TransactionType.INCOME) {
    return 'Income';
  }
  if (type == TransactionType.EXPENSE) {
    return 'Expense';
  }
  return 'Transfer';
}

double _safeDouble(String raw) {
  return double.tryParse(raw.replaceAll('%', '').replaceAll(',', '')) ?? 0.0;
}

String _money(double value, String currency) {
  final f = NumberFormat.compactCurrency(symbol: '$currency ');
  return f.format(value);
}
