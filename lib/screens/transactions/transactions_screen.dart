import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/transaction_tile.dart';
import '../../widgets/wave_widgets.dart';
import '../transactions/add_transaction_sheet.dart';
import '../../models/transaction_model.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _filter = 'all';
  String _searchQuery = '';
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadTransactions();
    });
  }

  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  List<TransactionModel> _filtered(List<TransactionModel> all) {
    var list = all;
    if (_filter == 'income')  list = list.where((t) => t.isIncome).toList();
    if (_filter == 'expense') list = list.where((t) => t.isExpense).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) =>
        (t.note?.toLowerCase().contains(q) ?? false) ||
        t.category.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Map<String, List<TransactionModel>> _groupByDate(List<TransactionModel> txns) {
    final map = <String, List<TransactionModel>>{};
    for (final t in txns) {
      map.putIfAbsent(DateHelpers.relative(t.date), () => []).add(t);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<TransactionProvider>(
        builder: (_, provider, __) {
          final filtered = _filtered(provider.transactions);
          return CustomScrollView(
            slivers: [
              // ── Wave Header ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: ClipPath(
                  clipper: WaveClipper(),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 56),
                    decoration: const BoxDecoration(gradient: AppColors.headerGradient),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: _isSearching
                          ? TextField(
                              controller: _searchController,
                              autofocus: true,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                              decoration: const InputDecoration(
                                hintText: 'Search transactions…',
                                hintStyle: TextStyle(color: Colors.white54),
                                border: InputBorder.none,
                                filled: false,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (v) => setState(() => _searchQuery = v),
                            )
                          : Text('Transactions', style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                        ),
                        GestureDetector(
                          onTap: () => setState(() {
                            _isSearching = !_isSearching;
                            if (!_isSearching) { _searchQuery = ''; _searchController.clear(); }
                          }),
                          child: Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      // Month selector
                      _MonthSelector(
                        current: provider.selectedMonth,
                        onChanged: provider.changeMonth,
                      ),
                      const SizedBox(height: 16),
                      // Stats row (glass)
                      Row(children: [
                        _GlassStat('Income', CurrencyFormatter.format(provider.totalIncome, compact: true), AppColors.income),
                        const SizedBox(width: 8),
                        _GlassStat('Spent',  CurrencyFormatter.format(provider.totalExpenses, compact: true), AppColors.expense),
                        const SizedBox(width: 8),
                        _GlassStat('Saved',  CurrencyFormatter.format(provider.netSavings, compact: true),
                            provider.netSavings >= 0 ? Colors.white : AppColors.expense),
                      ]),
                    ]),
                  ),
                ),
              ),

              // ── Filter chips ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(children: [
                    _filterChip('All', 'all'),
                    const SizedBox(width: 8),
                    _filterChip('Income', 'income'),
                    const SizedBox(width: 8),
                    _filterChip('Expenses', 'expense'),
                  ]),
                ),
              ),

              // ── Transactions list ─────────────────────────────────────────
              if (provider.isLoading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
              else if (filtered.isEmpty)
                SliverFillRemaining(child: _emptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final grouped = _groupByDate(filtered);
                        final keys = grouped.keys.toList();
                        final key = keys[i];
                        final txns = grouped[key]!;
                        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySurface,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(key, style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                              const Spacer(),
                              Text(
                                CurrencyFormatter.formatWithSign(txns.fold(0.0, (s, t) => s + (t.isIncome ? t.amount : -t.amount))),
                                style: GoogleFonts.inter(color: AppColors.text3, fontSize: 12),
                              ),
                            ]),
                          ),
                          ...txns.map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TransactionTile(
                              transaction: t,
                              onDelete: () => provider.deleteTransaction(t.id),
                              onTap: () => AddTransactionSheet.show(context, existing: t),
                            ),
                          )),
                        ]);
                      },
                      childCount: _groupByDate(filtered).length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => AddTransactionSheet.show(context),
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          boxShadow: selected ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))] : [],
        ),
        child: Text(label, style: GoogleFonts.inter(
          color: selected ? Colors.white : AppColors.text2,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        )),
      ),
    );
  }

  Widget _emptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 72, height: 72,
      decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(24)),
      child: const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 36)),
    const SizedBox(height: 16),
    Text('No transactions found', style: GoogleFonts.inter(color: AppColors.text1, fontSize: 16, fontWeight: FontWeight.w600)),
    const SizedBox(height: 4),
    Text('Try adjusting your filters', style: GoogleFonts.inter(color: AppColors.text3, fontSize: 13)),
  ]));
}

class _GlassStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _GlassStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: GoogleFonts.inter(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
      Text(label, style: GoogleFonts.inter(color: Colors.white60, fontSize: 11)),
    ]),
  ));
}

class _MonthSelector extends StatelessWidget {
  final DateTime current;
  final ValueChanged<DateTime> onChanged;
  const _MonthSelector({required this.current, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final isCurrentMonth = current.month == DateTime.now().month && current.year == DateTime.now().year;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: () => onChanged(DateTime(current.year, current.month - 1)),
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 20),
        ),
      ),
      const SizedBox(width: 12),
      Text(DateHelpers.monthYear(current), style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(width: 12),
      GestureDetector(
        onTap: isCurrentMonth ? null : () => onChanged(DateTime(current.year, current.month + 1)),
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: isCurrentMonth ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.chevron_right_rounded, color: isCurrentMonth ? Colors.white30 : Colors.white, size: 20),
        ),
      ),
    ]);
  }
}
