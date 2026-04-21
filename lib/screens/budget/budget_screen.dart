import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/budget_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/budget_progress_card.dart';
import '../budget/set_budget_sheet.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});
  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final tx = context.read<TransactionProvider>();
    final budget = context.read<BudgetProvider>();
    await tx.loadTransactions();
    await budget.loadBudgets(transactions: tx.transactions);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Budgets', style: GoogleFonts.inter(color: AppColors.text1, fontSize: 22, fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => SetBudgetSheet.show(context),
        icon: const Icon(Icons.add),
        label: Text('Add Budget', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
      body: Consumer2<BudgetProvider, TransactionProvider>(
        builder: (_, budgetProvider, txProvider, __) {
          if (budgetProvider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          // Period toggle
          return RefreshIndicator(
            onRefresh: _load,
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Period switch
                      Container(
                        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.all(4),
                        child: Row(children: [
                          _periodBtn(context, budgetProvider, 'monthly', 'Monthly'),
                          _periodBtn(context, budgetProvider, 'weekly', 'Weekly'),
                        ]),
                      ),
                      const SizedBox(height: 16),

                      // Summary row
                      if (budgetProvider.statuses.isNotEmpty) ...[
                        _BudgetSummaryRow(statuses: budgetProvider.statuses),
                        const SizedBox(height: 20),
                      ],
                    ]),
                  ),
                ),

                if (budgetProvider.budgets.isEmpty)
                  SliverFillRemaining(
                    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('🎯', style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 16),
                      Text('No budgets set', style: GoogleFonts.inter(color: AppColors.text1, fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('Tap + to set spending limits\nfor each category', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 13), textAlign: TextAlign.center),
                    ])),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final status = budgetProvider.statuses[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: BudgetProgressCard(
                              status: status,
                              onEdit: () => SetBudgetSheet.show(
                                context,
                                preselectedCategory: status.budget.category,
                                existingId: status.budget.id,
                                existingLimit: status.budget.limitAmount,
                                existingPeriod: status.budget.period,
                              ),
                              onDelete: () => _confirmDelete(context, budgetProvider, status.budget.id),
                            ),
                          );
                        },
                        childCount: budgetProvider.statuses.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _periodBtn(BuildContext context, BudgetProvider provider, String value, String label) {
    final selected = provider.period == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => provider.setPeriod(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label, textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: selected ? AppColors.primary : AppColors.text2, fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, BudgetProvider provider, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: Text('Delete Budget?', style: GoogleFonts.inter(color: AppColors.text1, fontWeight: FontWeight.w600)),
        content: Text('This budget will be removed.', style: GoogleFonts.inter(color: AppColors.text2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: GoogleFonts.inter(color: AppColors.expense))),
        ],
      ),
    );
    if (confirm == true) await provider.deleteBudget(id);
  }
}

class _BudgetSummaryRow extends StatelessWidget {
  final List statuses;
  const _BudgetSummaryRow({required this.statuses});

  @override
  Widget build(BuildContext context) {
    final over = statuses.where((s) => s.isOver).length;
    final warning = statuses.where((s) => s.isWarning).length;
    final safe = statuses.where((s) => s.isSafe).length;
    return Row(children: [
      _chip('$safe Safe', AppColors.income),
      const SizedBox(width: 8),
      _chip('$warning Warning', AppColors.warning),
      const SizedBox(width: 8),
      _chip('$over Over', AppColors.expense),
    ]);
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
    child: Text(label, style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
  );
}
