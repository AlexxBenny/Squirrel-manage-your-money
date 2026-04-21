import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/goal_model.dart';
import '../../providers/goal_provider.dart';
import '../../providers/portfolio_provider.dart';
import '../../widgets/wave_widgets.dart';
import 'edit_goal_sheet.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});
  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  bool _fabVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GoalProvider>().loadGoals();
      setState(() => _fabVisible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: AnimatedScale(
        scale: _fabVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: FloatingActionButton(
          onPressed: () => _showAddSheet(context),
          backgroundColor: const Color(0xFF6C63FF),
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
      body: Consumer2<GoalProvider, PortfolioProvider>(
        builder: (_, gp, pp, __) {
          final goals = gp.goals;
          final holdings = pp.holdings;
          return CustomScrollView(slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, gp, holdings)),
            if (goals.isEmpty)
              SliverFillRemaining(child: Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('🎯', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 16),
                  Text('No goals yet', style: GoogleFonts.inter(
                    color: AppColors.text1, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Set a financial goal and track your progress',
                    style: GoogleFonts.inter(color: AppColors.text3, fontSize: 13)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _showAddSheet(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add First Goal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              )))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    // Build effective goal with portfolio value included
                    final raw = goals[i];
                    final effectiveSaved = gp.effectiveSaved(raw, holdings);
                    final effective = raw.copyWith(currentAmount: effectiveSaved);
                    final portfolioContrib = gp.portfolioContribution(raw, holdings);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _GoalCard(
                        goal: effective,
                        rawGoal: raw,
                        portfolioContrib: portfolioContrib,
                        onTopUp: (amt) => gp.topUp(raw.id, amt, holdings),
                        onDelete: () => gp.deleteGoal(raw.id),
                        onEdit: (updated) => gp.updateGoal(updated),
                      ),
                    );
                  },
                  childCount: goals.length,
                )),
              ),
          ]);
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, GoalProvider gp, holdings) {
    final total    = gp.totalTargeted(holdings);
    final saved    = gp.totalSaved(holdings);
    final pct      = total > 0 ? saved / total : 0.0;
    return ClipPath(
      clipper: WaveClipper(),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 52),
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Goals', style: GoogleFonts.inter(
            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          if (gp.goals.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Overall Progress', style: GoogleFonts.inter(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct.clamp(0.0, 1.0),
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                  minHeight: 8))),
              const SizedBox(width: 10),
              Text('${(pct * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _GlassChip(CurrencyFormatter.format(saved, compact: true), 'Saved'),
              const SizedBox(width: 8),
              _GlassChip(CurrencyFormatter.format(total - saved, compact: true), 'Remaining'),
              const SizedBox(width: 8),
              _GlassChip('${gp.goals.length}', 'Goals'),
            ]),
          ],
        ]),
      ),
    );
  }

  void _showAddSheet(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AddGoalSheet(),
  );
}

// ── Goal Card ─────────────────────────────────────────────────────────────────
class _GoalCard extends StatefulWidget {
  final GoalModel goal;
  final GoalModel rawGoal;
  final double portfolioContrib;
  final ValueChanged<double> onTopUp;
  final VoidCallback onDelete;
  final ValueChanged<GoalModel> onEdit;
  const _GoalCard({
    required this.goal, required this.rawGoal, required this.portfolioContrib,
    required this.onTopUp, required this.onDelete, required this.onEdit,
  });
  @override
  State<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<_GoalCard> with SingleTickerProviderStateMixin {
  bool _expanded = false;

  GoalModel get g => widget.goal;

  @override
  Widget build(BuildContext context) {
    final pct = g.progressPct;
    final isCompleted = g.isCompleted;
    final days = g.daysLeft;
    final monthly = g.monthlySavingNeeded;
    final color = isCompleted ? AppColors.income : const Color(0xFF6C63FF);

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _expanded ? color.withValues(alpha: 0.5) :
                   isCompleted ? AppColors.income.withValues(alpha: 0.3) : AppColors.border,
            width: _expanded ? 1.5 : 1),
          boxShadow: [BoxShadow(
            color: _expanded ? color.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
            blurRadius: _expanded ? 16 : 8, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header ──
            Row(children: [
              Text(g.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.title, style: GoogleFonts.inter(
                  color: AppColors.text1, fontSize: 15, fontWeight: FontWeight.w800)),
                Text(GoalModel.categories.firstWhere(
                  (c) => c['id'] == g.category, orElse: () => {'label': 'Other'})['label']!,
                  style: GoogleFonts.inter(color: AppColors.text3, fontSize: 12)),
              ])),
              if (isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.income.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20)),
                  child: Text('✅ Done', style: GoogleFonts.inter(
                    color: AppColors.income, fontSize: 10, fontWeight: FontWeight.w700))),
              const SizedBox(width: 4),
              Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: AppColors.text3, size: 20),
            ]),
            const SizedBox(height: 12),

            // ── Progress bar ──
            ClipRRect(borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct, minHeight: 10,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(color))),
            const SizedBox(height: 8),
            Row(children: [
              Text('₹${_compact(g.currentAmount)}',
                style: GoogleFonts.inter(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
              Text(' / ₹${_compact(g.targetAmount)}',
                style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12)),
              const Spacer(),
              Text('${(pct * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.inter(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
            ]),

            // ── Portfolio badge ──
            if (widget.portfolioContrib > 0) ...[
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.show_chart_rounded, size: 10, color: Color(0xFF6C63FF)),
                    const SizedBox(width: 4),
                    Text('₹${_compact(widget.portfolioContrib)} from portfolio',
                      style: GoogleFonts.inter(color: const Color(0xFF6C63FF),
                        fontSize: 10, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(width: 6),
                if ((g.currentAmount - widget.portfolioContrib) > 0)
                  Text('+ ₹${_compact(g.currentAmount - widget.portfolioContrib)} manual',
                    style: GoogleFonts.inter(color: AppColors.text3, fontSize: 10)),
              ]),
            ],

            // ── Expanded section ──
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // ── Insight chips grid ──
                Wrap(spacing: 8, runSpacing: 8, children: [
                  // Amount remaining
                  if (!isCompleted)
                    _InsightChip('🎯', 'Remaining',
                      '₹${_compact(g.remaining)}', AppColors.text2),

                  // Days left / deadline
                  if (days != null)
                    _InsightChip('⏰', days > 0 ? 'Days Left' : 'Status',
                      days > 0 ? '$days days' : 'Overdue!',
                      days > 0 ? AppColors.text2 : AppColors.expense)
                  else
                    _InsightChip('📆', 'Deadline', 'Open-ended', AppColors.text3),

                  // Monthly savings needed
                  if (monthly != null && !isCompleted)
                    _InsightChip('📅', 'Need / Month',
                      '₹${_compact(monthly)}', const Color(0xFF6C63FF))
                  else if (!isCompleted && g.targetDate == null)
                    _InsightChip('📅', 'Monthly Need', 'Set a deadline', AppColors.text3),

                  // Portfolio contribution
                  if (widget.portfolioContrib > 0)
                    _InsightChip('📈', 'From Portfolio',
                      '₹${_compact(widget.portfolioContrib)}', const Color(0xFF00D9A3)),

                  // Manual savings
                  if (widget.portfolioContrib > 0 && (g.currentAmount - widget.portfolioContrib) > 0)
                    _InsightChip('💰', 'Manual Savings',
                      '₹${_compact(g.currentAmount - widget.portfolioContrib)}', AppColors.text2),

                  // On-track status (only when we have both monthly needed and some savings)
                  if (monthly != null && !isCompleted && g.currentAmount > 0) (() {
                    // Estimate avg monthly savings from creation to now
                    final monthsSince = DateTime.now()
                        .difference(g.createdAt).inDays / 30.44;
                    if (monthsSince < 0.5) return const SizedBox.shrink();
                    final avgMonthly = g.currentAmount / monthsSince;
                    final onTrack = avgMonthly >= monthly;
                    return _InsightChip(
                      onTrack ? '✅' : '⚠️',
                      'Pace',
                      onTrack ? 'On Track' : '₹${_compact(monthly - avgMonthly)}/mo short',
                      onTrack ? AppColors.income : const Color(0xFFFFB800),
                    );
                  })(),

                  // Completion %
                  _InsightChip('📊', 'Progress',
                    '${(g.progressPct * 100).toStringAsFixed(1)}%',
                    isCompleted ? AppColors.income : color),
                ]),

                const SizedBox(height: 14),
                // Action buttons
                Row(children: [
                  if (!isCompleted) Expanded(child: _ActionBtn(
                    label: 'Top Up', icon: Icons.add_rounded, color: color,
                    onTap: () => _showTopUp(context))),
                  if (!isCompleted) const SizedBox(width: 8),
                  Expanded(child: _ActionBtn(
                    label: 'Edit', icon: Icons.edit_rounded,
                    color: AppColors.text2,
                    onTap: () => _showEdit(context))),
                  const SizedBox(width: 8),
                  Expanded(child: _ActionBtn(
                    label: 'Delete', icon: Icons.delete_outline_rounded,
                    color: AppColors.expense,
                    onTap: widget.onDelete)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _showTopUp(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.background,
      title: Text('Top Up "${g.title}"',
        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
      content: TextField(controller: ctrl, keyboardType: TextInputType.number,
        decoration: InputDecoration(prefixText: '₹ ', hintText: '5000',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppColors.text3))),
        ElevatedButton(
          onPressed: () {
            final amt = double.tryParse(ctrl.text);
            if (amt != null && amt > 0) { widget.onTopUp(amt); Navigator.pop(context); }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
          child: const Text('Add', style: TextStyle(color: Colors.white))),
      ],
    ));
  }

  void _showEdit(BuildContext context) => EditGoalSheet.show(
    context, widget.rawGoal, widget.onEdit);

  String _compact(double v) {
    if (v >= 1e7) return '${(v / 1e7).toStringAsFixed(1)}Cr';
    if (v >= 1e5) return '${(v / 1e5).toStringAsFixed(1)}L';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _ActionBtn extends StatelessWidget {
  final String label; final IconData icon; final Color color; final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      alignment: Alignment.center,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

class _InsightChip extends StatelessWidget {
  final String emoji, label, value;
  final Color color;
  const _InsightChip(this.emoji, this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(color: AppColors.text3, fontSize: 9, fontWeight: FontWeight.w500)),
      ]),
      const SizedBox(height: 2),
      Text(value, style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
    ]),
  );
}



class _GlassChip extends StatelessWidget {
  final String value, label;
  const _GlassChip(this.value, this.label);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
      Text(label, style: GoogleFonts.inter(color: Colors.white60, fontSize: 10)),
    ]),
  ));
}

// ── Add Goal Sheet ────────────────────────────────────────────────────────────
class _AddGoalSheet extends StatefulWidget {
  const _AddGoalSheet();
  @override
  State<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<_AddGoalSheet> {
  final _title  = TextEditingController();
  final _target = TextEditingController();
  final _saved  = TextEditingController();
  final _notes  = TextEditingController();
  String _category = 'other';
  String _emoji = '🎯';
  DateTime? _targetDate;
  bool _saving = false;
  final Set<String> _selectedIds = {};

  static String _compactStatic(double v) {
    if (v >= 1e7) return '${(v / 1e7).toStringAsFixed(1)}Cr';
    if (v >= 1e5) return '${(v / 1e5).toStringAsFixed(1)}L';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  void dispose() { _title.dispose(); _target.dispose(); _saved.dispose(); _notes.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || double.tryParse(_target.text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter title and target amount')));
      return;
    }
    setState(() => _saving = true);
    final gp = context.read<GoalProvider>();
    await gp.addGoal(GoalModel(
      id: gp.newId(), title: _title.text.trim(),
      emoji: _emoji, category: _category,
      targetAmount: double.parse(_target.text),
      currentAmount: double.tryParse(_saved.text) ?? 0,
      targetDate: _targetDate, notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      linkedHoldingIds: _selectedIds.toList(),
      createdAt: DateTime.now(),
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(children: [
        const SizedBox(height: 12),
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Text('New Goal', style: GoogleFonts.inter(color: AppColors.text1, fontSize: 20, fontWeight: FontWeight.w800)),
            const Spacer(),
            TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.text3))),
          ])),
        const SizedBox(height: 8),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Category grid
            Text('Category', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12, fontWeight: FontWeight.w600)),
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
            Text('Goal Title *', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(controller: _title, decoration: InputDecoration(
              hintText: 'e.g. Buy a House in 5 years',
              filled: true, fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            )),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Target Amount *', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(controller: _target, keyboardType: TextInputType.number,
                  decoration: InputDecoration(prefixText: '₹ ', hintText: '5000000',
                    filled: true, fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  )),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Already Saved', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(controller: _saved, keyboardType: TextInputType.number,
                  decoration: InputDecoration(prefixText: '₹ ', hintText: '0',
                    filled: true, fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  )),
              ])),
            ]),
            const SizedBox(height: 12),
            Text('Target Date (optional)', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(context: context,
                  initialDate: DateTime.now().add(const Duration(days: 365)),
                  firstDate: DateTime.now(), lastDate: DateTime(2060));
                if (d != null) setState(() => _targetDate = d);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  const Icon(Icons.calendar_month_rounded, color: AppColors.text3, size: 18),
                  const SizedBox(width: 8),
                  Text(_targetDate != null
                    ? '${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}'
                    : 'No deadline (open-ended)',
                    style: GoogleFonts.inter(color: _targetDate != null ? AppColors.text1 : AppColors.text3, fontSize: 13)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            // ── Link Investments ──────────────────────────────
            Text('Link Investments (optional)',
              style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Their current value auto-counts toward this goal',
              style: GoogleFonts.inter(color: AppColors.text3, fontSize: 11)),
            const SizedBox(height: 8),
            Consumer<PortfolioProvider>(
              builder: (_, pp, __) {
                final holdings = pp.holdings;
                if (holdings.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border)),
                    child: Text('No investments yet — add some in Portfolio first',
                      style: GoogleFonts.inter(color: AppColors.text3, fontSize: 12)),
                  );
                }
                return Column(children: holdings.map((h) {
                  final sel = _selectedIds.contains(h.id);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (sel) _selectedIds.remove(h.id);
                      else _selectedIds.add(h.id);
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
                          Text(h.name, style: GoogleFonts.inter(
                            color: AppColors.text1, fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(h.assetClassName,
                            style: GoogleFonts.inter(color: AppColors.text3, fontSize: 10)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('₹${_compactStatic(h.currentValue)}',
                            style: GoogleFonts.inter(
                              color: sel ? const Color(0xFF6C63FF) : AppColors.text2,
                              fontSize: 12, fontWeight: FontWeight.w700)),
                          if (sel) Text('linked ✓',
                            style: GoogleFonts.inter(color: const Color(0xFF6C63FF), fontSize: 10)),
                        ]),
                      ]),
                    ),
                  );
                }).toList());
              },
            ),
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
                : Text('Create Goal', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
          )),
        ),
      ]),
    );
  }
}
