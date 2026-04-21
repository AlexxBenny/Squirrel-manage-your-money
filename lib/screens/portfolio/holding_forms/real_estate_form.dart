import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/holding_model.dart';
import '../add_holding_sheet.dart';

class RealEstateForm extends StatefulWidget {
  const RealEstateForm({super.key});
  @override
  RealEstateFormState createState() => RealEstateFormState();
}

class RealEstateFormState extends State<RealEstateForm> {
  String _propType   = 'residential';
  final _name        = TextEditingController();
  final _location    = TextEditingController();
  final _purchasePrice = TextEditingController();
  final _regCost     = TextEditingController();
  final _renovation  = TextEditingController();
  final _currentVal  = TextEditingController();
  final _rental      = TextEditingController();
  final _loanAmt     = TextEditingController();
  final _loanRate    = TextEditingController();
  final _emi         = TextEditingController();
  final _loanMonths  = TextEditingController();
  bool _hasLoan      = false;
  DateTime _purchaseDate = DateTime.now();

  @override
  void dispose() {
    for (final c in [_name, _location, _purchasePrice, _regCost, _renovation,
      _currentVal, _rental, _loanAmt, _loanRate, _emi, _loanMonths]) c.dispose();
    super.dispose();
  }

  HoldingModel? buildHolding(String id) {
    final pp  = double.tryParse(_purchasePrice.text) ?? 0;
    final reg = double.tryParse(_regCost.text) ?? 0;
    final ren = double.tryParse(_renovation.text) ?? 0;
    final cur = double.tryParse(_currentVal.text);
    if (pp <= 0) { _err('Enter purchase price'); return null; }
    if (_name.text.trim().isEmpty) { _err('Enter property name'); return null; }
    final totalCost = pp + reg + ren;
    return HoldingModel(
      id: id, name: _name.text.trim(), assetClass: 'real_estate',
      investedAmount: totalCost,
      currentValueOverride: cur ?? totalCost,
      meta: {
        'property_type': _propType,
        'location': _location.text.trim(),
        'purchase_price': pp,
        'reg_stamp_duty': reg,
        'renovation_cost': ren,
        'total_cost': totalCost,
        'purchase_date': _purchaseDate.toIso8601String(),
        'rental_income': double.tryParse(_rental.text) ?? 0,
        'has_loan': _hasLoan,
        if (_hasLoan) ...{
          'loan_amount': double.tryParse(_loanAmt.text) ?? 0,
          'loan_rate': double.tryParse(_loanRate.text) ?? 0,
          'emi_amount': double.tryParse(_emi.text) ?? 0,
          'remaining_months': int.tryParse(_loanMonths.text) ?? 0,
        },
      },
      createdAt: DateTime.now(),
    );
  }

  void _err(String m) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _purchaseDate,
      firstDate: DateTime(2000), lastDate: DateTime.now());
    if (d != null) setState(() => _purchaseDate = d);
  }

  double get _totalCost => (double.tryParse(_purchasePrice.text) ?? 0)
      + (double.tryParse(_regCost.text) ?? 0)
      + (double.tryParse(_renovation.text) ?? 0);

  double get _appreciation {
    final cur = double.tryParse(_currentVal.text) ?? 0;
    final tc  = _totalCost;
    return tc > 0 ? (cur - tc) / tc * 100 : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      formLabel('Property Type'),
      DropdownButtonFormField<String>(
        value: _propType, decoration: fieldDec('Type'), dropdownColor: Colors.white,
        items: const [
          DropdownMenuItem(value: 'residential', child: Text('🏠 Residential')),
          DropdownMenuItem(value: 'commercial',  child: Text('🏢 Commercial')),
          DropdownMenuItem(value: 'plot',        child: Text('🌍 Plot / Land')),
          DropdownMenuItem(value: 'reit',        child: Text('📊 REIT')),
        ],
        onChanged: (v) => setState(() => _propType = v!),
      ),
      const SizedBox(height: 12),

      formLabel('Property Name *'),
      TextField(controller: _name, decoration: fieldDec('e.g. My Flat in Bangalore')),
      const SizedBox(height: 12),

      formLabel('Location'),
      TextField(controller: _location, decoration: fieldDec('City, State…')),
      const SizedBox(height: 12),

      formSection('Purchase Details'),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Purchase Price *'),
          TextField(controller: _purchasePrice, keyboardType: TextInputType.number,
            decoration: fieldDec('5000000', prefix: '₹ '), onChanged: (_) => setState(() {})),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Reg + Stamp Duty'),
          TextField(controller: _regCost, keyboardType: TextInputType.number,
            decoration: fieldDec('350000', prefix: '₹ '), onChanged: (_) => setState(() {})),
        ])),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Renovation Cost'),
          TextField(controller: _renovation, keyboardType: TextInputType.number,
            decoration: fieldDec('0', prefix: '₹ '), onChanged: (_) => setState(() {})),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Total Cost'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Text('₹${_totalCost.toStringAsFixed(0)}',
              style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ])),
      ]),
      const SizedBox(height: 12),
      formLabel('Purchase Date'),
      GestureDetector(onTap: _pickDate, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Row(children: [
          const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Text('${_purchaseDate.day}/${_purchaseDate.month}/${_purchaseDate.year}',
            style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13)),
        ]),
      )),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Current Value (estimate)'),
          TextField(controller: _currentVal, keyboardType: TextInputType.number,
            decoration: fieldDec('7500000', prefix: '₹ '), onChanged: (_) => setState(() {})),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Monthly Rental'),
          TextField(controller: _rental, keyboardType: TextInputType.number,
            decoration: fieldDec('0', prefix: '₹ ')),
        ])),
      ]),
      if ((double.tryParse(_currentVal.text) ?? 0) > 0) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _appreciation >= 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Text(_appreciation >= 0 ? '📈' : '📉', style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text('${_appreciation >= 0 ? '+' : ''}${_appreciation.toStringAsFixed(1)}% appreciation',
              style: GoogleFonts.inter(
                color: _appreciation >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
      ],

      formSection('Home Loan (Optional)'),
      Row(children: [
        Switch(value: _hasLoan, onChanged: (v) => setState(() => _hasLoan = v),
          activeColor: const Color(0xFF9B59B6)),
        Text('Has Home Loan', style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13)),
      ]),
      if (_hasLoan) ...[
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            formLabel('Loan Amount'),
            TextField(controller: _loanAmt, keyboardType: TextInputType.number,
              decoration: fieldDec('3500000', prefix: '₹ ')),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            formLabel('Interest Rate'),
            TextField(controller: _loanRate, keyboardType: TextInputType.number,
              decoration: fieldDec('8.5', suffix: '%')),
          ])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            formLabel('Monthly EMI'),
            TextField(controller: _emi, keyboardType: TextInputType.number,
              decoration: fieldDec('35000', prefix: '₹ ')),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            formLabel('Remaining Months'),
            TextField(controller: _loanMonths, keyboardType: TextInputType.number,
              decoration: fieldDec('156')),
          ])),
        ]),
      ],
    ]);
  }
}
