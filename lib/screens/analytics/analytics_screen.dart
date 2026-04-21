import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/categories.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/insight_engine.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/portfolio_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, List<double>>? _trend;
  bool _loadingTrend = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final tx = context.read<TransactionProvider>();
    await tx.loadTransactions();
    final trend = await tx.getMonthlyTrend();
    if (mounted) setState(() { _trend = trend; _loadingTrend = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Analytics', style: GoogleFonts.inter(color: AppColors.text1, fontSize: 22, fontWeight: FontWeight.w700)),
      ),
      body: Consumer3<TransactionProvider, BudgetProvider, PortfolioProvider>(
        builder: (_, txProvider, budgetProvider, portfolioProvider, __) {
          final insights = InsightEngine.generate(
            transactions: txProvider.transactions,
            budgetStatuses: budgetProvider.statuses,
            holdings: portfolioProvider.holdings,
            totalIncome: txProvider.totalIncome,
            totalExpenses: txProvider.totalExpenses,
          );
          return RefreshIndicator(
            onRefresh: _load,
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                // Monthly overview stats
                _OverviewCards(provider: txProvider),
                const SizedBox(height: 20),

                // 12-month bar chart
                _SectionTitle('12-Month Trend'),
                const SizedBox(height: 10),
                _MonthlyBarChart(trend: _trend, loading: _loadingTrend),
                const SizedBox(height: 20),

                // Category breakdown
                if (txProvider.expenseByCategory.isNotEmpty) ...[
                  _SectionTitle('Expense Breakdown'),
                  const SizedBox(height: 10),
                  _CategoryPieChart(data: txProvider.expenseByCategory, total: txProvider.totalExpenses),
                  const SizedBox(height: 12),
                  _CategoryList(data: txProvider.expenseByCategory, total: txProvider.totalExpenses),
                  const SizedBox(height: 20),
                ],

                // Top expenses
                if (txProvider.expenses.isNotEmpty) ...[
                  _SectionTitle('Top Expenses This Month'),
                  const SizedBox(height: 10),
                  ...txProvider.expenses
                      .toList()
                      .sorted()
                      .take(5)
                      .map((t) {
                    final cat = Categories.findById(t.category);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TopExpenseRow(
                        emoji: cat?.emoji ?? '💸',
                        label: cat?.name ?? t.category,
                        note: t.note,
                        amount: t.amount,
                        color: cat?.color ?? AppColors.text2,
                        date: DateHelpers.dayMonth(t.date),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                ],

                // Anomalies
                _AnomaliesSection(provider: txProvider),
                const SizedBox(height: 20),

                // All insights
                if (insights.isNotEmpty) ...[
                  _SectionTitle('💡 All Insights'),
                  const SizedBox(height: 10),
                  ...insights.map((insight) {
                    final color = insight.type == 'warning' ? AppColors.expense
                        : insight.type == 'tip' ? AppColors.primary
                        : AppColors.info;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: color.withOpacity(0.25)),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(insight.emoji ?? '💡', style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(insight.title, style: GoogleFonts.inter(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(insight.body, style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12)),
                          ])),
                        ]),
                      ),
                    );
                  }),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Text(title,
    style: GoogleFonts.inter(color: AppColors.text1, fontSize: 16, fontWeight: FontWeight.w700));
}

class _OverviewCards extends StatelessWidget {
  final TransactionProvider provider;
  const _OverviewCards({required this.provider});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _StatBox('Savings Rate', '${provider.savingsRate.toStringAsFixed(0)}%',
          provider.savingsRate >= 20 ? AppColors.income : AppColors.warning),
      const SizedBox(width: 10),
      _StatBox('Avg Daily Spend',
          CurrencyFormatter.format(provider.totalExpenses / 30, compact: true), AppColors.expense),
      const SizedBox(width: 10),
      _StatBox('Transactions', '${provider.transactions.length}', AppColors.primary),
    ]);
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: GoogleFonts.inter(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(color: AppColors.text2, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}

class _MonthlyBarChart extends StatelessWidget {
  final Map<String, List<double>>? trend;
  final bool loading;
  const _MonthlyBarChart({required this.trend, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    if (trend == null) return const SizedBox.shrink();

    final incomes = trend!['income'] ?? [];
    final expenses = trend!['expense'] ?? [];
    final months = DateHelpers.last12Months();
    final maxY = [...incomes, ...expenses].fold(0.0, (m, v) => v > m ? v : m) * 1.2;

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(0, 16, 8, 8),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: BarChart(BarChartData(
        maxY: maxY > 0 ? maxY : 100,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22,
            getTitlesWidget: (v, _) {
              final idx = v.toInt();
              if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
              return Padding(padding: const EdgeInsets.only(top: 4),
                child: Text(months[idx].month.toString().padLeft(2, '0'), style: GoogleFonts.inter(color: AppColors.text3, fontSize: 9)));
            },
          )),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40,
            getTitlesWidget: (v, _) => Text(CurrencyFormatter.format(v, compact: true),
              style: GoogleFonts.inter(color: AppColors.text3, fontSize: 9)),
          )),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(months.length, (i) => BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(toY: incomes.length > i ? incomes[i] : 0, color: AppColors.income.withOpacity(0.7), width: 6, borderRadius: BorderRadius.circular(3)),
            BarChartRodData(toY: expenses.length > i ? expenses[i] : 0, color: AppColors.expense.withOpacity(0.7), width: 6, borderRadius: BorderRadius.circular(3)),
          ],
        )),
      )),
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  final Map<String, double> data;
  final double total;
  const _CategoryPieChart({required this.data, required this.total});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return SizedBox(
      height: 160,
      child: PieChart(PieChartData(
        sections: entries.asMap().entries.map((e) {
          final cat = Categories.findById(e.value.key);
          final color = cat?.color ?? AppColors.chartPalette[e.key % AppColors.chartPalette.length];
          final pct = total > 0 ? e.value.value / total * 100 : 0;
          return PieChartSectionData(
            value: e.value.value, color: color, radius: 55, showTitle: pct > 8,
            title: '${pct.toStringAsFixed(0)}%',
            titleStyle: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 35,
      )),
    );
  }
}

class _CategoryList extends StatelessWidget {
  final Map<String, double> data;
  final double total;
  const _CategoryList({required this.data, required this.total});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(children: entries.take(6).map((e) {
      final cat = Categories.findById(e.key);
      final pct = total > 0 ? e.value / total : 0.0;
      final color = cat?.color ?? AppColors.text2;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Text(cat?.emoji ?? '💸', style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(cat?.name ?? e.key, style: GoogleFonts.inter(color: AppColors.text1, fontSize: 13, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(CurrencyFormatter.format(e.value), style: GoogleFonts.inter(color: AppColors.text1, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: pct.toDouble(), backgroundColor: AppColors.surface2, valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 4),
            ),
          ])),
        ]),
      );
    }).toList());
  }
}

class _TopExpenseRow extends StatelessWidget {
  final String emoji, label, date;
  final String? note;
  final double amount;
  final Color color;
  const _TopExpenseRow({required this.emoji, required this.label, required this.amount, required this.color, required this.date, this.note});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
    child: Row(children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), alignment: Alignment.center,
        child: Text(emoji, style: const TextStyle(fontSize: 18))),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.inter(color: AppColors.text1, fontSize: 13, fontWeight: FontWeight.w600)),
        if (note?.isNotEmpty == true) Text(note!, style: GoogleFonts.inter(color: AppColors.text2, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(CurrencyFormatter.format(amount), style: GoogleFonts.inter(color: AppColors.expense, fontSize: 13, fontWeight: FontWeight.w700)),
        Text(date, style: GoogleFonts.inter(color: AppColors.text3, fontSize: 11)),
      ]),
    ]),
  );
}

class _AnomaliesSection extends StatelessWidget {
  final TransactionProvider provider;
  const _AnomaliesSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: provider.getAnomalies(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionTitle('⚠️ Unusual Spending'),
          const SizedBox(height: 10),
          ...snap.data!.map((t) {
            final cat = Categories.findById(t.category);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.warning.withOpacity(0.3))),
                child: Row(children: [
                  Text(cat?.emoji ?? '⚠️', style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${cat?.name ?? t.category} — ${DateHelpers.dayMonth(t.date)}',
                        style: GoogleFonts.inter(color: AppColors.warning, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('Unusually high: ${CurrencyFormatter.format(t.amount)}',
                        style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12)),
                  ])),
                ]),
              ),
            );
          }),
          const SizedBox(height: 8),
        ]);
      },
    );
  }
}

extension _TxSort on List {
  List sorted() => this..sort((a, b) => (b.amount as double).compareTo(a.amount as double));
}
