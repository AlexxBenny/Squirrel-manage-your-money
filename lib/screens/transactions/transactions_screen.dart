import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/transaction_tile.dart';
import '../transactions/add_transaction_sheet.dart';
import '../../models/transaction_model.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _filter = 'all'; // 'all' | 'income' | 'expense'
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
    if (_filter == 'income') list = list.where((t) => t.isIncome).toList();
    if (_filter == 'expense') list = list.where((t) => t.isExpense).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) =>
        (t.note?.toLowerCase().contains(q) ?? false) || t.category.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Map<String, List<TransactionModel>> _groupByDate(List<TransactionModel> txns) {
    final map = <String, List<TransactionModel>>{};
    for (final t in txns) {
      final key = DateHelpers.relative(t.date);
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: GoogleFonts.inter(color: AppColors.text1, fontSize: 16),
                decoration: const InputDecoration(hintText: 'Search transactions...', border: InputBorder.none, filled: false, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : Text('Transactions', style: GoogleFonts.inter(color: AppColors.text1, fontSize: 22, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: AppColors.text2),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) { _searchQuery = ''; _searchController.clear(); }
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => AddTransactionSheet.show(context),
        child: const Icon(Icons.add),
      ),
      body: Consumer<TransactionProvider>(
        builder: (_, provider, __) {
          return Column(
            children: [
              // Month selector
              _MonthSelector(
                current: provider.selectedMonth,
                onChanged: provider.changeMonth,
              ),

              // Totals bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  _totalChip('Income', provider.totalIncome, AppColors.income),
                  const SizedBox(width: 8),
                  _totalChip('Expenses', provider.totalExpenses, AppColors.expense),
                  const SizedBox(width: 8),
                  _totalChip('Saved', provider.netSavings, provider.netSavings >= 0 ? AppColors.income : AppColors.expense),
                ]),
              ),

              // Filter chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(children: [
                  _filterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _filterChip('Income', 'income'),
                  const SizedBox(width: 8),
                  _filterChip('Expense', 'expense'),
                ]),
              ),

              const SizedBox(height: 8),

              // Transaction list
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _buildList(provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(TransactionProvider provider) {
    final filtered = _filtered(provider.transactions);
    if (filtered.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🔍', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text('No transactions found', style: GoogleFonts.inter(color: AppColors.text1, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Try adjusting your filters', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 13)),
      ]));
    }
    final grouped = _groupByDate(filtered);
    final keys = grouped.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final key = keys[i];
        final txns = grouped[key]!;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Text(key, style: GoogleFonts.inter(color: AppColors.text2, fontSize: 13, fontWeight: FontWeight.w600)),
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
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.15) : AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(label, style: GoogleFonts.inter(color: selected ? AppColors.primary : AppColors.text2, fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }

  Widget _totalChip(String label, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(CurrencyFormatter.format(amount, compact: true), style: GoogleFonts.inter(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
          Text(label, style: GoogleFonts.inter(color: AppColors.text2, fontSize: 11)),
        ]),
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime current;
  final ValueChanged<DateTime> onChanged;
  const _MonthSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        IconButton(
          onPressed: () => onChanged(DateTime(current.year, current.month - 1)),
          icon: const Icon(Icons.chevron_left, color: AppColors.text2),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: Text(
            DateHelpers.monthYear(current),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.text1, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          onPressed: current.month == DateTime.now().month && current.year == DateTime.now().year
              ? null
              : () => onChanged(DateTime(current.year, current.month + 1)),
          icon: Icon(Icons.chevron_right, color: current.month == DateTime.now().month && current.year == DateTime.now().year ? AppColors.text3 : AppColors.text2),
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }
}
