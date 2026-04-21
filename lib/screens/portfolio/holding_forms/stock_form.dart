import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/holding_model.dart';
import '../add_holding_sheet.dart';

class StockForm extends StatefulWidget {
  const StockForm({super.key});
  @override
  StockFormState createState() => StockFormState();
}

class StockFormState extends State<StockForm> {
  final _name     = TextEditingController();
  final _ticker   = TextEditingController();
  final _qty      = TextEditingController();
  final _avgPrice = TextEditingController();
  final _sector   = TextEditingController();
  final _isin     = TextEditingController();
  final _broker   = TextEditingController();
  String _exchange = 'NSE';
  DateTime _buyDate = DateTime.now();

  @override
  void dispose() {
    for (final c in [_name, _ticker, _qty, _avgPrice, _sector, _isin, _broker]) c.dispose();
    super.dispose();
  }

  HoldingModel? buildHolding(String id) {
    final qty   = double.tryParse(_qty.text);
    final price = double.tryParse(_avgPrice.text);
    if (_name.text.trim().isEmpty || _ticker.text.trim().isEmpty) { _err('Enter name and ticker'); return null; }
    if (qty == null || qty <= 0 || price == null || price <= 0) { _err('Enter valid quantity and price'); return null; }
    return HoldingModel(
      id: id, name: _name.text.trim(), assetClass: 'stock',
      investedAmount: qty * price,
      ticker: _ticker.text.trim().toUpperCase(),
      exchange: _exchange,
      quantity: qty, avgBuyPrice: price,
      meta: {
        'sector': _sector.text.trim(),
        'isin': _isin.text.trim(),
        'brokerage': _broker.text.trim(),
        'buy_date': _buyDate.toIso8601String(),
      },
      createdAt: DateTime.now(),
    );
  }

  void _err(String m) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _buyDate,
      firstDate: DateTime(2000), lastDate: DateTime.now());
    if (d != null) setState(() => _buyDate = d);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      formLabel('Company Name *'),
      TextField(controller: _name, decoration: fieldDec('e.g. Reliance Industries')),
      const SizedBox(height: 12),

      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Ticker Symbol *'),
          TextField(controller: _ticker, decoration: fieldDec('RELIANCE'),
            textCapitalization: TextCapitalization.characters),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Exchange'),
          DropdownButtonFormField<String>(
            value: _exchange, decoration: fieldDec('Exchange'),
            dropdownColor: Colors.white,
            items: const [
              DropdownMenuItem(value: 'NSE', child: Text('NSE')),
              DropdownMenuItem(value: 'BSE', child: Text('BSE')),
            ],
            onChanged: (v) => setState(() => _exchange = v!),
          ),
        ])),
      ]),
      const SizedBox(height: 12),

      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Quantity *'),
          TextField(controller: _qty, keyboardType: TextInputType.number,
            decoration: fieldDec('50')),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Avg Buy Price *'),
          TextField(controller: _avgPrice, keyboardType: TextInputType.number,
            decoration: fieldDec('2500', prefix: '₹ ')),
        ])),
      ]),
      const SizedBox(height: 12),

      formLabel('Sector'),
      TextField(controller: _sector, decoration: fieldDec('Technology, BFSI, Energy…')),
      const SizedBox(height: 12),

      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('ISIN (optional)'),
          TextField(controller: _isin, decoration: fieldDec('INE009A01021')),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Broker'),
          TextField(controller: _broker, decoration: fieldDec('Zerodha, Groww…')),
        ])),
      ]),
      const SizedBox(height: 12),

      formLabel('Buy Date'),
      GestureDetector(
        onTap: _pickDate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Row(children: [
            const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text('${_buyDate.day}/${_buyDate.month}/${_buyDate.year}',
              style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13)),
          ]),
        ),
      ),
    ]);
  }
}
