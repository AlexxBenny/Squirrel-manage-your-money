import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/holding_model.dart';
import '../add_holding_sheet.dart';

class GoldForm extends StatefulWidget {
  const GoldForm({super.key});
  @override
  GoldFormState createState() => GoldFormState();
}

class GoldFormState extends State<GoldForm> {
  String _goldType = 'physical'; // physical|sgb|digital|etf
  final _name     = TextEditingController();
  final _grams    = TextEditingController();
  final _avgPrice = TextEditingController(); // per gram or per unit
  final _curPrice = TextEditingController();
  final _provider = TextEditingController();
  final _ticker   = TextEditingController();
  String _purity  = '22K';
  DateTime? _sgbMaturity;

  static const _types = ['physical', 'sgb', 'digital', 'etf'];
  static const _typeLabels = ['Physical', 'SGB', 'Digital', 'Gold ETF'];

  @override
  void dispose() {
    for (final c in [_name, _grams, _avgPrice, _curPrice, _provider, _ticker]) c.dispose();
    super.dispose();
  }

  HoldingModel? buildHolding(String id) {
    final qty   = double.tryParse(_grams.text);
    final price = double.tryParse(_avgPrice.text);
    if (qty == null || qty <= 0 || price == null || price <= 0) { _err('Enter quantity and avg price'); return null; }
    final curP  = double.tryParse(_curPrice.text);
    final curVal = curP != null ? qty * curP : null;
    return HoldingModel(
      id: id,
      name: _name.text.trim().isEmpty
          ? _goldType == 'etf' ? (_ticker.text.trim().isEmpty ? 'Gold ETF' : _ticker.text.trim())
          : 'Gold (${_goldType[0].toUpperCase()}${_goldType.substring(1)})'
          : _name.text.trim(),
      assetClass: 'gold',
      investedAmount: qty * price,
      currentValueOverride: curVal,
      ticker: _goldType == 'etf' && _ticker.text.trim().isNotEmpty ? _ticker.text.trim().toUpperCase() : null,
      exchange: _goldType == 'etf' ? 'NSE' : null,
      quantity: qty, avgBuyPrice: price,
      maturityDate: _sgbMaturity,
      meta: {
        'gold_type': _goldType,
        'purity': _purity,
        'quantity_grams': qty,
        'current_price_per_gram': curP,
        'provider': _provider.text.trim(),
        'sgb_interest_rate': _goldType == 'sgb' ? 2.5 : null,
        if (_sgbMaturity != null) 'sgb_maturity': _sgbMaturity!.toIso8601String(),
      },
      createdAt: DateTime.now(),
    );
  }

  void _err(String m) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickSgbMaturity() async {
    final d = await showDatePicker(context: context,
      initialDate: DateTime.now().add(const Duration(days: 365 * 8)),
      firstDate: DateTime.now(), lastDate: DateTime(2040));
    if (d != null) setState(() => _sgbMaturity = d);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      formLabel('Gold Type'),
      SizedBox(height: 44, child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _types.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sel = _goldType == _types[i];
          return GestureDetector(
            onTap: () => setState(() => _goldType = _types[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFFFFF3E0) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: sel ? const Color(0xFFE67E22) : const Color(0xFFE2E8F0)),
              ),
              child: Text(_typeLabels[i], style: GoogleFonts.inter(
                color: sel ? const Color(0xFFE67E22) : const Color(0xFF64748B),
                fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          );
        },
      )),
      const SizedBox(height: 12),

      if (_goldType == 'physical') ...[
        formLabel('Purity'),
        DropdownButtonFormField<String>(
          value: _purity, decoration: fieldDec('Purity'),
          dropdownColor: Colors.white,
          items: ['24K', '22K', '18K'].map((p) => DropdownMenuItem(
            value: p, child: Text(p, style: GoogleFonts.inter(fontSize: 13)))).toList(),
          onChanged: (v) => setState(() => _purity = v!),
        ),
        const SizedBox(height: 12),
      ],

      if (_goldType == 'etf') ...[
        formLabel('ETF Symbol (e.g. GOLDBEES)'),
        TextField(controller: _ticker, decoration: fieldDec('GOLDBEES, GOLD, NIPGOLD…'),
          textCapitalization: TextCapitalization.characters),
        const SizedBox(height: 12),
      ],

      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel(_goldType == 'etf' ? 'Units *' : 'Grams / Units *'),
          TextField(controller: _grams, keyboardType: TextInputType.number,
            decoration: fieldDec('50.0')),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Avg Buy Price *'),
          TextField(controller: _avgPrice, keyboardType: TextInputType.number,
            decoration: fieldDec('5800', prefix: '₹ ', suffix: _goldType == 'etf' ? '/unit' : '/g')),
        ])),
      ]),
      const SizedBox(height: 12),

      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Current Price (optional)'),
          TextField(controller: _curPrice, keyboardType: TextInputType.number,
            decoration: fieldDec('7200', prefix: '₹ ', suffix: _goldType == 'etf' ? '/unit' : '/g')),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel(_goldType == 'sgb' ? 'Issuer / Series' : 'Provider'),
          TextField(controller: _provider, decoration: fieldDec(
            _goldType == 'sgb' ? 'RBI / Tranche' :
            _goldType == 'digital' ? 'MMTC, SafeGold…' : 'HDFC, SBI…')),
        ])),
      ]),

      if (_goldType == 'sgb') ...[
        const SizedBox(height: 12),
        formLabel('Maturity Date (8 years from issue)'),
        GestureDetector(
          onTap: _pickSgbMaturity,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(children: [
              const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(_sgbMaturity != null
                ? '${_sgbMaturity!.day}/${_sgbMaturity!.month}/${_sgbMaturity!.year}'
                : 'Pick maturity date',
                style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFBBF7D0))),
          child: Text('SGB earns 2.5% p.a. interest on issue price, paid semi-annually',
            style: GoogleFonts.inter(color: const Color(0xFF16A34A), fontSize: 11)),
        ),
      ],
    ]);
  }
}
