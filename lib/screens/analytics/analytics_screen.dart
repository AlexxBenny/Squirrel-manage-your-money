import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/categories.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/insight_engine.dart';
import '../../models/custom_tag_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/portfolio_provider.dart';
import '../../providers/tag_provider.dart';
import '../../widgets/wave_widgets.dart';

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
    final tagProvider = context.read<TagProvider>();
    await tx.loadTransactions();
    await tagProvider.loadTags();
    await tagProvider.loadTagTotals(
      from: DateHelpers.startOfMonth(tx.selectedMonth),
      to: DateHelpers.endOfMonth(tx.selectedMonth),
    );
    final trend = await tx.getMonthlyTrend();
    if (mounted) setState(() { _trend = trend; _loadingTrend = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer4<TransactionProvider, BudgetProvider, PortfolioProvider, TagProvider>(
        builder: (_, txp, bp, pp, tagProvider, __) {
          final insights = InsightEngine.generate(
            transactions: txp.transactions,
            budgetStatuses: bp.statuses,
            holdings: pp.holdings,
            totalIncome: txp.totalIncome,
            totalExpenses: txp.totalExpenses,
          );
          return RefreshIndicator(
            onRefresh: _load,
            color: AppColors.primary,
            child: CustomScrollView(slivers: [
              // Wave header
              SliverToBoxAdapter(child: ClipPath(
                clipper: WaveClipper(),
                child: Container(
                  padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 56),
                  decoration: const BoxDecoration(gradient: AppColors.headerGradient),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Analytics', style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(DateHelpers.monthYear(txp.selectedMonth), style: GoogleFonts.inter(color: Colors.white60, fontSize: 13)),
                    const SizedBox(height: 20),
                    Row(children: [
                      _GlassStat('${txp.savingsRate.toStringAsFixed(0)}%', 'Savings Rate',
                          txp.savingsRate >= 20 ? AppColors.income : AppColors.warning),
                      const SizedBox(width: 8),
                      _GlassStat(CurrencyFormatter.format(txp.totalExpenses / 30, compact: true), 'Daily Avg', AppColors.expense),
                      const SizedBox(width: 8),
                      _GlassStat('${txp.transactions.length}', 'Transactions', Colors.white),
                    ]),
                  ]),
                ),
              )),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList(delegate: SliverChildListDelegate([

                  // 12-month bar chart
                  _SectionTitle('12-Month Trend', Icons.bar_chart_rounded),
                  const SizedBox(height: 12),
                  CurvedContainer(
                    padding: const EdgeInsets.fromLTRB(8, 16, 12, 8),
                    child: _loadingTrend
                        ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
                        : _buildBarChart(),
                  ),
                  const SizedBox(height: 8),
                  // Legend
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _legendDot(AppColors.income, 'Income'),
                    const SizedBox(width: 16),
                    _legendDot(AppColors.expense, 'Expenses'),
                  ]),
                  const SizedBox(height: 24),

                  // Tag spending breakdown — expandable
                  if (tagProvider.tags.isNotEmpty) ...[
                    _SectionTitle('Spending by Tag', Icons.label_rounded),
                    const SizedBox(height: 4),
                    Text('Tap a tag to see its transactions',
                      style: GoogleFonts.inter(color: AppColors.text3, fontSize: 12)),
                    const SizedBox(height: 12),
                    ...(() {
                      // Build full list: every tag, with spending (0 if none)
                      final spending = tagProvider.tagTotals;
                      final allEntries = tagProvider.tags
                          .map((t) => MapEntry(t, spending[t.id] ?? 0.0))
                          .toList()
                        ..sort((a, b) => b.value.compareTo(a.value));
                      final maxAmount = allEntries.isEmpty ? 0.0 : allEntries.first.value;
                      return allEntries.map((entry) {
                        final taggedTxns = txp.transactions
                            .where((t) => CustomTagModel.parseIds(t.tags).contains(entry.key.id))
                            .toList()
                          ..sort((a, b) => b.date.compareTo(a.date));
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TagExpandableCard(
                            tag: entry.key,
                            total: entry.value,
                            maxTotal: maxAmount,
                            transactions: taggedTxns,
                          ),
                        );
                      });
                    })(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 14),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            'Tag totals are an independent view of your spending — amounts are not duplicated in category totals.',
                            style: GoogleFonts.inter(color: AppColors.primary, fontSize: 11, height: 1.4),
                          )),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Category breakdown
                  if (txp.expenseByCategory.isNotEmpty) ...[
                    _SectionTitle('Expense Breakdown', Icons.pie_chart_rounded),
                    const SizedBox(height: 12),
                    CurvedContainer(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        SizedBox(height: 150, child: PieChart(PieChartData(
                          sections: txp.expenseByCategory.entries.toList().asMap().entries.map((e) {
                            final cat = Categories.findById(e.value.key);
                            final color = cat?.color ?? AppColors.chartPalette[e.key % AppColors.chartPalette.length];
                            final pct = txp.totalExpenses > 0 ? e.value.value / txp.totalExpenses * 100 : 0;
                            return PieChartSectionData(
                              value: e.value.value, color: color, radius: 52,
                              showTitle: pct > 8,
                              title: '${pct.toStringAsFixed(0)}%',
                              titleStyle: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                            );
                          }).toList(),
                          sectionsSpace: 2, centerSpaceRadius: 32,
                        ))),
                        const SizedBox(height: 16),
                        ...((txp.expenseByCategory.entries.toList()
                              ..sort((a, b) => b.value.compareTo(a.value)))
                            .take(5)
                            .map((e) {
                          final cat = Categories.findById(e.key);
                          final pct = txp.totalExpenses > 0 ? e.value / txp.totalExpenses : 0.0;
                          final color = cat?.color ?? AppColors.primary;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(children: [
                              Text(cat?.emoji ?? '💸', style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Text(cat?.name ?? e.key, style: GoogleFonts.inter(color: AppColors.text1, fontSize: 13, fontWeight: FontWeight.w600)),
                                  const Spacer(),
                                  Text(CurrencyFormatter.format(e.value, compact: true), style: GoogleFonts.inter(color: AppColors.text1, fontSize: 13, fontWeight: FontWeight.w700)),
                                ]),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct.toDouble(),
                                    backgroundColor: AppColors.surface2,
                                    valueColor: AlwaysStoppedAnimation<Color>(color),
                                    minHeight: 5,
                                  ),
                                ),
                              ])),
                            ]),
                          );
                        })),
                      ]),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Insights
                  if (insights.isNotEmpty) ...[
                    _SectionTitle('Smart Insights', Icons.auto_awesome_rounded),
                    const SizedBox(height: 12),
                    ...insights.map((insight) {
                      final color = insight.type == 'warning' ? AppColors.expense
                          : insight.type == 'tip' ? AppColors.primary
                          : AppColors.info;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: color.withValues(alpha: 0.2)),
                            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                              alignment: Alignment.center,
                              child: Text(insight.emoji ?? '💡', style: const TextStyle(fontSize: 18)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(insight.title, style: GoogleFonts.inter(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(insight.body, style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12, height: 1.4)),
                            ])),
                          ]),
                        ),
                      );
                    }),
                  ],
                ])),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildBarChart() {
    if (_trend == null) return const SizedBox(height: 160);
    final incomes  = _trend!['income']  ?? [];
    final expenses = _trend!['expense'] ?? [];
    final months   = DateHelpers.last12Months();
    final maxY = [...incomes, ...expenses].fold(0.0, (m, v) => v > m ? v : m) * 1.25;
    return SizedBox(
      height: 160,
      child: BarChart(BarChartData(
        maxY: maxY > 0 ? maxY : 1000,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 20,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= months.length) return const SizedBox.shrink();
              return Padding(padding: const EdgeInsets.only(top: 4),
                child: Text('${months[i].month}'.padLeft(2, '0'), style: GoogleFonts.inter(color: AppColors.text3, fontSize: 9)));
            },
          )),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 38,
            getTitlesWidget: (v, _) => Text(CurrencyFormatter.format(v, compact: true), style: GoogleFonts.inter(color: AppColors.text3, fontSize: 9)),
          )),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(months.length, (i) => BarChartGroupData(x: i, barRods: [
          BarChartRodData(toY: incomes.length > i ? incomes[i] : 0, color: AppColors.income.withValues(alpha: 0.75), width: 5, borderRadius: BorderRadius.circular(3)),
          BarChartRodData(toY: expenses.length > i ? expenses[i] : 0, color: AppColors.expense.withValues(alpha: 0.75), width: 5, borderRadius: BorderRadius.circular(3)),
        ])),
      )),
    );
  }

  Widget _legendDot(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 6),
    Text(label, style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12)),
  ]);
}

class _TagExpandableCard extends StatefulWidget {
  final CustomTagModel tag;
  final double total;
  final double maxTotal;
  final List<TransactionModel> transactions;

  const _TagExpandableCard({
    required this.tag,
    required this.total,
    required this.maxTotal,
    required this.transactions,
  });

  @override
  State<_TagExpandableCard> createState() => _TagExpandableCardState();
}

class _TagExpandableCardState extends State<_TagExpandableCard> {
  bool _expanded = false;

  // Group transactions by category for a cleaner breakdown
  Map<String, List<TransactionModel>> get _byCategory {
    final map = <String, List<TransactionModel>>{};
    for (final t in widget.transactions) {
      map.putIfAbsent(t.category, () => []).add(t);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final tag = widget.tag;
    final ratio = widget.maxTotal > 0 ? widget.total / widget.maxTotal : 0.0;
    final txCount = widget.transactions.length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _expanded ? tag.color.withValues(alpha: 0.35) : AppColors.border, width: _expanded ? 1.5 : 1),
        boxShadow: [BoxShadow(color: _expanded ? tag.color.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header row (always visible) ──────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              Row(children: [
                // Emoji badge
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: tag.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: Text(tag.emoji, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(tag.name, style: GoogleFonts.inter(color: AppColors.text1, fontSize: 14, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(
                    widget.total > 0
                        ? CurrencyFormatter.format(widget.total)
                        : '₹0',
                    style: GoogleFonts.inter(
                      color: widget.total > 0 ? tag.color : AppColors.text3,
                      fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    txCount == 0
                        ? 'No spending this month'
                        : '$txCount transaction${txCount != 1 ? 's' : ''}',
                    style: GoogleFonts.inter(color: AppColors.text3, fontSize: 11)),
                ])),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(Icons.keyboard_arrow_down_rounded, color: tag.color, size: 22),
                ),
              ]),
              const SizedBox(height: 10),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio.toDouble(),
                  backgroundColor: AppColors.surface2,
                  valueColor: AlwaysStoppedAnimation<Color>(tag.color),
                  minHeight: 5,
                ),
              ),
            ]),
          ),
        ),

        // ── Expandable transaction list ───────────────────────────────
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 280),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: _expanded ? _buildTransactionList() : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }

  Widget _buildTransactionList() {
    if (widget.transactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Text('🏷️', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('No tagged transactions',
                style: GoogleFonts.inter(color: AppColors.text1, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('Tap + and select this tag when adding a transaction.',
                style: GoogleFonts.inter(color: AppColors.text2, fontSize: 11, height: 1.4)),
            ])),
          ]),
        ),
      );
    }

    // Group by category and show category sub-headers
    final byCategory = _byCategory;
    final sortedCategories = byCategory.entries.toList()
      ..sort((a, b) {
        final sumA = a.value.fold(0.0, (s, t) => s + t.amount);
        final sumB = b.value.fold(0.0, (s, t) => s + t.amount);
        return sumB.compareTo(sumA);
      });

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Divider(color: widget.tag.color.withValues(alpha: 0.15), height: 1),
      ...sortedCategories.map((catEntry) {
        final cat = Categories.findById(catEntry.key);
        final catTotal = catEntry.value.fold(0.0, (s, t) => s + t.amount);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Category sub-header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(children: [
              Text(cat?.emoji ?? '💸', style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(cat?.name ?? catEntry.key,
                style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(CurrencyFormatter.format(catTotal, compact: true),
                style: GoogleFonts.inter(color: widget.tag.color, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
          // Transactions in this category
          ...catEntry.value.map((t) => _TxRow(t: t, tagColor: widget.tag.color)),
        ]);
      }),
      const SizedBox(height: 8),
    ]);
  }
}

class _TxRow extends StatelessWidget {
  final TransactionModel t;
  final Color tagColor;
  const _TxRow({required this.t, required this.tagColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
        ),
        child: Row(children: [
          // Date pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
            child: Text(
              '${t.date.day}/${t.date.month}',
              style: GoogleFonts.inter(color: AppColors.text3, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          // Note or category
          Expanded(child: Text(
            t.note?.isNotEmpty == true ? t.note! : (Categories.findById(t.category)?.name ?? t.category),
            style: GoogleFonts.inter(color: AppColors.text1, fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          )),
          // Amount
          Text(
            '${t.isExpense ? '-' : '+'}${CurrencyFormatter.format(t.amount, compact: true)}',
            style: GoogleFonts.inter(
              color: t.isExpense ? AppColors.expense : AppColors.income,
              fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ]),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle(this.title, this.icon);
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 28, height: 28,
      decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: AppColors.primary, size: 16)),
    const SizedBox(width: 8),
    Text(title, style: GoogleFonts.inter(color: AppColors.text1, fontSize: 16, fontWeight: FontWeight.w700)),
  ]);
}

class _GlassStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _GlassStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: GoogleFonts.inter(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
      Text(label, style: GoogleFonts.inter(color: Colors.white60, fontSize: 10)),
    ]),
  ));
}
