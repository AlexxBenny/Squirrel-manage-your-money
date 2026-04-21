import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/categories.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/portfolio_provider.dart';
import '../../models/holding_model.dart';
import '../portfolio/add_holding_sheet.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});
  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PortfolioProvider>().loadHoldings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Portfolio', style: GoogleFonts.inter(color: AppColors.text1, fontSize: 22, fontWeight: FontWeight.w700)),
        actions: [
          Consumer<PortfolioProvider>(
            builder: (_, p, __) => IconButton(
              onPressed: p.isFetchingPrices ? null : () => p.fetchLivePrices(),
              icon: p.isFetchingPrices
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : const Icon(Icons.refresh, color: AppColors.text2),
              tooltip: 'Refresh prices',
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddHoldingSheet.show(context),
        icon: const Icon(Icons.add),
        label: Text('Add Holding', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
      body: Consumer<PortfolioProvider>(
        builder: (_, provider, __) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (provider.holdings.isEmpty) {
            return _emptyState();
          }
          return RefreshIndicator(
            onRefresh: () async {
              await provider.loadHoldings();
              await provider.fetchLivePrices();
            },
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              children: [
                _PortfolioHeader(provider: provider),
                const SizedBox(height: 20),
                if (provider.holdings.length > 1) ...[
                  _AssetPieChart(provider: provider),
                  const SizedBox(height: 20),
                ],
                Text('Holdings', style: GoogleFonts.inter(color: AppColors.text1, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                ...provider.holdings.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _HoldingCard(holding: h, onDelete: () => provider.deleteHolding(h.id)),
                )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('📈', style: TextStyle(fontSize: 56)),
    const SizedBox(height: 16),
    Text('No holdings yet', style: GoogleFonts.inter(color: AppColors.text1, fontSize: 18, fontWeight: FontWeight.w600)),
    const SizedBox(height: 6),
    Text('Track stocks, crypto, and more', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 13)),
  ]));
}

class _PortfolioHeader extends StatelessWidget {
  final PortfolioProvider provider;
  const _PortfolioHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isPnLPositive = provider.totalPnL >= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.2), AppColors.surface],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Total Portfolio Value', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 13)),
        const SizedBox(height: 4),
        Text(CurrencyFormatter.format(provider.totalCurrentValue), style: GoogleFonts.inter(color: AppColors.text1, fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(children: [
          _stat('Invested', CurrencyFormatter.format(provider.totalInvested), AppColors.text2),
          const SizedBox(width: 24),
          _stat(
            'P&L',
            '${CurrencyFormatter.formatWithSign(provider.totalPnL)} (${CurrencyFormatter.formatPct(provider.totalPnLPct)})',
            isPnLPositive ? AppColors.income : AppColors.expense,
          ),
        ]),
      ]),
    );
  }

  Widget _stat(String label, String value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.inter(color: AppColors.text3, fontSize: 11)),
    Text(value, style: GoogleFonts.inter(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
  ]);
}

class _AssetPieChart extends StatelessWidget {
  final PortfolioProvider provider;
  const _AssetPieChart({required this.provider});

  @override
  Widget build(BuildContext context) {
    final byClass = provider.byAssetClass;
    final total = provider.totalCurrentValue;
    final entries = byClass.entries.toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Asset Allocation', style: GoogleFonts.inter(color: AppColors.text1, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: Row(children: [
            Expanded(
              child: PieChart(PieChartData(
                sections: entries.asMap().entries.map((e) {
                  final color = AppColors.chartPalette[e.key % AppColors.chartPalette.length];
                  return PieChartSectionData(
                    value: e.value.value,
                    color: color,
                    radius: 50,
                    showTitle: false,
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              )),
            ),
            const SizedBox(width: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entries.asMap().entries.map((e) {
                final color = AppColors.chartPalette[e.key % AppColors.chartPalette.length];
                final pct = total > 0 ? e.value.value / total * 100 : 0;
                final ac = AssetClasses.all.firstWhere((a) => a['id'] == e.value.key, orElse: () => {'name': e.value.key, 'emoji': '💼'});
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 6),
                    Text('${ac['emoji']} ${ac['name']}', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 11)),
                    const SizedBox(width: 6),
                    Text('${pct.toStringAsFixed(0)}%', style: GoogleFonts.inter(color: AppColors.text1, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                );
              }).toList(),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _HoldingCard extends StatelessWidget {
  final HoldingModel holding;
  final VoidCallback onDelete;
  const _HoldingCard({required this.holding, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isPnLPositive = holding.isProfit;
    final ac = AssetClasses.all.firstWhere((a) => a['id'] == holding.assetClass, orElse: () => {'emoji': '💼', 'name': holding.assetClass});

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.center,
          child: Text(ac['emoji'] as String, style: const TextStyle(fontSize: 22)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(holding.name, style: GoogleFonts.inter(color: AppColors.text1, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text(CurrencyFormatter.format(holding.currentValue, compact: true), style: GoogleFonts.inter(color: AppColors.text1, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 3),
          Row(children: [
            Text('${holding.ticker}  ·  Qty: ${holding.quantity}', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12)),
            const Spacer(),
            Text(
              '${isPnLPositive ? '+' : ''}${CurrencyFormatter.format(holding.profitLoss)} (${CurrencyFormatter.formatPct(holding.profitLossPct)})',
              style: GoogleFonts.inter(color: isPnLPositive ? AppColors.income : AppColors.expense, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ]),
          if (holding.currentPrice != null) ...[
            const SizedBox(height: 3),
            Text('Current: ${CurrencyFormatter.format(holding.currentPrice!, showDecimal: true)}  ·  Avg: ${CurrencyFormatter.format(holding.avgBuyPrice, showDecimal: true)}', style: GoogleFonts.inter(color: AppColors.text3, fontSize: 11)),
          ],
        ])),
        PopupMenuButton<String>(
          onSelected: (v) { if (v == 'delete') onDelete(); },
          color: AppColors.surface2,
          icon: const Icon(Icons.more_vert, color: AppColors.text3, size: 18),
          itemBuilder: (_) => [
            PopupMenuItem(value: 'delete', child: Text('Delete', style: GoogleFonts.inter(color: AppColors.expense))),
          ],
        ),
      ]),
    );
  }
}
