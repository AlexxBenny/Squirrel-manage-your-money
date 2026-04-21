import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/insight_engine.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/portfolio_provider.dart';
import '../../widgets/summary_card.dart';
import '../../widgets/transaction_tile.dart';
import '../transactions/add_transaction_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final txProvider = context.read<TransactionProvider>();
    final budgetProvider = context.read<BudgetProvider>();
    final portfolioProvider = context.read<PortfolioProvider>();
    await txProvider.loadTransactions();
    await budgetProvider.loadBudgets(transactions: txProvider.transactions);
    await portfolioProvider.loadHoldings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: AppColors.background,
              floating: true,
              pinned: false,
              expandedHeight: 80,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                title: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FinanceOS 🐿️',
                      style: GoogleFonts.inter(color: AppColors.text1, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      DateHelpers.monthYear(DateTime.now()),
                      style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Consumer3<TransactionProvider, BudgetProvider, PortfolioProvider>(
                  builder: (_, txProvider, budgetProvider, portfolioProvider, __) {
                    final income = txProvider.totalIncome;
                    final expenses = txProvider.totalExpenses;
                    final savings = txProvider.netSavings;
                    final insights = InsightEngine.generate(
                      transactions: txProvider.transactions,
                      budgetStatuses: budgetProvider.statuses,
                      holdings: portfolioProvider.holdings,
                      totalIncome: income,
                      totalExpenses: expenses,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary cards 2x2
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.35,
                          children: [
                            SummaryCard(
                              label: 'Income',
                              amount: CurrencyFormatter.format(income, compact: true),
                              icon: Icons.arrow_downward_rounded,
                              color: AppColors.income,
                            ),
                            SummaryCard(
                              label: 'Expenses',
                              amount: CurrencyFormatter.format(expenses, compact: true),
                              icon: Icons.arrow_upward_rounded,
                              color: AppColors.expense,
                            ),
                            SummaryCard(
                              label: 'Net Savings',
                              amount: CurrencyFormatter.format(savings, compact: true),
                              icon: Icons.savings_outlined,
                              color: savings >= 0 ? AppColors.income : AppColors.expense,
                              subtitle: '${txProvider.savingsRate.toStringAsFixed(0)}% of income',
                            ),
                            SummaryCard(
                              label: 'Portfolio',
                              amount: CurrencyFormatter.format(portfolioProvider.totalCurrentValue, compact: true),
                              icon: Icons.show_chart_rounded,
                              color: AppColors.primary,
                              subtitle: CurrencyFormatter.formatWithSign(portfolioProvider.totalPnL),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Budget alerts
                        if (budgetProvider.overBudget.isNotEmpty || budgetProvider.nearLimit.isNotEmpty) ...[
                          _sectionHeader('⚡ Budget Alerts'),
                          const SizedBox(height: 10),
                          ...budgetProvider.overBudget.take(2).map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _alertBanner(
                              '${s.budget.category} budget exceeded!',
                              'Spent ${CurrencyFormatter.format(s.spent)} of ${CurrencyFormatter.format(s.budget.limitAmount)}',
                              AppColors.expense,
                              Icons.warning_amber_rounded,
                            ),
                          )),
                          ...budgetProvider.nearLimit.take(2).map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _alertBanner(
                              '${s.budget.category} nearing limit',
                              '${(s.usageRatio * 100).toStringAsFixed(0)}% used — ${CurrencyFormatter.format(s.remaining)} left',
                              AppColors.warning,
                              Icons.info_outline_rounded,
                            ),
                          )),
                          const SizedBox(height: 12),
                        ],

                        // Insights
                        if (insights.isNotEmpty) ...[
                          _sectionHeader('💡 Insights'),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 100,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: insights.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (_, i) {
                                final insight = insights[i];
                                final color = insight.type == 'warning' ? AppColors.expense
                                    : insight.type == 'tip' ? AppColors.primary
                                    : AppColors.info;
                                return Container(
                                  width: 220,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: color.withOpacity(0.3)),
                                  ),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Text(insight.emoji ?? '💡', style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(insight.title, style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    ]),
                                    const SizedBox(height: 6),
                                    Text(insight.body, style: GoogleFonts.inter(color: AppColors.text2, fontSize: 11), maxLines: 3, overflow: TextOverflow.ellipsis),
                                  ]),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Recent transactions
                        _sectionHeader('Recent Transactions'),
                        const SizedBox(height: 10),
                        if (txProvider.isLoading)
                          const Center(child: CircularProgressIndicator(color: AppColors.primary))
                        else if (txProvider.transactions.isEmpty)
                          _emptyState()
                        else
                          ...txProvider.transactions.take(5).map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TransactionTile(
                              transaction: t,
                              onDelete: () => txProvider.deleteTransaction(t.id),
                              onTap: () => AddTransactionSheet.show(context, existing: t),
                            ),
                          )),
                        const SizedBox(height: 100),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(
    title,
    style: GoogleFonts.inter(color: AppColors.text1, fontSize: 16, fontWeight: FontWeight.w700),
  );

  Widget _alertBanner(String title, String subtitle, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.inter(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          Text(subtitle, style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12)),
        ])),
      ]),
    );
  }

  Widget _emptyState() => Container(
    padding: const EdgeInsets.all(32),
    alignment: Alignment.center,
    child: Column(children: [
      const Text('💸', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      Text('No transactions yet', style: GoogleFonts.inter(color: AppColors.text1, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('Tap + to add your first one', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 13)),
    ]),
  );
}
