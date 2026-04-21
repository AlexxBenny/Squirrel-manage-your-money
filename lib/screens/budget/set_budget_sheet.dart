import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/categories.dart';
import '../../providers/budget_provider.dart';

class SetBudgetSheet extends StatefulWidget {
  final String? preselectedCategory;
  final String? existingId;
  final double? existingLimit;
  final String? existingPeriod;

  const SetBudgetSheet({super.key, this.preselectedCategory, this.existingId, this.existingLimit, this.existingPeriod});

  static Future<void> show(BuildContext context, {String? preselectedCategory, String? existingId, double? existingLimit, String? existingPeriod}) {
    return showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => SetBudgetSheet(preselectedCategory: preselectedCategory, existingId: existingId, existingLimit: existingLimit, existingPeriod: existingPeriod),
    );
  }

  @override
  State<SetBudgetSheet> createState() => _SetBudgetSheetState();
}

class _SetBudgetSheetState extends State<SetBudgetSheet> {
  String _selectedCategory = 'food';
  String _period = 'monthly';
  final _limitController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.preselectedCategory ?? 'food';
    _period = widget.existingPeriod ?? 'monthly';
    if (widget.existingLimit != null) _limitController.text = widget.existingLimit!.toStringAsFixed(0);
  }

  @override
  void dispose() { _limitController.dispose(); super.dispose(); }

  Future<void> _save() async {
    final limit = double.tryParse(_limitController.text);
    if (limit == null || limit <= 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid limit'))); return; }
    setState(() => _isSaving = true);
    try {
      await context.read<BudgetProvider>().upsertBudget(id: widget.existingId, category: _selectedCategory, limitAmount: limit, period: _period);
      if (mounted) Navigator.pop(context);
    } finally { if (mounted) setState(() => _isSaving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text(widget.existingId != null ? 'Edit Budget' : 'Set Budget', style: GoogleFonts.inter(color: AppColors.text1, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Text('Period', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(4),
            child: Row(children: [_periodBtn('monthly', 'Monthly'), _periodBtn('weekly', 'Weekly')]),
          ),
          const SizedBox(height: 16),
          Text('Category', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.85),
            itemCount: Categories.expense.length,
            itemBuilder: (_, i) {
              final cat = Categories.expense[i];
              final selected = _selectedCategory == cat.id;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: selected ? cat.color.withOpacity(0.2) : AppColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? cat.color : AppColors.border, width: selected ? 2 : 1),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(cat.name.split(' ').first, style: GoogleFonts.inter(color: selected ? cat.color : AppColors.text2, fontSize: 10, fontWeight: FontWeight.w500), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text('Spending Limit', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: _limitController, keyboardType: TextInputType.number,
            style: GoogleFonts.inter(color: AppColors.text1, fontSize: 16),
            decoration: const InputDecoration(hintText: '5000', prefixText: '₹  '),
          ),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(widget.existingId != null ? 'Update Budget' : 'Set Budget'),
          )),
        ]),
      ),
    );
  }

  Widget _periodBtn(String value, String label) {
    final selected = _period == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _period = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: selected ? AppColors.primary.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: Text(label, textAlign: TextAlign.center, style: GoogleFonts.inter(color: selected ? AppColors.primary : AppColors.text2, fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
        ),
      ),
    );
  }
}
