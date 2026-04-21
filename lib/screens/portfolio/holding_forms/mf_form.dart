import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/holding_model.dart';
import '../add_holding_sheet.dart';
import '../mf_search_dialog.dart';

class MfForm extends StatefulWidget {
  const MfForm({super.key});
  @override
  MfFormState createState() => MfFormState();
}

class MfFormState extends State<MfForm> {
  final _name       = TextEditingController();
  final _fundHouse  = TextEditingController();
  final _folio      = TextEditingController();
  final _schemeCode = TextEditingController();
  final _units      = TextEditingController();
  final _avgNav     = TextEditingController();
  final _currentNav = TextEditingController();
  final _sipAmount  = TextEditingController();
  final _lumpAmount = TextEditingController();
  final _notes      = TextEditingController();

  String _plan     = 'direct';   // direct | regular
  String _category = 'equity_large_cap';
  String _type     = 'sip';      // sip | lumpsum
  bool   _isELSS   = false;
  int    _sipDay   = 5;
  DateTime _sipStart = DateTime.now();

  static const _plans = ['direct', 'regular'];
  static const _categories = [
    'equity_large_cap', 'equity_mid_cap', 'equity_small_cap',
    'equity_flexi', 'index', 'elss', 'debt_short', 'debt_long', 'hybrid', 'fof',
  ];
  static const _catLabels = [
    'Large Cap', 'Mid Cap', 'Small Cap', 'Flexi Cap',
    'Index / ETF', 'ELSS (Tax Saver)', 'Debt Short', 'Debt Long', 'Hybrid', 'FoF',
  ];

  @override
  void dispose() {
    for (final c in [_name, _fundHouse, _folio, _schemeCode, _units, _avgNav,
      _currentNav, _sipAmount, _lumpAmount, _notes]) { c.dispose(); }
    super.dispose();
  }

  HoldingModel? buildHolding(String id) {
    if (_name.text.trim().isEmpty) { _err('Enter fund name'); return null; }
    final units    = double.tryParse(_units.text) ?? 0;
    final avgNav   = double.tryParse(_avgNav.text) ?? 0;
    final curNav   = double.tryParse(_currentNav.text);
    final sipAmt   = double.tryParse(_sipAmount.text);
    final lumpAmt  = double.tryParse(_lumpAmount.text) ?? 0;

    if (_type == 'sip' && (sipAmt == null || sipAmt <= 0)) { _err('Enter SIP amount'); return null; }
    if (avgNav <= 0 || units <= 0) { _err('Enter units and avg NAV'); return null; }

    final invested = _type == 'sip'
        ? _estimateSipInvested(sipAmt!, _sipStart, _sipDay)
        : lumpAmt;

    final currentVal = units * (curNav ?? avgNav);

    final meta = <String, dynamic>{
      'fund_house': _fundHouse.text.trim(),
      'folio': _folio.text.trim(),
      'scheme_code': _schemeCode.text.trim(),
      'plan': _plan,
      'category': _isELSS ? 'elss' : _category,
      'investment_type': _type,
      'units': units,
      'avg_nav': avgNav,
      'current_nav': curNav ?? avgNav,
      'is_elss': _isELSS || _category == 'elss',
    };
    if (_type == 'sip') {
      meta['sip_amount'] = sipAmt;
      meta['sip_day']    = _sipDay;
      meta['sip_start']  = _sipStart.toIso8601String();
    }

    return HoldingModel(
      id: id,
      name: _name.text.trim(),
      assetClass: 'mutual_fund',
      investedAmount: invested,
      currentValueOverride: currentVal,
      sipDay: _type == 'sip' ? _sipDay : null,
      alertEnabled: true,
      meta: meta,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      createdAt: DateTime.now(),
    );
  }

  double _estimateSipInvested(double sipAmt, DateTime start, int day) {
    final now = DateTime.now();
    int count = 0;
    DateTime d = DateTime(start.year, start.month, day);
    while (!d.isAfter(now)) { count++; d = DateTime(d.year, d.month + 1, day); }
    return count * sipAmt;
  }

  void _err(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickSipStart() async {
    final d = await showDatePicker(
      context: context, initialDate: _sipStart,
      firstDate: DateTime(2010), lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _sipStart = d);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Search button ──────────────────────────────────────────────────────
      GestureDetector(
        onTap: () async {
          final result = await MfSearchDialog.show(context);
          if (result != null) {
            setState(() {
              _name.text = result.schemeName;
              _schemeCode.text = result.schemeCode.toString();
              if (result.fundHouse != null) _fundHouse.text = result.fundHouse!;
              if (result.plan != null) _plan = result.plan!;
            });
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF00D9A3), Color(0xFF0EA5E9)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Icon(Icons.search_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Search from 16,000+ Funds', style: GoogleFonts.inter(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              Text('Auto-fills name, code, fund house & plan',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
            ])),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
          ]),
        ),
      ),
      const SizedBox(height: 16),

      formLabel('Fund Name *'),
      TextField(controller: _name, decoration: fieldDec('e.g. Mirae Asset Large Cap Fund')),
      const SizedBox(height: 12),

      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Fund House'),
          TextField(controller: _fundHouse, decoration: fieldDec('Mirae, HDFC, SBI…')),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Folio Number'),
          TextField(controller: _folio, decoration: fieldDec('Optional')),
        ])),
      ]),
      const SizedBox(height: 12),

      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('mfapi Scheme Code'),
          TextField(controller: _schemeCode, keyboardType: TextInputType.number,
            decoration: fieldDec('119598 (for live NAV)')),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Plan'),
          _TogglePill(options: _plans, labels: const ['Direct', 'Regular'],
            selected: _plan, onChanged: (v) => setState(() => _plan = v)),
        ])),
      ]),
      const SizedBox(height: 12),

      formLabel('Fund Category'),
      DropdownButtonFormField<String>(
        value: _category,
        decoration: fieldDec('Select category'),
        dropdownColor: Colors.white,
        items: List.generate(_categories.length, (i) => DropdownMenuItem(
          value: _categories[i], child: Text(_catLabels[i],
            style: GoogleFonts.inter(fontSize: 13)))),
        onChanged: (v) => setState(() {
          _category = v!;
          if (v == 'elss') _isELSS = true;
        }),
      ),
      const SizedBox(height: 12),

      Row(children: [
        Checkbox(value: _isELSS, onChanged: (v) => setState(() => _isELSS = v!),
          activeColor: const Color(0xFF00D9A3)),
        Text('ELSS / Tax Saver (80C)', style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13)),
      ]),

      formSection('Investment Details'),

      formLabel('Investment Type'),
      _TogglePill(options: const ['sip', 'lumpsum'], labels: const ['SIP', 'Lump Sum'],
        selected: _type, onChanged: (v) => setState(() => _type = v)),
      const SizedBox(height: 12),

      if (_type == 'sip') ...[
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            formLabel('Monthly SIP Amount *'),
            TextField(controller: _sipAmount, keyboardType: TextInputType.number,
              decoration: fieldDec('5000', prefix: '₹ ')),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            formLabel('SIP Date (day of month)'),
            DropdownButtonFormField<int>(
              value: _sipDay, decoration: fieldDec('Day'),
              dropdownColor: Colors.white,
              items: List.generate(28, (i) => DropdownMenuItem(
                value: i + 1, child: Text('${i + 1}', style: GoogleFonts.inter(fontSize: 13)))),
              onChanged: (v) => setState(() => _sipDay = v!),
            ),
          ])),
        ]),
        const SizedBox(height: 12),
        formLabel('SIP Start Date'),
        GestureDetector(
          onTap: _pickSipStart,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(children: [
              const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text('${_sipStart.day}/${_sipStart.month}/${_sipStart.year}',
                style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
      ] else ...[
        formLabel('Lump Sum Amount *'),
        TextField(controller: _lumpAmount, keyboardType: TextInputType.number,
          decoration: fieldDec('50000', prefix: '₹ ')),
        const SizedBox(height: 12),
      ],

      formSection('NAV & Units'),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Units Held *'),
          TextField(controller: _units, keyboardType: TextInputType.number,
            decoration: fieldDec('145.234')),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Avg Buy NAV *'),
          TextField(controller: _avgNav, keyboardType: TextInputType.number,
            decoration: fieldDec('62.45', prefix: '₹ ')),
        ])),
      ]),
      const SizedBox(height: 12),
      formLabel('Current NAV (leave blank to auto-fetch)'),
      TextField(controller: _currentNav, keyboardType: TextInputType.number,
        decoration: fieldDec('78.90', prefix: '₹ ')),
      const SizedBox(height: 12),
      formLabel('Notes (optional)'),
      TextField(controller: _notes, decoration: fieldDec('Any additional info')),
      const SizedBox(height: 8),
    ]);
  }
}

// Shared toggle pill widget
class _TogglePill extends StatelessWidget {
  final List<String> options;
  final List<String> labels;
  final String selected;
  final ValueChanged<String> onChanged;
  const _TogglePill({required this.options, required this.labels,
    required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
      child: Row(children: List.generate(options.length, (i) {
        final sel = selected == options[i];
        return Expanded(child: GestureDetector(
          onTap: () => onChanged(options[i]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: sel ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: sel ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)] : [],
            ),
            alignment: Alignment.center,
            child: Text(labels[i], style: GoogleFonts.inter(
              color: sel ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
          ),
        ));
      })),
    );
  }
}
