import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/categories.dart';
import '../../providers/category_provider.dart';

class ManageCategoriesSheet extends StatefulWidget {
  const ManageCategoriesSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<CategoryProvider>(),
      child: const ManageCategoriesSheet(),
    ),
  );

  @override
  State<ManageCategoriesSheet> createState() => _ManageCategoriesSheetState();
}

class _ManageCategoriesSheetState extends State<ManageCategoriesSheet> {
  final _nameCtrl = TextEditingController();
  String _emoji = '💸';
  Color _color = AppColors.primary;
  bool _isIncome = false;
  bool _saving = false;

  static const _emojis = [
    '💸','🍕','🏔️','✈️','🏖️','🎉','💪','📸','🎸','🌿','🛒','🐾',
    '🍷','☕','🎯','🏋️','🌊','🌸','🎓','🏦','🧘','🛵','🔧','🎨',
  ];
  static const _colors = [
    Color(0xFF2563EB), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444),
    Color(0xFF8B5CF6), Color(0xFF06B6D4), Color(0xFFEC4899), Color(0xFF14B8A6),
    Color(0xFFF97316), Color(0xFF6366F1), Color(0xFF64748B), Color(0xFF0F172A),
  ];

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await context.read<CategoryProvider>().createCategory(
        name: name, emoji: _emoji, color: _color, isIncome: _isIncome);
      _nameCtrl.clear();
      setState(() { _emoji = '💸'; _color = AppColors.primary; _isIncome = false; });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category name already exists')));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.only(bottom: bottom > 0 ? bottom : 16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28)),
      child: Consumer<CategoryProvider>(
        builder: (_, provider, __) => SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(children: [
                Text('Custom Categories', style: GoogleFonts.inter(color: AppColors.text1, fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                GestureDetector(onTap: () => Navigator.pop(context),
                  child: Container(width: 32, height: 32,
                    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.close_rounded, size: 18, color: AppColors.text2))),
              ]),
            ),

            // Create form
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('New Category', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),

                  // Emoji + name
                  Row(children: [
                    GestureDetector(
                      onTap: () {
                        final i = _emojis.indexOf(_emoji);
                        setState(() => _emoji = _emojis[(i + 1) % _emojis.length]);
                      },
                      child: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: _color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: _color.withValues(alpha: 0.3))),
                        alignment: Alignment.center,
                        child: Text(_emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(
                      controller: _nameCtrl,
                      style: GoogleFonts.inter(color: AppColors.text1, fontSize: 15, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'e.g. Gym, Pet Care, Side Hustle',
                        hintStyle: GoogleFonts.inter(color: AppColors.text3, fontSize: 13),
                        filled: true, fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    )),
                  ]),
                  const SizedBox(height: 12),

                  // Type toggle
                  Container(
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(4),
                    child: Row(children: [
                      _typeBtn('Expense', false),
                      _typeBtn('Income', true),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // Color picker
                  Wrap(spacing: 8, runSpacing: 8, children: _colors.map((c) {
                    final sel = _color == c;
                    return GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: AnimatedContainer(duration: const Duration(milliseconds: 150),
                        width: 28, height: 28,
                        decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                          border: Border.all(color: sel ? AppColors.text1 : Colors.transparent, width: 2.5),
                          boxShadow: sel ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6)] : []),
                        child: sel ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null),
                    );
                  }).toList()),
                  const SizedBox(height: 14),

                  SizedBox(width: double.infinity, child: ElevatedButton(
                    onPressed: _saving ? null : _create,
                    style: ElevatedButton.styleFrom(backgroundColor: _color, foregroundColor: Colors.white, minimumSize: const Size(0, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Create Category', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  )),
                ]),
              ),
            ),

            // Existing custom categories
            if (provider.customCategories.isNotEmpty) ...[
              const SizedBox(height: 20),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Text('Your Custom Categories', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('${provider.customCategories.length}', style: GoogleFonts.inter(color: AppColors.text3, fontSize: 12)),
                ])),
              const SizedBox(height: 8),
              ...provider.customCategories.map((cat) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cat.color.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(cat.name, style: GoogleFonts.inter(color: AppColors.text1, fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(cat.isIncome ? 'Income' : 'Expense',
                        style: GoogleFonts.inter(color: cat.color, fontSize: 11, fontWeight: FontWeight.w600)),
                    ])),
                    GestureDetector(
                      onTap: () => _confirmDelete(context, provider, cat),
                      child: Container(width: 30, height: 30,
                        decoration: BoxDecoration(color: AppColors.expense.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.delete_outline_rounded, color: AppColors.expense, size: 16)),
                    ),
                  ]),
                ),
              )),
            ],
            const SizedBox(height: 16),

            // Info banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 14),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Custom categories work exactly like built-in ones — use them in transactions, budgets, and analytics.',
                    style: GoogleFonts.inter(color: AppColors.primary, fontSize: 11, height: 1.4),
                  )),
                ]),
              ),
            ),
            const SizedBox(height: 16),
          ],
        )),
      ),
    );
  }

  Widget _typeBtn(String label, bool income) {
    final sel = _isIncome == income;
    final color = income ? AppColors.income : AppColors.expense;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _isIncome = income),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: sel ? Border.all(color: color.withValues(alpha: 0.3)) : null,
        ),
        child: Text(label, textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: sel ? color : AppColors.text2, fontSize: 13, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
      ),
    ));
  }

  Future<void> _confirmDelete(BuildContext ctx, CategoryProvider provider, AppCategory cat) async {
    final ok = await showDialog<bool>(context: ctx, builder: (d) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Delete "${cat.name}"?', style: GoogleFonts.inter(color: AppColors.text1, fontWeight: FontWeight.w700)),
      content: Text('Existing transactions with this category will keep their data but the category won\'t appear in pickers.',
        style: GoogleFonts.inter(color: AppColors.text2, fontSize: 13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense, foregroundColor: Colors.white, minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
          onPressed: () => Navigator.pop(d, true),
          child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        ),
      ],
    ));
    if (ok == true) await provider.deleteCategory(cat.id);
  }
}
