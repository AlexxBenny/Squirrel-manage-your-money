import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/holding_model.dart';
import '../add_holding_sheet.dart';

class FdForm extends StatefulWidget {
  const FdForm({super.key});
  @override
  FdFormState createState() => FdFormState();
}

class FdFormState extends State<FdForm> {
  final _bankName   = TextEditingController();
  final _principal  = TextEditingController();
  final _rate       = TextEditingController();
  final _tenure     = TextEditingController();
  String _compound  = 'quarterly';
  String _fdType    = 'regular';
  String _intType   = 'cumulative';
  bool   _senior    = false;
  DateTime _start   = DateTime.now();
  DateTime? _maturity;

  static const _compounds = ['monthly', 'quarterly', 'annually', 'cumulative'];
  static const _compLabels = ['Monthly', 'Quarterly', 'Annual', 'On Maturity'];
  static const _fdTypes = ['regular', 'tax_saver_80c', 'scss', 'corporate'];
  static const _fdTypeLabels = ['Regular', 'Tax Saver (80C)', 'SCSS', 'Corporate'];

  @override
  void dispose() {
    for (final c in [_bankName, _principal, _rate, _tenure]) c.dispose();
    super.dispose();
  }

  /// Compound interest: A = P(1 + r/n)^(nt)
  double _computeMaturity(double p, double rPct, int months) {
    final r = rPct / 100;
    final t = months / 12;
    final n = _compound == 'monthly' ? 12.0
        : _compound == 'quarterly' ? 4.0
        : _compound == 'annually' ? 1.0
        : 1.0; // cumulative = annual for approx
    if (_senior) { /* already factored into rate */ }
    return p * _pow(1 + r / n, n * t);
  }

  double _pow(double base, double exp) {
    double result = 1;
    double b = base;
    int e = exp.toInt();
    while (e > 0) { if (e % 2 == 1) result *= b; b *= b; e ~/= 2; }
    return result;
  }

  HoldingModel? buildHolding(String id) {
    final p       = double.tryParse(_principal.text);
    final rate    = double.tryParse(_rate.text);
    final months  = int.tryParse(_tenure.text);
    if (_bankName.text.trim().isEmpty) { _err('Enter bank name'); return null; }
    if (p == null || p <= 0) { _err('Enter principal amount'); return null; }
    if (rate == null || rate <= 0) { _err('Enter interest rate'); return null; }
    if (months == null || months <= 0) { _err('Enter tenure in months'); return null; }

    final maturity = _maturity ?? _start.add(Duration(days: (months * 30.44).round()));
    final matAmt   = _compound != 'cumulative'
        ? _computeMaturity(p, rate, months)
        : _computeMaturity(p, rate, months);

    return HoldingModel(
      id: id, name: '${_bankName.text.trim()} FD', assetClass: 'fd',
      investedAmount: p,
      currentValueOverride: matAmt,
      maturityDate: maturity,
      alertEnabled: true,
      meta: {
        'bank_name': _bankName.text.trim(),
        'principal': p,
        'interest_rate': rate,
        'tenure_months': months,
        'compounding': _compound,
        'fd_type': _fdType,
        'interest_type': _intType,
        'is_senior_citizen': _senior,
        'start_date': _start.toIso8601String(),
        'maturity_date': maturity.toIso8601String(),
        'maturity_amount': matAmt,
      },
      createdAt: DateTime.now(),
    );
  }

  void _err(String m) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickDate(bool isStart) async {
    final d = await showDatePicker(context: context,
      initialDate: isStart ? _start : (_maturity ?? _start.add(const Duration(days: 365))),
      firstDate: DateTime(2015), lastDate: DateTime(2040));
    if (d != null) setState(() { if (isStart) _start = d; else _maturity = d; });
  }

  @override
  Widget build(BuildContext context) {
    final p    = double.tryParse(_principal.text) ?? 0;
    final rate = double.tryParse(_rate.text) ?? 0;
    final mo   = int.tryParse(_tenure.text) ?? 0;
    final matAmt = (p > 0 && rate > 0 && mo > 0) ? _computeMaturity(p, rate, mo) : 0.0;
    final gain   = matAmt - p;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      formLabel('Bank / Institution *'),
      TextField(controller: _bankName, decoration: fieldDec('HDFC Bank, SBI, LIC…')),
      const SizedBox(height: 12),

      formLabel('FD Type'),
      DropdownButtonFormField<String>(
        value: _fdType, decoration: fieldDec('Type'), dropdownColor: Colors.white,
        items: List.generate(_fdTypes.length, (i) => DropdownMenuItem(
          value: _fdTypes[i], child: Text(_fdTypeLabels[i],
            style: GoogleFonts.inter(fontSize: 13)))),
        onChanged: (v) => setState(() => _fdType = v!),
      ),
      const SizedBox(height: 12),

      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Principal *'),
          TextField(controller: _principal, keyboardType: TextInputType.number,
            decoration: fieldDec('100000', prefix: '₹ '),
            onChanged: (_) => setState(() {})),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Interest Rate (% p.a.) *'),
          TextField(controller: _rate, keyboardType: TextInputType.number,
            decoration: fieldDec('7.1', suffix: '%'),
            onChanged: (_) => setState(() {})),
        ])),
      ]),
      const SizedBox(height: 12),

      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Tenure (months) *'),
          TextField(controller: _tenure, keyboardType: TextInputType.number,
            decoration: fieldDec('24'), onChanged: (_) => setState(() {})),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Compounding'),
          DropdownButtonFormField<String>(
            value: _compound, decoration: fieldDec(''), dropdownColor: Colors.white,
            items: List.generate(_compounds.length, (i) => DropdownMenuItem(
              value: _compounds[i], child: Text(_compLabels[i],
                style: GoogleFonts.inter(fontSize: 12)))),
            onChanged: (v) => setState(() => _compound = v!),
          ),
        ])),
      ]),
      const SizedBox(height: 12),

      Row(children: [
        Checkbox(value: _senior, onChanged: (v) => setState(() => _senior = v!),
          activeColor: const Color(0xFF4DA6FF)),
        Text('Senior Citizen Rate (+0.5%)', style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13)),
      ]),
      const SizedBox(height: 12),

      // Live maturity calculator preview
      if (matAmt > 0) Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF4DA6FF), Color(0xFF2563EB)]),
          borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Maturity Amount', style: GoogleFonts.inter(color: Colors.white60, fontSize: 11)),
            Text('₹${matAmt.toStringAsFixed(0)}', style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Interest Earned', style: GoogleFonts.inter(color: Colors.white60, fontSize: 11)),
            Text('+₹${gain.toStringAsFixed(0)}', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
      const SizedBox(height: 12),

      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Start Date'),
          GestureDetector(onTap: () => _pickDate(true), child: _datePill(_start)),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Maturity Date (auto or override)'),
          GestureDetector(onTap: () => _pickDate(false),
            child: _datePill(_maturity ?? (_tenure.text.isNotEmpty
              ? _start.add(Duration(days: (int.tryParse(_tenure.text) ?? 0) * 30))
              : _start))),
        ])),
      ]),
    ]);
  }

  Widget _datePill(DateTime d) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
    child: Row(children: [
      const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF64748B)),
      const SizedBox(width: 8),
      Text('${d.day}/${d.month}/${d.year}',
        style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13)),
    ]),
  );
}
