import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/lend_model.dart';
import '../../providers/lend_provider.dart';

// ── Currency formatter ────────────────────────────────────────────────────────
final _fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
String _f(double v) => _fmt.format(v);

class LendScreen extends StatefulWidget {
  const LendScreen({super.key});

  @override
  State<LendScreen> createState() => _LendScreenState();
}

class _LendScreenState extends State<LendScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LendProvider>().loadLendings();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(onAdd: () => _AddLendSheet.show(context)),
            const SizedBox(height: 12),
            const _SummaryRow(),
            const SizedBox(height: 12),
            _TabBar(controller: _tab),
            Expanded(child: _TabContent(controller: _tab)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _AddLendSheet.show(context),
        backgroundColor: AppColors.primary,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final VoidCallback onAdd;
  const _Header({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lend & Borrow',
                    style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text1)),
                Text('Track money you owe or are owed',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.text3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary Row ───────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  const _SummaryRow();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LendProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
              child: _SummaryCard(
            label: 'You Lent',
            amount: p.totalLentOut,
            icon: Icons.arrow_upward_rounded,
            color: AppColors.income,
            bgColor: const Color(0xFFECFDF5),
          )),
          const SizedBox(width: 10),
          Expanded(
              child: _SummaryCard(
            label: 'You Owe',
            amount: p.totalBorrowed,
            icon: Icons.arrow_downward_rounded,
            color: AppColors.expense,
            bgColor: const Color(0xFFFEF2F2),
          )),
          const SizedBox(width: 10),
          Expanded(
              child: _SummaryCard(
            label: 'Net',
            amount: p.netPosition,
            icon: Icons.account_balance_wallet_rounded,
            color: p.netPosition >= 0 ? AppColors.income : AppColors.expense,
            bgColor: p.netPosition >= 0
                ? const Color(0xFFECFDF5)
                : const Color(0xFFFEF2F2),
          )),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final Color bgColor;
  const _SummaryCard(
      {required this.label,
      required this.amount,
      required this.icon,
      required this.color,
      required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(height: 8),
          Text(_f(amount.abs()),
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: GoogleFonts.inter(fontSize: 10, color: AppColors.text3)),
        ],
      ),
    );
  }
}

// ── Tab Bar ───────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final TabController controller;
  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.text2,
        labelStyle:
            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Pending'),
          Tab(text: 'Overdue'),
          Tab(text: 'Settled'),
        ],
      ),
    );
  }
}

// ── Tab Content ───────────────────────────────────────────────────────────────
class _TabContent extends StatelessWidget {
  final TabController controller;
  const _TabContent({required this.controller});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LendProvider>();
    if (p.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return TabBarView(
      controller: controller,
      children: [
        _LendList(items: p.pending),
        _LendList(items: p.overdue),
        _LendList(items: p.settled),
      ],
    );
  }
}

// ── Lend List ─────────────────────────────────────────────────────────────────
class _LendList extends StatelessWidget {
  final List<LendModel> items;
  const _LendList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.handshake_outlined, size: 56, color: AppColors.text3),
            const SizedBox(height: 12),
            Text('Nothing here',
                style: GoogleFonts.inter(color: AppColors.text2, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Tap + to add a record',
                style: GoogleFonts.inter(color: AppColors.text3, fontSize: 12)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _LendCard(item: items[i]),
    );
  }
}

// ── Lend Card ─────────────────────────────────────────────────────────────────
class _LendCard extends StatelessWidget {
  final LendModel item;
  const _LendCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<LendProvider>();
    final isLent = item.isLent;
    final color = isLent ? AppColors.income : AppColors.expense;
    final bgColor =
        isLent ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);

    return Dismissible(
      key: Key(item.id),
      background: _swipeBg(
          color: AppColors.income,
          icon: Icons.check_circle_rounded,
          label: item.isPending ? 'Settle' : 'Re-open',
          align: Alignment.centerLeft),
      secondaryBackground: _swipeBg(
          color: AppColors.expense,
          icon: Icons.delete_rounded,
          label: 'Delete',
          align: Alignment.centerRight),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          if (item.isPending) {
            await provider.markSettled(item.id);
          } else {
            await provider.markPending(item.id);
          }
          return false; // don't remove — list rebuilds via provider
        } else {
          return await _confirmDelete(context);
        }
      },
      onDismissed: (dir) {
        if (dir == DismissDirection.endToStart) {
          provider.deleteLending(item.id);
        }
      },
      child: GestureDetector(
        onTap: () => _AddLendSheet.show(context, existing: item),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: bgColor, borderRadius: BorderRadius.circular(12)),
                child: Icon(
                    isLent
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: color,
                    size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.personName,
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text1),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (item.isOverdue)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.expense.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('OVERDUE',
                                style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.expense)),
                          ),
                        if (item.isSettled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.income.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('SETTLED',
                                style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.income)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isLent ? 'You lent' : 'You borrowed',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.text3),
                    ),
                    if (item.note != null && item.note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(item.note!,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.text2),
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 10, color: AppColors.text3),
                            const SizedBox(width: 3),
                            Text(DateFormat('d MMM y').format(item.date),
                                style: GoogleFonts.inter(
                                    fontSize: 10, color: AppColors.text3)),
                          ],
                        ),
                        if (item.dueDate != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule_rounded,
                                  size: 10,
                                  color: item.isOverdue
                                      ? AppColors.expense
                                      : AppColors.text3),
                              const SizedBox(width: 3),
                              Text(
                                  'Due ${DateFormat('d MMM y').format(item.dueDate!)}',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: item.isOverdue
                                          ? AppColors.expense
                                          : AppColors.text3)),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(_f(item.amount),
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _swipeBg(
      {required Color color,
      required IconData icon,
      required String label,
      required Alignment align}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Delete Record',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            content: Text('Remove this lending record permanently?',
                style: GoogleFonts.inter()),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete',
                      style: TextStyle(color: AppColors.expense))),
            ],
          ),
        ) ??
        false;
  }
}

// ── Add / Edit Bottom Sheet ───────────────────────────────────────────────────
class _AddLendSheet extends StatefulWidget {
  final LendModel? existing;
  const _AddLendSheet({this.existing});

  static Future<void> show(BuildContext context, {LendModel? existing}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddLendSheet(existing: existing),
    );
  }

  @override
  State<_AddLendSheet> createState() => _AddLendSheetState();
}

class _AddLendSheetState extends State<_AddLendSheet> {
  final _formKey = GlobalKey<FormState>();
  final _namCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _type = 'lent';
  DateTime _date = DateTime.now();
  DateTime? _dueDate;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.existing!;
      _type = e.type;
      _namCtrl.text = e.personName;
      _amtCtrl.text = e.amount.toStringAsFixed(0);
      _noteCtrl.text = e.note ?? '';
      _date = e.date;
      _dueDate = e.dueDate;
    }
  }

  @override
  void dispose() {
    _namCtrl.dispose();
    _amtCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text(_isEditing ? 'Edit Record' : 'New Record',
                  style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text1)),
              const SizedBox(height: 20),

              // Type toggle
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _TypeBtn(
                        label: '↑ I Lent',
                        selected: _type == 'lent',
                        color: AppColors.income,
                        onTap: () => setState(() => _type = 'lent')),
                    _TypeBtn(
                        label: '↓ I Borrowed',
                        selected: _type == 'borrowed',
                        color: AppColors.expense,
                        onTap: () => setState(() => _type = 'borrowed')),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Person name
              TextFormField(
                controller: _namCtrl,
                decoration: const InputDecoration(
                  labelText: 'Person Name',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Amount
              TextFormField(
                controller: _amtCtrl,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixIcon: Icon(Icons.currency_rupee_rounded),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Note
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Date row
              Row(
                children: [
                  Expanded(
                    child: _DatePickerTile(
                      label: 'Date',
                      date: _date,
                      icon: Icons.calendar_today_rounded,
                      onPick: () async {
                        final d = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100));
                        if (d != null) setState(() => _date = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DatePickerTile(
                      label: _dueDate == null ? 'Due Date (opt)' : 'Due Date',
                      date: _dueDate,
                      icon: Icons.event_rounded,
                      onPick: () async {
                        final d = await showDatePicker(
                            context: context,
                            initialDate: _dueDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100));
                        if (d != null) setState(() => _dueDate = d);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_isEditing ? 'Save Changes' : 'Add Record'),
                ),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => _delete(),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.expense,
                        side: const BorderSide(color: AppColors.expense)),
                    child: const Text('Delete Record'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<LendProvider>();
    try {
      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          type: _type,
          personName: _namCtrl.text.trim(),
          amount: double.parse(_amtCtrl.text.trim()),
          date: _date,
          dueDate: _dueDate,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
        await provider.updateLending(updated);
      } else {
        await provider.addLending(
          type: _type,
          personName: _namCtrl.text.trim(),
          amount: double.parse(_amtCtrl.text.trim()),
          date: _date,
          dueDate: _dueDate,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _delete() async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Delete Record',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            content: const Text('This cannot be undone.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete',
                      style: TextStyle(color: AppColors.expense))),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;
    await context.read<LendProvider>().deleteLending(widget.existing!.id);
    if (mounted) Navigator.pop(context);
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────
class _TypeBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TypeBtn(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.text2)),
        ),
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final IconData icon;
  final VoidCallback onPick;
  const _DatePickerTile(
      {required this.label,
      required this.date,
      required this.icon,
      required this.onPick});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.text2),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 10, color: AppColors.text3)),
                  Text(
                      date != null
                          ? DateFormat('d MMM y').format(date!)
                          : 'Tap to pick',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              date != null ? AppColors.text1 : AppColors.text3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
