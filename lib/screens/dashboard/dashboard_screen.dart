import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/insight_engine.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../models/budget_model.dart';
import '../../providers/portfolio_provider.dart';
import '../../providers/category_provider.dart';
import '../../widgets/transaction_tile.dart';
import '../../widgets/wave_widgets.dart';
import '../transactions/add_transaction_sheet.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // FIX #10: Computed once after data loads, not on every Consumer rebuild.
  List<Insight> _insights = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final txProvider        = context.read<TransactionProvider>();
    final budgetProvider    = context.read<BudgetProvider>();
    final portfolioProvider = context.read<PortfolioProvider>();
    final categoryProvider  = context.read<CategoryProvider>();
    await categoryProvider.loadCategories();
    await txProvider.loadTransactions();
    await budgetProvider.loadBudgets(transactions: txProvider.transactions);
    await portfolioProvider.loadHoldings();
    // Compute insights once here; never inside the Consumer builder.
    if (mounted) {
      setState(() {
        _insights = InsightEngine.generate(
          transactions: txProvider.transactions,
          budgetStatuses: budgetProvider.statuses,
          holdings: portfolioProvider.holdings,
          totalIncome: txProvider.totalIncome,
          totalExpenses: txProvider.totalExpenses,
        );
      });
    }
  }

  static String _topCategory(Map<String, double> byCategory) {
    if (byCategory.isEmpty) return 'No expenses yet';
    final top = byCategory.entries.reduce((a, b) => a.value > b.value ? a : b);
    final name = top.key.replaceAll('_', ' ');
    return 'Top: ${name[0].toUpperCase()}${name.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: Consumer3<TransactionProvider, BudgetProvider, PortfolioProvider>(
          builder: (_, txProvider, budgetProvider, portfolioProvider, __) {
            final income   = txProvider.totalIncome;
            final expenses = txProvider.totalExpenses;
            final savings  = txProvider.netSavings;

            return CustomScrollView(
              slivers: [
                // ── Wave Header ──────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _WaveDashboardHeader(
                    income: income,
                    expenses: expenses,
                    savings: savings,
                    monthLabel: DateHelpers.monthYear(txProvider.selectedMonth),
                    portfolioValue: portfolioProvider.totalCurrentValue,
                    portfolioPnL: portfolioProvider.totalPnL,
                    portfolioPnLPct: portfolioProvider.totalPnLPct,
                  ),
                ),

                // ── Body content ─────────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 20),

                      // ── Unique stat cards (no duplication with header) ────
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.0,
                        children: [
                          _StatCard(
                            label: 'Income',
                            amount: CurrencyFormatter.format(income, compact: true),
                            sub: '${txProvider.incomes.length} transaction${txProvider.incomes.length == 1 ? '' : 's'}',
                            icon: Icons.south_rounded,
                            color: AppColors.income,
                          ),
                          _StatCard(
                            label: 'Expenses',
                            amount: CurrencyFormatter.format(expenses, compact: true),
                            sub: _topCategory(txProvider.expenseByCategory),
                            icon: Icons.north_rounded,
                            color: AppColors.expense,
                          ),
                          _BudgetHealthCard(
                            statuses: budgetProvider.statuses,
                          ),
                          _PortfolioPnLCard(
                            value: portfolioProvider.totalCurrentValue,
                            pnl: portfolioProvider.totalPnL,
                            pnlPct: portfolioProvider.totalPnLPct,
                          ),
                        ],
                      ),

                      // Budget alerts
                      if (budgetProvider.overBudget.isNotEmpty || budgetProvider.nearLimit.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _SectionHeader(title: 'Budget Alerts', icon: Icons.warning_amber_rounded, iconColor: AppColors.warning),
                        const SizedBox(height: 12),
                        ...budgetProvider.overBudget.take(2).map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _AlertBanner(
                            title: '${s.budget.category} budget exceeded',
                            subtitle: 'Spent ${CurrencyFormatter.format(s.spent)} of ${CurrencyFormatter.format(s.budget.limitAmount)}',
                            color: AppColors.expense,
                            icon: Icons.warning_rounded,
                          ),
                        )),
                        ...budgetProvider.nearLimit.take(2).map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _AlertBanner(
                            title: '${s.budget.category} nearing limit',
                            subtitle: '${(s.usageRatio * 100).toStringAsFixed(0)}% used — ${CurrencyFormatter.format(s.remaining)} left',
                            color: AppColors.warning,
                            icon: Icons.info_rounded,
                          ),
                        )),
                      ],

                      // Insights — full width vertical
                      if (_insights.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _SectionHeader(title: 'Smart Insights', icon: Icons.auto_awesome_rounded, iconColor: AppColors.primary),
                        const SizedBox(height: 12),
                        ..._insights.map((insight) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _InsightCard(insight: insight),
                        )),
                      ],

                      // Recent Transactions
                      const SizedBox(height: 24),
                      _SectionHeader(title: 'Recent Activity', icon: Icons.receipt_long_rounded, iconColor: AppColors.primary),
                      const SizedBox(height: 12),

                      if (txProvider.isLoading)
                        const Center(child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ))
                      else if (txProvider.transactions.isEmpty)
                        _EmptyState()
                      else
                        ...txProvider.transactions.take(5).map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TransactionTile(
                            transaction: t,
                            onDelete: () => txProvider.deleteTransaction(t.id),
                            onTap: () => AddTransactionSheet.show(context, existing: t),
                          ),
                        )),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Wave Header ─────────────────────────────────────────────────────────────

class _WaveDashboardHeader extends StatelessWidget {
  final double income, expenses, savings, portfolioValue, portfolioPnL, portfolioPnLPct;
  final String monthLabel;

  const _WaveDashboardHeader({
    required this.income, required this.expenses, required this.savings,
    required this.monthLabel, required this.portfolioValue,
    required this.portfolioPnL, required this.portfolioPnLPct,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ClipPath(
      clipper: WaveClipper(),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, top + 16, 20, 60),
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Good ${_greeting()} 👋', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 2),
                Text('FinanceOS', style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 13),
                  const SizedBox(width: 6),
                  Text(monthLabel, style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.settings_outlined, color: Colors.white, size: 18),
                ),
              ),
            ]),

            const SizedBox(height: 24),

            // Net balance hero
            Text('Net Balance', style: GoogleFonts.inter(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.format(savings),
              style: GoogleFonts.inter(
                color: Colors.white, fontSize: 34,
                fontWeight: FontWeight.w800, letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 20),

            // Savings Rate / Portfolio — unique, not duplicated in cards below
            Row(children: [
              Expanded(child: _GlassStatChip(
                icon: Icons.trending_up_rounded,
                iconBg: AppColors.income,
                label: 'Savings Rate',
                value: '${(income > 0 ? savings / income * 100 : 0).toStringAsFixed(1)}%',
                sub: '${CurrencyFormatter.format(savings, compact: true)} saved',
              )),
              const SizedBox(width: 12),
              Expanded(child: _GlassStatChip(
                icon: Icons.candlestick_chart_rounded,
                iconBg: AppColors.info,
                label: 'Portfolio',
                value: CurrencyFormatter.format(portfolioValue, compact: true),
                sub: '${portfolioPnL >= 0 ? '+' : ''}${portfolioPnLPct.toStringAsFixed(1)}% return',
              )),
            ]),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }
}

class _GlassStatChip extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String label, value;
  final String? sub;
  const _GlassStatChip({required this.icon, required this.iconBg, required this.label, required this.value, this.sub});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
    ),
    child: Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: iconBg.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
        Text(label, style: GoogleFonts.inter(color: Colors.white60, fontSize: 11)),
        if (sub != null)
          Text(sub!, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.75), fontSize: 10, fontWeight: FontWeight.w500)),
      ])),
    ]),
  );
}

// ── Unique Stat Cards ─────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, amount, sub;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.amount, required this.sub, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 10),
        Text(amount,
          style: GoogleFonts.inter(color: AppColors.text1, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(color: AppColors.text2, fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(sub, style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w600),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

class _BudgetHealthCard extends StatelessWidget {
  final List<BudgetStatus> statuses;
  const _BudgetHealthCard({required this.statuses});

  @override
  Widget build(BuildContext context) {
    final total   = statuses.length;
    final onTrack = statuses.where((s) => !s.isOver && !s.isWarning).length;
    final color = total == 0
        ? AppColors.primary
        : onTrack == total ? AppColors.income
        : onTrack == 0    ? AppColors.expense
        : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.account_balance_wallet_rounded, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            total == 0 ? '--' : '$onTrack/$total',
            style: GoogleFonts.inter(color: AppColors.text1, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 2),
          Text('Budget Health', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total > 0 ? onTrack / total : 0,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 4,
              ),
            )
          else
            Text('Set budgets', style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PortfolioPnLCard extends StatelessWidget {
  final double value, pnl, pnlPct;
  const _PortfolioPnLCard({required this.value, required this.pnl, required this.pnlPct});

  @override
  Widget build(BuildContext context) {
    final isPos  = pnl >= 0;
    final color  = isPos ? AppColors.income : AppColors.expense;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.info.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.show_chart_rounded, color: AppColors.info, size: 20),
          ),
          const SizedBox(height: 10),
          Text(CurrencyFormatter.format(value, compact: true),
            style: GoogleFonts.inter(color: AppColors.text1, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('Portfolio', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text('${isPos ? '+' : ''}${pnlPct.toStringAsFixed(1)}% return',
            style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ─── Supporting Widgets ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  const _SectionHeader({required this.title, required this.icon, required this.iconColor});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 28, height: 28,
      decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: iconColor, size: 16),
    ),
    const SizedBox(width: 8),
    Text(title, style: GoogleFonts.inter(color: AppColors.text1, fontSize: 16, fontWeight: FontWeight.w700)),
  ]);
}

class _AlertBanner extends StatelessWidget {
  final String title, subtitle;
  final Color color;
  final IconData icon;
  const _AlertBanner({required this.title, required this.subtitle, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.inter(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        Text(subtitle, style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12)),
      ])),
    ]),
  );
}

class _InsightCard extends StatelessWidget {
  final Insight insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final color = insight.type == 'warning' ? AppColors.expense
        : insight.type == 'tip' ? AppColors.primary
        : AppColors.info;
    return Container(
      width: double.infinity, // fill full width
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(insight.emoji ?? '💡', style: const TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(insight.title,
            style: GoogleFonts.inter(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(insight.body,
            style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12, height: 1.4)),
        ])),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(32),
    alignment: Alignment.center,
    child: Column(children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(24)),
        child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 36),
      ),
      const SizedBox(height: 16),
      Text('No transactions yet', style: GoogleFonts.inter(color: AppColors.text1, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('Tap + to record your first one', style: GoogleFonts.inter(color: AppColors.text3, fontSize: 13)),
    ]),
  );
}
