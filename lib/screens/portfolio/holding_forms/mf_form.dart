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
  DateTime _sipStart   = DateTime.now();
  DateTime _stepUpDate = DateTime.now();  // effective date for new step-up
  final List<Map<String, dynamic>> _sipHistory = [];  // [{date, amount, note}]

  static const _plans = ['direct', 'regular'];

  // Full SEBI-compliant category list
  static const _categories = [
    // ── Equity ──────────────────────────────────────────────────────────────
    'equity_large_cap', 'equity_mid_cap', 'equity_small_cap', 'equity_multi_cap',
    'equity_flexi', 'equity_large_mid', 'equity_sectoral', 'equity_value',
    'equity_focused', 'elss',
    // ── Hybrid ───────────────────────────────────────────────────────────────
    'hybrid', 'hybrid_balanced_advantage', 'hybrid_equity_savings',
    'hybrid_arbitrage', 'hybrid_multi_asset', 'hybrid_conservative',
    // ── Debt ─────────────────────────────────────────────────────────────────
    'debt_liquid', 'debt_short', 'debt_medium', 'debt_long',
    'debt_dynamic', 'debt_corporate_bond', 'debt_credit_risk',
    'debt_banking_psu', 'debt_gilt',
    // ── Passive / Index ───────────────────────────────────────────────────────
    'index',
    // ── Commodity (Gold / Silver) ─────────────────────────────────────────────
    'commodity_gold_etf', 'commodity_gold_fof',
    'commodity_silver_etf', 'commodity_silver_fof',
    // ── International & Other ─────────────────────────────────────────────────
    'international_fof', 'fof',
  ];
  static const _catLabels = [
    // ── Equity ──────────────────────────────────────────────────────────────
    'Large Cap', 'Mid Cap', 'Small Cap', 'Multi Cap',
    'Flexi Cap', 'Large & Mid Cap', 'Sectoral / Thematic', 'Value / Contra',
    'Focused Fund', 'ELSS (Tax Saver)',
    // ── Hybrid ───────────────────────────────────────────────────────────────
    'Aggressive Hybrid', 'Balanced Advantage (BAF)', 'Equity Savings',
    'Arbitrage', 'Multi-Asset Allocation', 'Conservative Hybrid',
    // ── Debt ─────────────────────────────────────────────────────────────────
    'Liquid / Overnight', 'Short Duration', 'Medium Duration', 'Long Duration',
    'Dynamic Bond', 'Corporate Bond', 'Credit Risk',
    'Banking & PSU', 'Gilt / Govt Securities',
    // ── Passive / Index ───────────────────────────────────────────────────────
    'Index Fund / ETF',
    // ── Commodity (Gold / Silver) ─────────────────────────────────────────────
    '🥇 Gold ETF', '🥇 Gold Fund of Fund',
    '🥈 Silver ETF', '🥈 Silver Fund of Fund',
    // ── International & Other ─────────────────────────────────────────────────
    '🌐 International / Global FoF', 'Fund of Funds (Other)',
  ];

  @override
  void dispose() {
    for (final c in [_name, _fundHouse, _folio, _schemeCode, _units, _avgNav,
      _currentNav, _sipAmount, _lumpAmount, _notes]) { c.dispose(); }
    super.dispose();
  }

  /// Pre-fills the form from an existing holding for editing.
  void loadFrom(HoldingModel h) {
    _name.text      = h.name;
    _fundHouse.text = h.mfFundHouse ?? '';
    _folio.text     = h.mfFolio ?? '';
    _schemeCode.text = h.mfSchemeCode ?? '';
    if (h.mfPlan != null) _plan = h.mfPlan!;
    if (h.mfCategory != null && _categories.contains(h.mfCategory)) {
      _category = h.mfCategory!;
    }
    _isELSS = h.mfIsELSS;
    if (h.mfType != null) _type = h.mfType!;
    final avgNav = (h.meta['avg_nav'] as num?)?.toDouble() ?? 0;
    if (avgNav > 0) _avgNav.text = avgNav.toStringAsFixed(4);
    if ((h.mfUnits ?? 0) > 0) _units.text = h.mfUnits!.toStringAsFixed(3);
    if ((h.mfCurrentNav ?? 0) > 0) _currentNav.text = h.mfCurrentNav!.toStringAsFixed(4);
    // Load SIP history
    _sipHistory.clear();
    _sipHistory.addAll(h.mfSipHistory);
    if (_type == 'sip') {
      if ((h.mfSipAmount ?? 0) > 0) _sipAmount.text = h.mfSipAmount!.toStringAsFixed(0);
      if (h.sipDay != null) _sipDay = h.sipDay!;
      _sipStart = h.mfSipStart ?? DateTime.now();
      _stepUpDate = DateTime.now();
    } else {
      if (h.investedAmount > 0) _lumpAmount.text = h.investedAmount.toStringAsFixed(0);
    }
    _notes.text = h.notes ?? '';
    setState(() {});
  }

  HoldingModel? buildHolding(String id) {
    if (_name.text.trim().isEmpty) { _err('Enter fund name'); return null; }
    final units    = double.tryParse(_units.text) ?? 0;
    final avgNav   = double.tryParse(_avgNav.text) ?? 0;
    final curNav   = double.tryParse(_currentNav.text);
    final sipAmt   = double.tryParse(_sipAmount.text);

    if (_type == 'sip' && (sipAmt == null || sipAmt <= 0)) { _err('Enter SIP amount'); return null; }
    if (avgNav <= 0 || units <= 0) { _err('Enter units and avg NAV'); return null; }

    // units × avgBuyNAV = exact money paid in, regardless of SIP or lumpsum.
    // SIP/lumpsum amounts are kept in meta for future alerts/projections.
    final invested = units * avgNav;

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
      // ── SIP History (auto-maintained step-up log) ───────────────────────
      final history = List<Map<String, dynamic>>.from(_sipHistory);
      final dateStr  = _stepUpDate.toIso8601String().split('T')[0];
      if (history.isEmpty) {
        // First ever save → seed history with the initial amount
        history.add({
          'date': _sipStart.toIso8601String().split('T')[0],
          'amount': sipAmt,
          'note': 'Started SIP',
        });
      } else {
        final lastAmt = (history.last['amount'] as num).toDouble();
        if (sipAmt != lastAmt) {
          // Amount changed → record step-up / step-down
          final pct = lastAmt > 0 ? ((sipAmt! - lastAmt) / lastAmt * 100) : 0;
          final sign = pct >= 0 ? '+' : '';
          final label = pct >= 0 ? 'step-up' : 'reduced';
          history.add({
            'date': dateStr,
            'amount': sipAmt,
            'note': '$sign${pct.toStringAsFixed(1)}% $label',
          });
        }
      }
      meta['sip_history'] = history;
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
              // Fund house: from API meta (isEnriched) or name parsing fallback
              if (result.fundHouse != null) _fundHouse.text = result.fundHouse!;
              if (result.plan != null) _plan = result.plan!;
              // Category: from official SEBI scheme_category via API (no guessing)
              if (result.category != null &&
                  _categories.contains(result.category)) {
                _category = result.category!;
              }
              // Sync ELSS checkbox
              _isELSS = result.isElss || _category == 'elss';
              // Current NAV: from most recent data[] entry in the full scheme API
              if (result.latestNav != null) {
                _currentNav.text = result.latestNav!.toStringAsFixed(4);
              }
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
              Text('Auto-fills name, code, fund house, plan & category',
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

        // ── SIP History & Step-Up (only in edit mode when history exists) ──
        if (_sipHistory.isNotEmpty)
          _buildSipHistoryCard(),

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

  Widget _buildSipHistoryCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF86EFAC))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.history_rounded, size: 15, color: Color(0xFF16A34A)),
          const SizedBox(width: 6),
          Text('SIP History', style: GoogleFonts.inter(
            color: const Color(0xFF15803D), fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('${_sipHistory.length} entr${_sipHistory.length == 1 ? 'y' : 'ies'}',
            style: GoogleFonts.inter(color: const Color(0xFF86EFAC), fontSize: 10)),
        ]),
        const SizedBox(height: 10),

        // ── Timeline ────────────────────────────────────────────────────────
        ..._sipHistory.asMap().entries.map((entry) {
          final i    = entry.key;
          final e    = entry.value;
          final amt  = (e['amount'] as num).toDouble();
          final dt   = DateTime.tryParse(e['date'] as String? ?? '');
          final dtStr = dt != null
              ? '${dt.day} ${_monthName(dt.month)} ${dt.year}' : (e['date'] ?? '');
          final note  = e['note'] as String? ?? '';
          final isLast = i == _sipHistory.length - 1;
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(
                color: isLast ? const Color(0xFF16A34A) : const Color(0xFF86EFAC),
                shape: BoxShape.circle)),
              if (!isLast) Container(width: 2, height: 34, color: const Color(0xFF86EFAC)),
            ]),
            const SizedBox(width: 10),
            Expanded(child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('₹${amt.toStringAsFixed(0)}/mo',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0F172A), fontSize: 13,
                      fontWeight: isLast ? FontWeight.w800 : FontWeight.w500)),
                  Text(dtStr.toString(), style: GoogleFonts.inter(
                    color: const Color(0xFF64748B), fontSize: 10)),
                ])),
                if (note.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (note.contains('-') || note.contains('reduc'))
                          ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20)),
                    child: Text(note, style: GoogleFonts.inter(
                      color: (note.contains('-') || note.contains('reduc'))
                          ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                      fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
              ]),
            )),
          ]);
        }),

        // ── Step-Up Section ─────────────────────────────────────────────────
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(color: Color(0xFF86EFAC))),
        Text('Change SIP Amount', style: GoogleFonts.inter(
          color: const Color(0xFF374151), fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('New Monthly Amount', style: GoogleFonts.inter(
              color: const Color(0xFF64748B), fontSize: 10)),
            const SizedBox(height: 4),
            TextField(
              controller: _sipAmount,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: fieldDec('e.g. 6000', prefix: '₹ ')),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Effective From', style: GoogleFonts.inter(
              color: const Color(0xFF64748B), fontSize: 10)),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _stepUpDate,
                  firstDate: DateTime(2010),
                  lastDate: DateTime(2035));
                if (d != null) setState(() => _stepUpDate = d);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text('${_stepUpDate.day}/${_stepUpDate.month}/${_stepUpDate.year}',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A))),
                ]),
              ),
            ),
          ])),
        ]),
        const SizedBox(height: 6),

        // Live % change preview
        Builder(builder: (_) {
          final last = (_sipHistory.last['amount'] as num).toDouble();
          final cur  = double.tryParse(_sipAmount.text) ?? last;
          if (cur == last) {
            return Text('No change from current ₹${last.toStringAsFixed(0)}/mo',
              style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 10));
          }
          final pct  = (cur - last) / last * 100;
          final isUp = pct > 0;
          return Text(
            '${isUp ? '▲' : '▼'} ${pct.abs().toStringAsFixed(1)}% ${isUp ? 'increase' : 'decrease'}'
            ' · ₹${last.toStringAsFixed(0)} → ₹${cur.toStringAsFixed(0)}/mo',
            style: GoogleFonts.inter(
              color: isUp ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              fontSize: 10, fontWeight: FontWeight.w700));
        }),
      ]),
    );
  }

  static String _monthName(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];
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
