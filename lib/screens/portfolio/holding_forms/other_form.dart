import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/holding_model.dart';
import '../add_holding_sheet.dart';

class OtherForm extends StatefulWidget {
  const OtherForm({super.key});
  @override
  OtherFormState createState() => OtherFormState();
}

class OtherFormState extends State<OtherForm> {
  String _instrument = 'ppf';
  final _name        = TextEditingController();
  final _balance     = TextEditingController();
  final _annualContr = TextEditingController();
  final _rate        = TextEditingController();
  final _accountNo   = TextEditingController();
  final _issuer      = TextEditingController();
  final _faceValue   = TextEditingController();
  final _coupon      = TextEditingController();
  final _platform    = TextEditingController();
  DateTime? _openDate;
  DateTime? _maturityDate;

  static const _instruments = ['ppf', 'nps', 'epf', 'bond', 'p2p'];
  static const _instLabels  = ['PPF', 'NPS', 'EPF', 'Bond/Debenture', 'P2P Lending'];
  static const _instEmojis  = ['📋', '🏛️', '👔', '📜', '🤝'];

  @override
  void dispose() {
    for (final c in [_name, _balance, _annualContr, _rate, _accountNo,
      _issuer, _faceValue, _coupon, _platform]) c.dispose();
    super.dispose();
  }

  HoldingModel? buildHolding(String id) {
    final balance = double.tryParse(_balance.text) ?? 0;
    if (balance <= 0) { _err('Enter current balance / corpus'); return null; }

    final meta = <String, dynamic>{
      'instrument': _instrument,
      'current_balance': balance,
      'interest_rate': double.tryParse(_rate.text),
    };

    switch (_instrument) {
      case 'ppf':
        meta['account_number'] = _accountNo.text.trim();
        meta['annual_contribution'] = double.tryParse(_annualContr.text) ?? 0;
        if (_openDate != null) meta['opening_date'] = _openDate!.toIso8601String();
        if (_maturityDate != null) meta['maturity_date'] = _maturityDate!.toIso8601String();
      case 'nps':
        meta['account_number'] = _accountNo.text.trim();
        meta['annual_contribution'] = double.tryParse(_annualContr.text) ?? 0;
      case 'epf':
        meta['account_number'] = _accountNo.text.trim();
        meta['annual_contribution'] = double.tryParse(_annualContr.text) ?? 0;
      case 'bond':
        meta['issuer'] = _issuer.text.trim();
        meta['face_value'] = double.tryParse(_faceValue.text) ?? 0;
        meta['coupon_rate'] = double.tryParse(_coupon.text) ?? 0;
        if (_maturityDate != null) meta['maturity_date'] = _maturityDate!.toIso8601String();
      case 'p2p':
        meta['platform'] = _platform.text.trim();
    }

    return HoldingModel(
      id: id,
      name: _name.text.trim().isEmpty
          ? _instLabels[_instruments.indexOf(_instrument)]
          : _name.text.trim(),
      assetClass: 'other_asset',
      investedAmount: double.tryParse(_annualContr.text) ?? balance,
      currentValueOverride: balance,
      maturityDate: _maturityDate,
      alertEnabled: true,
      meta: meta,
      createdAt: DateTime.now(),
    );
  }

  void _err(String m) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickDate(bool isOpen) async {
    final initial = isOpen ? (_openDate ?? DateTime(2018)) : (_maturityDate ?? DateTime(2033));
    final first = isOpen ? DateTime(2000) : DateTime.now();
    final last  = isOpen ? DateTime.now() : DateTime(2060);
    final d = await showDatePicker(context: context,
      initialDate: initial, firstDate: first, lastDate: last);
    if (d != null) setState(() { if (isOpen) _openDate = d; else _maturityDate = d; });
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      formLabel('Instrument Type'),
      SizedBox(height: 48, child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _instruments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sel = _instrument == _instruments[i];
          return GestureDetector(
            onTap: () => setState(() => _instrument = _instruments[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFFF0F4FF) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: sel ? const Color(0xFF8B92A9) : const Color(0xFFE2E8F0))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_instEmojis[i], style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(_instLabels[i], style: GoogleFonts.inter(
                  color: sel ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
              ]),
            ),
          );
        },
      )),
      const SizedBox(height: 12),

      formLabel('Label (optional)'),
      TextField(controller: _name, decoration: fieldDec('e.g. My SBI PPF Account')),
      const SizedBox(height: 12),

      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Current Balance / Corpus *'),
          TextField(controller: _balance, keyboardType: TextInputType.number,
            decoration: fieldDec('1200000', prefix: '₹ ')),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Interest / Return Rate'),
          TextField(controller: _rate, keyboardType: TextInputType.number,
            decoration: fieldDec(_instrument == 'ppf' ? '7.1' : '12.0', suffix: '%')),
        ])),
      ]),
      const SizedBox(height: 12),

      if (_instrument != 'p2p') ...[
        formLabel('Account / PRAN Number'),
        TextField(controller: _accountNo, decoration: fieldDec('Optional')),
        const SizedBox(height: 12),
      ],

      if (_instrument != 'bond' && _instrument != 'p2p') ...[
        formLabel('Annual Contribution'),
        TextField(controller: _annualContr, keyboardType: TextInputType.number,
          decoration: fieldDec('150000', prefix: '₹ ')),
        const SizedBox(height: 12),
      ],

      if (_instrument == 'bond') ...[
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            formLabel('Issuer'),
            TextField(controller: _issuer, decoration: fieldDec('REC, NHAI…')),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            formLabel('Coupon Rate'),
            TextField(controller: _coupon, keyboardType: TextInputType.number,
              decoration: fieldDec('7.5', suffix: '%')),
          ])),
        ]),
        const SizedBox(height: 12),
      ],

      if (_instrument == 'p2p') ...[
        formLabel('Platform'),
        TextField(controller: _platform, decoration: fieldDec('Faircent, LenDenClub…')),
        const SizedBox(height: 12),
      ],

      if (_instrument == 'ppf' || _instrument == 'bond') ...[
        Row(children: [
          if (_instrument == 'ppf') Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            formLabel('Account Opening Date'),
            GestureDetector(onTap: () => _pickDate(true), child: _datePill(
              _openDate != null ? '${_openDate!.day}/${_openDate!.month}/${_openDate!.year}' : 'Pick date')),
          ])),
          if (_instrument == 'ppf') const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            formLabel('Maturity Date'),
            GestureDetector(onTap: () => _pickDate(false), child: _datePill(
              _maturityDate != null ? '${_maturityDate!.day}/${_maturityDate!.month}/${_maturityDate!.year}' : 'Pick date')),
          ])),
        ]),
        const SizedBox(height: 8),
      ],

      if (_instrument == 'ppf') Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFBBF7D0))),
        child: Text('PPF matures after 15 years. Annual contribution deadline is 31st March — you\'ll get an alert!',
          style: GoogleFonts.inter(color: const Color(0xFF16A34A), fontSize: 11, height: 1.4)),
      ),
    ]);
  }

  Widget _datePill(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
    child: Row(children: [
      const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF64748B)),
      const SizedBox(width: 8),
      Text(label, style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13)),
    ]),
  );
}

// Extension for HoldingModel to accept otherInstrument in constructor cleanly
extension HoldingModelExt on HoldingModel {
  static HoldingModel create({
    required String id, required String name, required String assetClass,
    required double investedAmount, double? currentValueOverride,
    String? ticker, String? exchange, double? quantity, double? avgBuyPrice,
    int? sipDay, DateTime? maturityDate, bool alertEnabled = true,
    Map<String, dynamic> meta = const {}, String? notes,
    required DateTime createdAt,
    String? otherInstrument,
  }) {
    final m = Map<String, dynamic>.from(meta);
    if (otherInstrument != null) m['instrument'] = otherInstrument;
    return HoldingModel(
      id: id, name: name, assetClass: assetClass,
      investedAmount: investedAmount, currentValueOverride: currentValueOverride,
      ticker: ticker, exchange: exchange, quantity: quantity, avgBuyPrice: avgBuyPrice,
      sipDay: sipDay, maturityDate: maturityDate, alertEnabled: alertEnabled,
      meta: m, notes: notes, createdAt: createdAt,
    );
  }
}
