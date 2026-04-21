import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/goal_model.dart';
import '../../providers/portfolio_provider.dart';

class EditGoalSheet extends StatefulWidget {
  final GoalModel rawGoal;
  final ValueChanged<GoalModel> onSave;
  const EditGoalSheet({super.key, required this.rawGoal, required this.onSave});

  static Future<void> show(BuildContext context, GoalModel raw, ValueChanged<GoalModel> onSave) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<PortfolioProvider>(),
          child: EditGoalSheet(rawGoal: raw, onSave: onSave),
        ),
      );

  @override
  State<EditGoalSheet> createState() => _EditGoalSheetState();
}

class _EditGoalSheetState extends State<EditGoalSheet> {
  late final TextEditingController _title;
  late final TextEditingController _target;
  late final TextEditingController _saved;
  late String _category;
  late String _emoji;
  late DateTime? _targetDate;
  late Set<String> _selectedIds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final g = widget.rawGoal;
    _title      = TextEditingController(text: g.title);
    _target     = TextEditingController(text: g.targetAmount.toStringAsFixed(0));
    _saved      = TextEditingController(
        text: g.currentAmount > 0 ? g.currentAmount.toStringAsFixed(0) : '');
    _category   = g.category;
    _emoji      = g.emoji;
    _targetDate = g.targetDate;
    _selectedIds = Set.from(g.linkedHoldingIds);
  }

  @override
  void dispose() { _title.dispose(); _target.dispose(); _saved.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || double.tryParse(_target.text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter title and target amount')));
      return;
    }
    setState(() => _saving = true);
    widget.onSave(GoalModel(
      id: widget.rawGoal.id,
      title: _title.text.trim(),
      emoji: _emoji,
      category: _category,
      targetAmount: double.parse(_target.text),
      currentAmount: double.tryParse(_saved.text) ?? 0,
      targetDate: _targetDate,
      linkedHoldingIds: _selectedIds.toList(),
      notes: widget.rawGoal.notes,
      createdAt: widget.rawGoal.createdAt,
    ));
    if (mounted) Navigator.pop(context);
  }

  static String _c(double v) {
    if (v >= 1e7) return '${(v / 1e7).toStringAsFixed(1)}Cr';
    if (v >= 1e5) return '${(v / 1e5).toStringAsFixed(1)}L';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
          Text('Edit Goal', style: GoogleFonts.inter(
            color: AppColors.text1, fontSize: 20, fontWeight: FontWeight.w800)),
          const Spacer(),
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.text3))),
        ])),
        const SizedBox(height: 8),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Category
            Text('Category', style: GoogleFonts.inter(color: AppColors.text2,
              fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: GoalModel.categories.map((c) {
              final sel = _category == c['id'];
              return GestureDetector(
                onTap: () => setState(() { _category = c['id']!; _emoji = c['emoji']!; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFF6C63FF).withValues(alpha: 0.1) : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? const Color(0xFF6C63FF) : AppColors.border)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(c['emoji']!, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(c['label']!, style: GoogleFonts.inter(
                      color: sel ? const Color(0xFF6C63FF) : AppColors.text2,
                      fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
                  ]),
                ),
              );
            }).toList()),
            const SizedBox(height: 16),

            // Title
            Text('Goal Title *', style: GoogleFonts.inter(color: AppColors.text2,
              fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(controller: _title, decoration: InputDecoration(
              filled: true, fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)))),
            const SizedBox(height: 12),

            // Target + Savings
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Target Amount *', style: GoogleFonts.inter(color: AppColors.text2,
                  fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(controller: _target, keyboardType: TextInputType.number,
                  decoration: InputDecoration(prefixText: '₹ ',
                    filled: true, fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border)))),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Manual Savings', style: GoogleFonts.inter(color: AppColors.text2,
                  fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(controller: _saved, keyboardType: TextInputType.number,
                  decoration: InputDecoration(prefixText: '₹ ', hintText: '0',
                    filled: true, fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border)))),
              ])),
            ]),
            const SizedBox(height: 12),

            // Date
            Text('Target Date', style: GoogleFonts.inter(color: AppColors.text2,
              fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(context: context,
                  initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 365)),
                  firstDate: DateTime.now(), lastDate: DateTime(2060));
                if (d != null) setState(() => _targetDate = d);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  const Icon(Icons.calendar_month_rounded, color: AppColors.text3, size: 18),
                  const SizedBox(width: 8),
                  Text(_targetDate != null
                    ? '${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}'
                    : 'No deadline',
                    style: GoogleFonts.inter(
                      color: _targetDate != null ? AppColors.text1 : AppColors.text3,
                      fontSize: 13)),
                  const Spacer(),
                  if (_targetDate != null)
                    GestureDetector(
                      onTap: () => setState(() => _targetDate = null),
                      child: const Icon(Icons.clear_rounded, size: 16, color: AppColors.text3)),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // Link investments
            Text('Link Investments', style: GoogleFonts.inter(color: AppColors.text2,
              fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Tap to toggle — their current value auto-counts toward this goal',
              style: GoogleFonts.inter(color: AppColors.text3, fontSize: 11)),
            const SizedBox(height: 8),
            Consumer<PortfolioProvider>(builder: (_, pp, __) {
              final holdings = pp.holdings;
              if (holdings.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border)),
                  child: Text('No investments found — add some in Portfolio first',
                    style: GoogleFonts.inter(color: AppColors.text3, fontSize: 12)));
              }
              return Column(children: holdings.map((h) {
                final sel = _selectedIds.contains(h.id);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (sel) _selectedIds.remove(h.id); else _selectedIds.add(h.id);
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFF6C63FF).withValues(alpha: 0.08) : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? const Color(0xFF6C63FF) : AppColors.border,
                        width: sel ? 1.5 : 1)),
                    child: Row(children: [
                      Text(h.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(h.name, style: GoogleFonts.inter(color: AppColors.text1,
                          fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(h.assetClassName,
                          style: GoogleFonts.inter(color: AppColors.text3, fontSize: 10)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('₹${_c(h.currentValue)}', style: GoogleFonts.inter(
                          color: sel ? const Color(0xFF6C63FF) : AppColors.text2,
                          fontSize: 12, fontWeight: FontWeight.w700)),
                        if (sel) Text('linked ✓',
                          style: GoogleFonts.inter(color: const Color(0xFF6C63FF), fontSize: 10)),
                      ]),
                    ]),
                  ),
                );
              }).toList());
            }),
          ]),
        )),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: _saving
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Save Changes',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
          )),
        ),
      ]),
    );
  }
}
