import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/categories.dart';
import '../../providers/transaction_provider.dart';
import '../../models/transaction_model.dart';

class AddTransactionSheet extends StatefulWidget {
  final TransactionModel? existing;
  const AddTransactionSheet({super.key, this.existing});

  static Future<void> show(BuildContext context, {TransactionModel? existing}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(existing: existing),
    );
  }

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  String _type = 'expense';
  String _selectedCategory = 'food';
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final t = widget.existing!;
      _type = t.type;
      _selectedCategory = t.category;
      _amountController.text = t.amount.toStringAsFixed(0);
      _noteController.text = t.note ?? '';
      _selectedDate = t.date;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<AppCategory> get _categories =>
      _type == 'expense' ? Categories.expense : Categories.income;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: AppColors.text1,
            surface: AppColors.surface2,
            onSurface: AppColors.text1,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<TransactionProvider>();

    try {
      if (widget.existing != null) {
        await provider.updateTransaction(widget.existing!.copyWith(
          type: _type,
          amount: amount,
          category: _selectedCategory,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          date: _selectedDate,
        ));
      } else {
        await provider.addTransaction(
          type: _type,
          amount: amount,
          category: _selectedCategory,
          date: _selectedDate,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              widget.existing != null ? 'Edit Transaction' : 'New Transaction',
              style: GoogleFonts.inter(
                color: AppColors.text1, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),

            // Type Toggle
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _typeButton('expense', '💸 Expense', AppColors.expense),
                  _typeButton('income', '💰 Income', AppColors.income),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Amount field
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.inter(
                color: AppColors.text1, fontSize: 28, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: '0',
                prefixText: '₹  ',
                prefixStyle: GoogleFonts.inter(
                  color: AppColors.text2, fontSize: 28, fontWeight: FontWeight.w400),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
              autofocus: widget.existing == null,
            ),
            const Divider(color: AppColors.border),
            const SizedBox(height: 16),

            // Category picker
            Text('Category', style: GoogleFonts.inter(
              color: AppColors.text2, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final selected = _selectedCategory == cat.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: selected ? cat.color.withOpacity(0.2) : AppColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? cat.color : AppColors.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(cat.emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 4),
                        Text(
                          cat.name.split(' ').first,
                          style: GoogleFonts.inter(
                            color: selected ? cat.color : AppColors.text2,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Note field
            TextField(
              controller: _noteController,
              style: GoogleFonts.inter(color: AppColors.text1, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Add a note (optional)',
                prefixIcon: Icon(Icons.notes_outlined, color: AppColors.text2),
              ),
            ),
            const SizedBox(height: 12),

            // Date picker
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: AppColors.text2, size: 18),
                    const SizedBox(width: 12),
                    Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: GoogleFonts.inter(color: AppColors.text1, fontSize: 14),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: AppColors.text3),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.existing != null ? 'Update' : 'Save Transaction'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeButton(String type, String label, Color color) {
    final selected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _type = type;
          _selectedCategory = type == 'expense' ? 'food' : 'salary';
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: selected ? color : AppColors.text2,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
