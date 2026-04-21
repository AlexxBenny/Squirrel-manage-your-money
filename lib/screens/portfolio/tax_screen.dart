import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/holding_model.dart';
import '../../providers/portfolio_provider.dart';

// ── Tax calculator (post-Budget 2024 rates) ──────────────────────────────────
class TaxService {
  /// LTCG exemption on equity (Budget 2024): ₹1,25,000
  static const double ltcgExemption = 125000;
  /// LTCG rate on equity/MF: 12.5%
  static const double ltcgRate = 0.125;
  /// STCG rate on equity/MF: 20%
  static const double stcgRate = 0.20;

  static TaxReport generate(List<HoldingModel> holdings) {
    double ltcgGain = 0, stcgGain = 0, fdInterest = 0, otherGain = 0;
    final entries = <TaxEntry>[];

    for (final h in holdings) {
      final held = DateTime.now().difference(h.createdAt).inDays;
      final gain = h.profitLoss;

      if (h.assetClass == 'stock' || h.assetClass == 'mutual_fund') {
        final isElss = h.mfIsELSS;
        if (held > 365 || isElss) {
          ltcgGain += gain;
          entries.add(TaxEntry(h.name, held, gain, 'LTCG', h.assetClass));
        } else {
          stcgGain += gain;
          entries.add(TaxEntry(h.name, held, gain, 'STCG', h.assetClass));
        }
      } else if (h.assetClass == 'crypto') {
        // Crypto: flat 30% + 1% TDS (no indexation, no exemption)
        otherGain += gain;
        entries.add(TaxEntry(h.name, held, gain, 'CRYPTO_30%', h.assetClass));
      } else if (h.assetClass == 'gold') {
        final type = h.goldType ?? 'physical';
        if (type == 'sgb') {
          // SGB maturity redemption: tax-exempt
          entries.add(TaxEntry(h.name, held, gain, 'SGB_EXEMPT', h.assetClass));
        } else if (held > 365 * 3) {
          // Physical/Digital gold LTCG: 20% with indexation (approx)
          otherGain += gain;
          entries.add(TaxEntry(h.name, held, gain, 'GOLD_LTCG_20%', h.assetClass));
        } else {
          // STCG: slab rate
          otherGain += gain;
          entries.add(TaxEntry(h.name, held, gain, 'GOLD_STCG', h.assetClass));
        }
      } else if (h.assetClass == 'fd') {
        // FD interest taxed at slab rate
        final interest = (h.fdMaturityAmount ?? h.currentValue) - (h.fdPrincipal ?? h.investedAmount);
        fdInterest += interest.clamp(0, double.infinity);
        entries.add(TaxEntry(h.name, held, interest, 'FD_INTEREST_SLAB', h.assetClass));
      }
    }

    // LTCG tax after ₹1.25L exemption
    final taxableLtcg = (ltcgGain - ltcgExemption).clamp(0.0, double.infinity);
    final ltcgTax = taxableLtcg * ltcgRate;
    final stcgTax = stcgGain.clamp(0.0, double.infinity) * stcgRate;
    final cryptoTax = otherGain.clamp(0.0, double.infinity) * 0.30;

    return TaxReport(
      entries: entries,
      ltcgGain: ltcgGain, ltcgTax: ltcgTax,
      stcgGain: stcgGain, stcgTax: stcgTax,
      fdInterest: fdInterest,
      otherGain: otherGain, cryptoTax: cryptoTax,
      totalTaxEstimate: ltcgTax + stcgTax + cryptoTax,
      generatedAt: DateTime.now(),
    );
  }

  static String exportText(TaxReport r) {
    final sb = StringBuffer();
    sb.writeln('═══════════════════════════════════');
    sb.writeln('   TAX P&L SUMMARY (FY ${_fy()})');
    sb.writeln('   Generated: ${r.generatedAt.day}/${r.generatedAt.month}/${r.generatedAt.year}');
    sb.writeln('   (Post-Budget 2024 Rates)');
    sb.writeln('═══════════════════════════════════\n');

    sb.writeln('📊 EQUITY & MUTUAL FUNDS');
    sb.writeln('─────────────────────────');
    sb.writeln('LTCG Gain (held >1yr): ₹${r.ltcgGain.toStringAsFixed(0)}');
    sb.writeln('  Exempt (₹1.25L):     -₹${TaxService.ltcgExemption.toStringAsFixed(0)}');
    sb.writeln('  Taxable @ 12.5%:     ₹${r.ltcgTax.toStringAsFixed(0)}');
    sb.writeln('STCG Gain (held ≤1yr): ₹${r.stcgGain.toStringAsFixed(0)}');
    sb.writeln('  Tax @ 20%:           ₹${r.stcgTax.toStringAsFixed(0)}');
    sb.writeln('');
    sb.writeln('🪙 CRYPTO');
    sb.writeln('─────────────────────────');
    sb.writeln('Gain/Loss:             ₹${r.otherGain.toStringAsFixed(0)}');
    sb.writeln('  Tax @ 30%:           ₹${r.cryptoTax.toStringAsFixed(0)}');
    sb.writeln('');
    sb.writeln('🏛️  FIXED DEPOSITS');
    sb.writeln('─────────────────────────');
    sb.writeln('Interest Income:       ₹${r.fdInterest.toStringAsFixed(0)}');
    sb.writeln('  (Add to income, taxed at slab rate)');
    sb.writeln('');
    sb.writeln('═══════════════════════════════════');
    sb.writeln('ESTIMATED TAX LIABILITY');
    sb.writeln('═══════════════════════════════════');
    sb.writeln('LTCG Tax:    ₹${r.ltcgTax.toStringAsFixed(0)}');
    sb.writeln('STCG Tax:    ₹${r.stcgTax.toStringAsFixed(0)}');
    sb.writeln('Crypto Tax:  ₹${r.cryptoTax.toStringAsFixed(0)}');
    sb.writeln('─────────────────────────');
    sb.writeln('TOTAL:       ₹${r.totalTaxEstimate.toStringAsFixed(0)}');
    sb.writeln('');
    sb.writeln('⚠️  This is an estimate. Consult a');
    sb.writeln('   CA for accurate tax filing.');
    sb.writeln('═══════════════════════════════════');
    sb.writeln('');
    sb.writeln('HOLDING-WISE BREAKDOWN');
    sb.writeln('─────────────────────────');
    for (final e in r.entries) {
      sb.writeln('• ${e.name}');
      sb.writeln('  Held: ${e.daysHeld}d  |  ${e.type}');
      sb.writeln('  Gain/Loss: ₹${e.gain.toStringAsFixed(0)}');
    }
    return sb.toString();
  }

  static String _fy() {
    final now = DateTime.now();
    if (now.month >= 4) return '${now.year}-${(now.year + 1).toString().substring(2)}';
    return '${now.year - 1}-${now.year.toString().substring(2)}';
  }
}

class TaxReport {
  final List<TaxEntry> entries;
  final double ltcgGain, ltcgTax, stcgGain, stcgTax;
  final double fdInterest, otherGain, cryptoTax, totalTaxEstimate;
  final DateTime generatedAt;
  const TaxReport({required this.entries, required this.ltcgGain,
    required this.ltcgTax, required this.stcgGain, required this.stcgTax,
    required this.fdInterest, required this.otherGain, required this.cryptoTax,
    required this.totalTaxEstimate, required this.generatedAt});
}

class TaxEntry {
  final String name; final int daysHeld; final double gain; final String type; final String assetClass;
  const TaxEntry(this.name, this.daysHeld, this.gain, this.type, this.assetClass);
}

// ── Tax P&L Screen ──────────────────────────────────────────────────────────
class TaxScreen extends StatelessWidget {
  const TaxScreen({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<PortfolioProvider>(),
      child: const TaxScreen()),
  );

  @override
  Widget build(BuildContext context) {
    final holdings = context.read<PortfolioProvider>().holdings;
    final report = TaxService.generate(holdings);
    final text = TaxService.exportText(report);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(children: [
        const SizedBox(height: 12),
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
          const Text('📄', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text('Tax P&L Summary', style: GoogleFonts.inter(color: AppColors.text1, fontSize: 18, fontWeight: FontWeight.w800)),
          const Spacer(),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard!')));
            },
            icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
            tooltip: 'Copy to clipboard',
          ),
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppColors.text3))),
        ])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child:
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.warning.withValues(alpha: 0.3))),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 14),
              const SizedBox(width: 6),
              Expanded(child: Text('Post-Budget 2024 rates · FY ${TaxService._fy()} · Consult a CA',
                style: GoogleFonts.inter(color: AppColors.warning, fontSize: 11))),
            ]))),
        const SizedBox(height: 8),
        // Summary cards
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
          _TaxChip('LTCG Tax', '₹${report.ltcgTax.toStringAsFixed(0)}', '12.5%', const Color(0xFF6C63FF)),
          const SizedBox(width: 8),
          _TaxChip('STCG Tax', '₹${report.stcgTax.toStringAsFixed(0)}', '20%', AppColors.expense),
          const SizedBox(width: 8),
          _TaxChip('Crypto Tax', '₹${report.cryptoTax.toStringAsFixed(0)}', '30%', const Color(0xFFFFB800)),
        ])),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF8B5CF6)]),
            borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total Estimated Tax', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
              Text('₹${report.totalTaxEstimate.toStringAsFixed(0)}',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('FD Interest', style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
              Text('₹${report.fdInterest.toStringAsFixed(0)} (slab)',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        // Holding breakdown
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text('HOLDING-WISE BREAKDOWN', style: GoogleFonts.inter(
              color: AppColors.text3, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            ...report.entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border)),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.name, style: GoogleFonts.inter(color: AppColors.text1, fontSize: 12, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('Held ${e.daysHeld}d', style: GoogleFonts.inter(color: AppColors.text3, fontSize: 11)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _typeColor(e.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                    child: Text(e.type, style: GoogleFonts.inter(
                      color: _typeColor(e.type), fontSize: 10, fontWeight: FontWeight.w700))),
                  const SizedBox(height: 4),
                  Text('${e.gain >= 0 ? '+' : ''}₹${e.gain.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      color: e.gain >= 0 ? AppColors.income : AppColors.expense,
                      fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ]),
            )),
          ],
        )),
      ]),
    );
  }

  Color _typeColor(String t) {
    if (t.contains('LTCG')) return const Color(0xFF6C63FF);
    if (t.contains('STCG')) return AppColors.expense;
    if (t.contains('CRYPTO')) return const Color(0xFFFFB800);
    if (t.contains('EXEMPT')) return AppColors.income;
    return AppColors.text3;
  }
}

class _TaxChip extends StatelessWidget {
  final String label, value, rate;
  final Color color;
  const _TaxChip(this.label, this.value, this.rate, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(color: AppColors.text3, fontSize: 9)),
      Text(value, style: GoogleFonts.inter(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
      Text('@ $rate', style: GoogleFonts.inter(color: AppColors.text3, fontSize: 9)),
    ]),
  ));
}
