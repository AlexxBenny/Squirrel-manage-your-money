import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/categories.dart';
import '../../models/holding_model.dart';
import '../../providers/portfolio_provider.dart';
import 'holding_forms/mf_form.dart';
import 'holding_forms/stock_form.dart';
import 'holding_forms/crypto_form.dart';
import 'holding_forms/gold_form.dart';
import 'holding_forms/fd_form.dart';
import 'holding_forms/real_estate_form.dart';
import 'holding_forms/other_form.dart';

class AddHoldingSheet extends StatefulWidget {
  final HoldingModel? existing;
  const AddHoldingSheet({super.key, this.existing});

  static Future<void> show(BuildContext context, {HoldingModel? existing}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddHoldingSheet(existing: existing),
    );

  @override
  State<AddHoldingSheet> createState() => _AddHoldingSheetState();
}

class _AddHoldingSheetState extends State<AddHoldingSheet> {
  late String _assetClass;
  bool _isSaving = false;

  // Form keys — one per asset type
  final _mfKey   = GlobalKey<MfFormState>();
  final _stKey   = GlobalKey<StockFormState>();
  final _crKey   = GlobalKey<CryptoFormState>();
  final _goKey   = GlobalKey<GoldFormState>();
  final _fdKey   = GlobalKey<FdFormState>();
  final _reKey   = GlobalKey<RealEstateFormState>();
  final _otKey   = GlobalKey<OtherFormState>();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _assetClass = widget.existing?.assetClass ?? 'mutual_fund';
    if (_isEditing) {
      // Pre-fill after first frame so form keys are mounted
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final h = widget.existing!;
        if (h.assetClass == 'mutual_fund') _mfKey.currentState?.loadFrom(h);
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final id = _isEditing ? widget.existing!.id : const Uuid().v4();
      final holding = switch (_assetClass) {
        'mutual_fund'  => _mfKey.currentState?.buildHolding(id),
        'stock'        => _stKey.currentState?.buildHolding(id),
        'crypto'       => _crKey.currentState?.buildHolding(id),
        'gold'         => _goKey.currentState?.buildHolding(id),
        'fd'           => _fdKey.currentState?.buildHolding(id),
        'real_estate'  => _reKey.currentState?.buildHolding(id),
        'other_asset'  => _otKey.currentState?.buildHolding(id),
        _              => null,
      };
      if (holding == null) return;
      if (_isEditing) {
        await context.read<PortfolioProvider>().updateHolding(holding);
      } else {
        await context.read<PortfolioProvider>().addHolding(holding);
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        // Handle
        const SizedBox(height: 12),
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Text(_isEditing ? 'Edit Investment' : 'Add Investment',
              style: GoogleFonts.inter(
                color: AppColors.text1, fontSize: 20, fontWeight: FontWeight.w800)),
            const Spacer(),
            TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.text3))),
          ]),
        ),
        const SizedBox(height: 16),
        // Asset class selector
        SizedBox(height: 100, child: _AssetClassPicker(
          selected: _assetClass,
          onChanged: _isEditing ? null : (v) => setState(() => _assetClass = v),
        )),
        const Divider(height: 1),
        // Form body
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: switch (_assetClass) {
            'mutual_fund'  => MfForm(key: _mfKey),
            'stock'        => StockForm(key: _stKey),
            'crypto'       => CryptoForm(key: _crKey),
            'gold'         => GoldForm(key: _goKey),
            'fd'           => FdForm(key: _fdKey),
            'real_estate'  => RealEstateForm(key: _reKey),
            _              => OtherForm(key: _otKey),
          },
        )),
        // Save button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(AssetClasses.colorFor(_assetClass)),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_isEditing ? 'Update ${AssetClasses.nameFor(_assetClass)}' : 'Save ${AssetClasses.nameFor(_assetClass)}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
          )),
        ),
      ]),
    );
  }
}

class _AssetClassPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String>? onChanged;  // null = locked (edit mode)
  const _AssetClassPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: AssetClasses.all.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, i) {
        final ac = AssetClasses.all[i];
        final id = ac['id'] as String;
        final color = Color(ac['color'] as int);
        final sel = selected == id;
        return GestureDetector(
          onTap: onChanged != null ? () => onChanged!(id) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 82,
            decoration: BoxDecoration(
              color: sel ? color.withValues(alpha: 0.12) : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: sel ? color : (onChanged == null ? AppColors.border.withValues(alpha: 0.4) : AppColors.border),
                width: sel ? 2 : 1),
            ),
            child: Opacity(
              opacity: onChanged == null && !sel ? 0.35 : 1.0,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(ac['emoji'] as String, style: const TextStyle(fontSize: 26)),
                const SizedBox(height: 4),
                Text(ac['name'] as String,
                  style: GoogleFonts.inter(
                    color: sel ? color : AppColors.text2,
                    fontSize: 10, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center, maxLines: 2),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ── Shared form field helpers used across all sub-forms ────────────────────

Widget formLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(text, style: GoogleFonts.inter(
    color: AppColors.text2, fontSize: 12, fontWeight: FontWeight.w600)),
);

InputDecoration fieldDec(String hint, {String? prefix, String? suffix, IconData? icon}) =>
  InputDecoration(
    hintText: hint,
    prefixText: prefix,
    suffixText: suffix,
    prefixIcon: icon != null ? Icon(icon, size: 18, color: AppColors.text3) : null,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    filled: true, fillColor: AppColors.surface,
    hintStyle: GoogleFonts.inter(color: AppColors.text3, fontSize: 13),
  );

Widget formSection(String title) => Padding(
  padding: const EdgeInsets.only(top: 20, bottom: 10),
  child: Text(title.toUpperCase(), style: GoogleFonts.inter(
    color: AppColors.text3, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
);

TextEditingController ctrl([String v = '']) => TextEditingController(text: v);
