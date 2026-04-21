import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/categories.dart';
import '../../providers/portfolio_provider.dart';

class AddHoldingSheet extends StatefulWidget {
  const AddHoldingSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => const AddHoldingSheet(),
    );
  }

  @override
  State<AddHoldingSheet> createState() => _AddHoldingSheetState();
}

class _AddHoldingSheetState extends State<AddHoldingSheet> {
  String _assetClass = 'stock';
  final _nameController = TextEditingController();
  final _tickerController = TextEditingController();
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();
  final _exchangeController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose(); _tickerController.dispose();
    _qtyController.dispose(); _priceController.dispose();
    _exchangeController.dispose(); super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty || _tickerController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter name and ticker')));
      return;
    }
    final qty = double.tryParse(_qtyController.text);
    final price = double.tryParse(_priceController.text);
    if (qty == null || qty <= 0 || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid quantity and price')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await context.read<PortfolioProvider>().addHolding(
        name: _nameController.text.trim(),
        ticker: _tickerController.text.trim().toUpperCase(),
        assetClass: _assetClass,
        quantity: qty, avgBuyPrice: price,
        exchange: _exchangeController.text.trim().isEmpty ? null : _exchangeController.text.trim().toUpperCase(),
      );
      if (mounted) Navigator.pop(context);
    } finally { if (mounted) setState(() => _isSaving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('Add Holding', style: GoogleFonts.inter(color: AppColors.text1, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          // Asset class chips
          Text('Asset Class', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: AssetClasses.all.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final ac = AssetClasses.all[i];
                final selected = _assetClass == ac['id'];
                final color = Color(ac['color'] as int);
                return GestureDetector(
                  onTap: () => setState(() => _assetClass = ac['id'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? color.withOpacity(0.2) : AppColors.surface2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? color : AppColors.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(ac['emoji'] as String, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(ac['name'] as String, style: GoogleFonts.inter(color: selected ? color : AppColors.text2, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          TextField(controller: _nameController, style: GoogleFonts.inter(color: AppColors.text1, fontSize: 14),
            decoration: const InputDecoration(hintText: 'e.g. Reliance Industries', labelText: 'Asset Name'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _tickerController, style: GoogleFonts.inter(color: AppColors.text1, fontSize: 14),
              decoration: const InputDecoration(hintText: 'e.g. RELIANCE', labelText: 'Ticker Symbol'),
              textCapitalization: TextCapitalization.characters,
            )),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _exchangeController, style: GoogleFonts.inter(color: AppColors.text1, fontSize: 14),
              decoration: const InputDecoration(hintText: 'NSE / BSE', labelText: 'Exchange (optional)'),
              textCapitalization: TextCapitalization.characters,
            )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _qtyController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(color: AppColors.text1, fontSize: 14),
              decoration: const InputDecoration(hintText: '10', labelText: 'Quantity'),
            )),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(color: AppColors.text1, fontSize: 14),
              decoration: const InputDecoration(hintText: '2500', labelText: 'Avg Buy Price (₹)', prefixText: '₹  '),
            )),
          ]),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Add to Portfolio'),
          )),
        ]),
      ),
    );
  }
}
