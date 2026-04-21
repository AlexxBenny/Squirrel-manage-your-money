import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/budget_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/budget_progress_card.dart';
import '../../widgets/wave_widgets.dart';
import '../budget/set_budget_sheet.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});
  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  bool _fabVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      setState(() => _fabVisible = true);
    });
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
      floatingActionButton: AnimatedScale(
        scale: _fabVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: FloatingActionButton.extended(
          onPressed: () => SetBudgetSheet.show(context),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text('Add Budget', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      body: Consumer2<BudgetProvider, TransactionProvider>(
        builder: (_, bp, txp, __) => RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(child: ClipPath(
              clipper: WaveClipper(),
              child: Container(
                padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 56),
                decoration: const BoxDecoration(gradient: AppColors.headerGradient),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Budgets', style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Track your spending limits', style: GoogleFonts.inter(color: Colors.white60, fontSize: 13)),
                  if (bp.statuses.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(children: [
                      _stat('${bp.statuses.where((s) => s.isSafe).length}', 'On Track', AppColors.income),
                      const SizedBox(width: 8),
                      _stat('${bp.statuses.where((s) => s.isWarning).length}', 'Warning', AppColors.warning),
                      const SizedBox(width: 8),
                      _stat('${bp.statuses.where((s) => s.isOver).length}', 'Over', AppColors.expense),
                    ]),
                  ],
                ]),
              ),
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  _periodBtn('monthly', 'Monthly', bp),
                  _periodBtn('weekly', 'Weekly', bp),
                ]),
              ),
            )),
            if (bp.isLoading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else if (bp.budgets.isEmpty)
              SliverFillRemaining(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 72, height: 72, decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.track_changes_rounded, color: AppColors.primary, size: 36)),
                const SizedBox(height: 16),
                Text('No budgets set', style: GoogleFonts.inter(color: AppColors.text1, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Tap + to set spending limits', style: GoogleFonts.inter(color: AppColors.text3, fontSize: 13)),
              ])))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverList(delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final s = bp.statuses[i];
                    return Padding(padding: const EdgeInsets.only(bottom: 12), child: BudgetProgressCard(
                      status: s,
                      onEdit: () => SetBudgetSheet.show(context, preselectedCategory: s.budget.category, existingId: s.budget.id, existingLimit: s.budget.limitAmount, existingPeriod: s.budget.period),
                      onDelete: () async {
                        final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: Text('Delete Budget?', style: GoogleFonts.inter(color: AppColors.text1, fontWeight: FontWeight.w700)),
                          content: Text('This budget will be removed.', style: GoogleFonts.inter(color: AppColors.text2)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense, foregroundColor: Colors.white, minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)), onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                          ],
                        ));
                        if (ok == true) await bp.deleteBudget(s.budget.id);
                      },
                    ));
                  },
                  childCount: bp.statuses.length,
                )),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _stat(String count, String label, Color color) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
    child: Column(children: [
      Text(count, style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
      Text(label, style: GoogleFonts.inter(color: color.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  ));

  Widget _periodBtn(String value, String label, BudgetProvider provider) {
    final sel = provider.period == value;
    return Expanded(child: GestureDetector(
      onTap: () => provider.setPeriod(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(gradient: sel ? AppColors.primaryGradient : null, borderRadius: BorderRadius.circular(12)),
        child: Text(label, textAlign: TextAlign.center, style: GoogleFonts.inter(color: sel ? Colors.white : AppColors.text2, fontSize: 14, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
      ),
    ));
  }
}
