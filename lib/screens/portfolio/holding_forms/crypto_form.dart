import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/holding_model.dart';
import '../add_holding_sheet.dart';

class CryptoForm extends StatefulWidget {
  const CryptoForm({super.key});
  @override
  CryptoFormState createState() => CryptoFormState();
}

class CryptoFormState extends State<CryptoForm> {
  final _name     = TextEditingController();
  final _coinId   = TextEditingController();
  final _ticker   = TextEditingController();
  final _qty      = TextEditingController();
  final _avgPrice = TextEditingController();
  final _exchange = TextEditingController();
  final _wallet   = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _coinId, _ticker, _qty, _avgPrice, _exchange, _wallet]) c.dispose();
    super.dispose();
  }

  HoldingModel? buildHolding(String id) {
    final qty   = double.tryParse(_qty.text);
    final price = double.tryParse(_avgPrice.text);
    if (_name.text.trim().isEmpty) { _err('Enter coin name'); return null; }
    if (qty == null || qty <= 0 || price == null || price <= 0) { _err('Enter valid quantity and price'); return null; }
    return HoldingModel(
      id: id, name: _name.text.trim(), assetClass: 'crypto',
      investedAmount: qty * price,
      ticker: _ticker.text.trim().toUpperCase().isEmpty ? null : _ticker.text.trim().toUpperCase(),
      quantity: qty, avgBuyPrice: price,
      meta: {
        'coin_id': _coinId.text.trim().toLowerCase(), // CoinGecko ID
        'exchange_name': _exchange.text.trim(),
        'wallet': _wallet.text.trim(),
      },
      createdAt: DateTime.now(),
    );
  }

  void _err(String m) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      formLabel('Coin Name *'),
      TextField(controller: _name, decoration: fieldDec('e.g. Bitcoin')),
      const SizedBox(height: 12),

      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('CoinGecko ID'),
          TextField(controller: _coinId, decoration: fieldDec('bitcoin, ethereum…')),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Ticker Symbol'),
          TextField(controller: _ticker, decoration: fieldDec('BTC, ETH…'),
            textCapitalization: TextCapitalization.characters),
        ])),
      ]),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFED7AA))),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFEA580C)),
          const SizedBox(width: 8),
          Expanded(child: Text('CoinGecko ID enables live price fetching (e.g. "bitcoin" not "BTC")',
            style: GoogleFonts.inter(color: const Color(0xFFEA580C), fontSize: 11))),
        ]),
      ),
      const SizedBox(height: 12),

      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Quantity *'),
          TextField(controller: _qty, keyboardType: TextInputType.number,
            decoration: fieldDec('0.05')),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Avg Buy Price (₹) *'),
          TextField(controller: _avgPrice, keyboardType: TextInputType.number,
            decoration: fieldDec('2800000', prefix: '₹ ')),
        ])),
      ]),
      const SizedBox(height: 12),

      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Exchange'),
          TextField(controller: _exchange, decoration: fieldDec('WazirX, CoinDCX…')),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          formLabel('Wallet (optional)'),
          TextField(controller: _wallet, decoration: fieldDec('Self-custody, Ledger…')),
        ])),
      ]),
    ]);
  }
}
