import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/categories.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/holding_model.dart';
import '../../providers/portfolio_provider.dart';
import '../../widgets/wave_widgets.dart';
import 'add_holding_sheet.dart';
import 'nav_chart_sheet.dart';
import 'tax_screen.dart';
import '../news/news_screen.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});
  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  static const _tabIds = ['all', 'stock', 'mutual_fund', 'crypto', 'gold', 'fd', 'real_estate', 'other_asset'];
  static const _tabLabels = ['All', 'Stocks', 'MF', 'Crypto', 'Gold', 'FD', 'RE', 'Other'];

  bool _fabVisible = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabIds.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PortfolioProvider>().loadHoldings();
      setState(() => _fabVisible = true);
    });
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: AnimatedScale(
        scale: _fabVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: FloatingActionButton(
          onPressed: () => AddHoldingSheet.show(context),
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
      body: Consumer<PortfolioProvider>(
        builder: (_, p, __) => RefreshIndicator(
          onRefresh: () async { await p.loadHoldings(); await p.fetchLivePrices(); },
          color: AppColors.primary,
          child: NestedScrollView(
            headerSliverBuilder: (_, __) => [
              SliverToBoxAdapter(child: _buildHeader(p)),
              if (p.alerts.isNotEmpty) SliverToBoxAdapter(child: _AlertsRow(alerts: p.alerts)),
              SliverToBoxAdapter(child: _buildAllocationSection(p)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.text3,
                  indicatorColor: AppColors.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: AppColors.border,
                  tabs: List.generate(_tabIds.length, (i) {
                    final ac = AssetClasses.findById(_tabIds[i]);
                    return Tab(text: '${ac?['emoji'] ?? '📊'} ${_tabLabels[i]}');
                  }),
                )),
              ),
            ],
            body: TabBarView(
              controller: _tabs,
              children: _tabIds.map((id) {
                final filtered = id == 'all'
                    ? p.holdings
                    : p.holdings.where((h) => h.assetClass == id).toList();
                if (filtered.isEmpty) {
                  final isAll = id == 'all';
                  return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(isAll ? '💼' : AssetClasses.emojiFor(id),
                      style: const TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      isAll ? 'No holdings yet' : 'No ${AssetClasses.nameFor(id)} yet',
                      style: GoogleFonts.inter(color: AppColors.text2, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('Tap + to add', style: GoogleFonts.inter(color: AppColors.text3, fontSize: 13)),
                  ]));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _HoldingCard(h: filtered[i], provider: p),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(PortfolioProvider p) {
    final xirr = p.portfolioXirr;
    return ClipPath(
      clipper: WaveClipper(),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 56),
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Portfolio', style: GoogleFonts.inter(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const Spacer(),
            // News button
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewsScreen())),
              child: Container(
                width: 36, height: 36, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
                child: const Icon(Icons.newspaper_rounded, color: Colors.white, size: 18),
              ),
            ),
            // Tax button
            GestureDetector(
              onTap: () => TaxScreen.show(context),
              child: Container(
                width: 36, height: 36, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
                child: const Icon(Icons.receipt_rounded, color: Colors.white, size: 18),
              ),
            ),
            // Refresh prices button
            GestureDetector(
              onTap: p.isFetchingPrices ? null : () => p.fetchLivePrices(),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
                child: p.isFetchingPrices
                    ? const Padding(padding: EdgeInsets.all(9),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
              ),
            ),
          ]),
          if (p.holdings.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Total Portfolio Value', style: GoogleFonts.inter(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 4),
            Text(CurrencyFormatter.format(p.totalCurrentValue),
              style: GoogleFonts.inter(color: Colors.white, fontSize: 28,
                fontWeight: FontWeight.w900, letterSpacing: -1)),
            const SizedBox(height: 12),
            Row(children: [
              _GlassStat('₹${_compact(p.totalInvested)}', 'Invested', Colors.white70),
              const SizedBox(width: 8),
              _GlassStat('${p.totalPnL >= 0 ? '+' : ''}₹${_compact(p.totalPnL)}',
                'P&L', p.totalPnL >= 0 ? AppColors.income : AppColors.expense),
              const SizedBox(width: 8),
              _GlassStat(
                xirr != null ? '${(xirr * 100).toStringAsFixed(1)}%' : '${p.totalPnLPct.toStringAsFixed(1)}%',
                xirr != null ? 'XIRR' : 'Returns',
                p.totalPnLPct >= 0 ? AppColors.income : AppColors.expense),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _buildAllocationSection(PortfolioProvider p) {
    if (p.holdings.length < 2) return const SizedBox.shrink();
    final byClass  = p.byAssetClass;
    final total    = p.totalCurrentValue;
    final risk     = p.riskSplit;
    final divScore = p.diversificationScore;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(children: [
        // Asset allocation donut
        CurvedContainer(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Asset Allocation', style: GoogleFonts.inter(
                color: AppColors.text1, fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: divScore >= 70 ? AppColors.income.withValues(alpha: 0.1)
                      : divScore >= 40 ? AppColors.warning.withValues(alpha: 0.1)
                      : AppColors.expense.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
                child: Text('Score: $divScore/100',
                  style: GoogleFonts.inter(
                    color: divScore >= 70 ? AppColors.income
                        : divScore >= 40 ? AppColors.warning : AppColors.expense,
                    fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 16),
            SizedBox(height: 130, child: Row(children: [
              Expanded(child: PieChart(PieChartData(
                sections: byClass.entries.toList().asMap().entries.map((e) =>
                  PieChartSectionData(
                    value: e.value.value,
                    color: Color(AssetClasses.colorFor(e.value.key)),
                    radius: 44, showTitle: false,
                  )).toList(),
                sectionsSpace: 2, centerSpaceRadius: 34,
              ))),
              const SizedBox(width: 16),
              Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center,
                children: byClass.entries.map((e) {
                  final pct = total > 0 ? e.value / total * 100 : 0;
                  return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
                    Container(width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: Color(AssetClasses.colorFor(e.key)),
                        borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      '${AssetClasses.emojiFor(e.key)} ${AssetClasses.nameFor(e.key)}',
                      style: GoogleFonts.inter(color: AppColors.text2, fontSize: 11),
                      overflow: TextOverflow.ellipsis)),
                    Text('${pct.toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(color: AppColors.text1, fontSize: 11, fontWeight: FontWeight.w700)),
                  ]));
                }).toList())),
            ])),
            const SizedBox(height: 12),
            // Risk split bar
            ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(height: 8,
              child: Row(children: [
                if (total > 0) ...[
                  Expanded(flex: (risk.marketLinked / total * 100).round(),
                    child: Container(color: AppColors.primary)),
                  Expanded(flex: (risk.fixedIncome / total * 100).round(),
                    child: Container(color: AppColors.income)),
                ],
              ]),
            )),
            const SizedBox(height: 6),
            Row(children: [
              _legendDot(AppColors.primary, 'Market-linked ${total > 0 ? '(${(risk.marketLinked / total * 100).toStringAsFixed(0)}%)' : ''}'),
              const SizedBox(width: 16),
              _legendDot(AppColors.income, 'Fixed income ${total > 0 ? '(${(risk.fixedIncome / total * 100).toStringAsFixed(0)}%)' : ''}'),
            ]),
          ]),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

String _compact(double v) {
  final abs = v.abs();
  final sign = v < 0 ? '-' : '';
  if (abs >= 1e7) return '${sign}${(abs / 1e7).toStringAsFixed(1)}Cr';
  if (abs >= 1e5) return '${sign}${(abs / 1e5).toStringAsFixed(1)}L';
  if (abs >= 1e3) return '${sign}${(abs / 1e3).toStringAsFixed(1)}K';
  return '$sign${abs.toStringAsFixed(0)}';
}

Widget _legendDot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
  Container(width: 8, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
  const SizedBox(width: 4),
  Text(label, style: GoogleFonts.inter(color: AppColors.text3, fontSize: 10)),
]);

// ── Alert banner row ─────────────────────────────────────────────────────────
class _AlertsRow extends StatelessWidget {
  final List<PortfolioAlert> alerts;
  const _AlertsRow({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(children: alerts.map((a) {
        final color = a.severity == AlertSeverity.urgent ? AppColors.expense
            : a.severity == AlertSeverity.warning ? AppColors.warning
            : AppColors.info;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.25))),
            child: Row(children: [
              Text(a.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.title, style: GoogleFonts.inter(
                  color: color, fontSize: 13, fontWeight: FontWeight.w700)),
                Text(a.subtitle, style: GoogleFonts.inter(
                  color: AppColors.text2, fontSize: 12)),
              ])),
            ]),
          ),
        );
      }).toList()),
    );
  }
}

// ── Holding card ─────────────────────────────────────────────────────────────
class _HoldingCard extends StatefulWidget {
  final HoldingModel h;
  final PortfolioProvider provider;
  const _HoldingCard({required this.h, required this.provider});
  @override
  State<_HoldingCard> createState() => _HoldingCardState();
}

class _HoldingCardState extends State<_HoldingCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.h;
    final color = Color(AssetClasses.colorFor(h.assetClass));
    final isProfit = h.isProfit;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _expanded ? color.withValues(alpha: 0.3) : AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // Main row
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(width: 46, height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Text(AssetClasses.emojiFor(h.assetClass),
                  style: const TextStyle(fontSize: 22))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(h.name,
                    style: GoogleFonts.inter(color: AppColors.text1, fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text(CurrencyFormatter.format(h.currentValue),
                    style: GoogleFonts.inter(color: AppColors.text1, fontSize: 14, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Text(_subtitle(h), style: GoogleFonts.inter(color: AppColors.text3, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isProfit ? AppColors.income : AppColors.expense).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      '${isProfit ? '+' : ''}${CurrencyFormatter.format(h.profitLoss, compact: true)} '
                      '(${h.profitLossPct.toStringAsFixed(1)}%)',
                      style: GoogleFonts.inter(
                        color: isProfit ? AppColors.income : AppColors.expense,
                        fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ])),
              const SizedBox(width: 6),
              AnimatedRotation(turns: _expanded ? 0.5 : 0, duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.text3, size: 20)),
            ]),
          ),
        ),
        // Expanded details
        if (_expanded) ...[
          Divider(color: color.withValues(alpha: 0.15), height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: _buildDetails(h, color),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(children: [
              if (h.assetClass == 'mutual_fund' && h.mfSchemeCode != null)
                TextButton.icon(
                  onPressed: () => NavChartSheet.show(context, h),
                  icon: const Icon(Icons.show_chart_rounded, size: 16, color: AppColors.primary),
                  label: Text('NAV Chart', style: GoogleFonts.inter(color: AppColors.primary, fontSize: 12)),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => widget.provider.deleteHolding(h.id),
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.expense),
                label: Text('Remove', style: GoogleFonts.inter(color: AppColors.expense, fontSize: 12)),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  String _subtitle(HoldingModel h) {
    switch (h.assetClass) {
      case 'mutual_fund':
        final parts = <String>[];
        if (h.mfFundHouse?.isNotEmpty == true) parts.add(h.mfFundHouse!);
        if (h.mfType == 'sip' && h.mfSipAmount != null) parts.add('SIP ₹${h.mfSipAmount!.toStringAsFixed(0)}/mo');
        if (h.mfPlan != null) parts.add(h.mfPlan!.toUpperCase());
        return parts.join(' · ');
      case 'stock':
        return '${h.ticker ?? ''} · ${h.exchange ?? ''} · Qty ${h.quantity?.toStringAsFixed(0) ?? ''}';
      case 'crypto':
        return '${h.ticker ?? ''} · ${(h.meta['exchange_name'] as String?)?.isNotEmpty == true ? h.meta['exchange_name'] : 'Crypto'}';
      case 'gold':
        return '${h.goldType?.toUpperCase() ?? 'GOLD'} · ${h.goldType == 'physical' ? '${h.goldGrams?.toStringAsFixed(1)}g ${h.goldPurity}' : '${h.quantity?.toStringAsFixed(3)} units'}';
      case 'fd':
        return '${h.fdBank ?? 'FD'} · ${h.fdRate?.toStringAsFixed(1)}% · ${h.fdTenureMonths}mo';
      case 'real_estate':
        return '${h.rePropType?.toUpperCase() ?? ''} · ${h.reLocation ?? ''}';
      default:
        return (h.otherInstrument ?? 'Other').toUpperCase();
    }
  }

  Widget _buildDetails(HoldingModel h, Color color) {
    final rows = <_DetailRow>[];
    rows.add(_DetailRow('Invested', CurrencyFormatter.format(h.investedAmount)));
    rows.add(_DetailRow('Current Value', CurrencyFormatter.format(h.currentValue)));
    rows.add(_DetailRow('P&L', '${h.isProfit ? '+' : ''}${CurrencyFormatter.format(h.profitLoss)}',
      color: h.isProfit ? AppColors.income : AppColors.expense));

    switch (h.assetClass) {
      case 'mutual_fund':
        if (h.mfUnits != null) rows.add(_DetailRow('Units', h.mfUnits!.toStringAsFixed(3)));
        if (h.avgBuyPrice != null) rows.add(_DetailRow('Avg NAV', '₹${h.avgBuyPrice!.toStringAsFixed(2)}'));
        if (h.mfCurrentNav != null) rows.add(_DetailRow('Current NAV', '₹${h.mfCurrentNav!.toStringAsFixed(2)}'));
        if (h.mfType == 'sip' && h.sipDay != null)
          rows.add(_DetailRow('SIP Day', 'Every ${h.sipDay}th'));
        if (h.mfIsELSS) rows.add(_DetailRow('Tax Benefit', 'ELSS (₹1.5L under 80C)'));
        if (h.mfFolio?.isNotEmpty == true) rows.add(_DetailRow('Folio', h.mfFolio!));
      case 'stock':
        if (h.quantity != null) rows.add(_DetailRow('Shares', h.quantity!.toStringAsFixed(0)));
        if (h.avgBuyPrice != null) rows.add(_DetailRow('Avg Price', '₹${h.avgBuyPrice!.toStringAsFixed(2)}'));
        if (h.currentPrice != null) rows.add(_DetailRow('CMP', '₹${h.currentPrice!.toStringAsFixed(2)}'));
        if (h.changePct != null) rows.add(_DetailRow('Day Change', '${h.changePct! >= 0 ? '+' : ''}${h.changePct!.toStringAsFixed(2)}%'));
        if ((h.meta['sector'] as String?)?.isNotEmpty == true) rows.add(_DetailRow('Sector', h.meta['sector'] as String));
      case 'gold':
        if (h.goldGrams != null) rows.add(_DetailRow('Quantity', '${h.goldGrams!.toStringAsFixed(2)} g'));
        if (h.goldCurrentPricePerGram != null) rows.add(_DetailRow('Current Price', '₹${h.goldCurrentPricePerGram!.toStringAsFixed(0)}/g'));
        if (h.sgbInterestRate != null) rows.add(_DetailRow('SGB Interest', '${h.sgbInterestRate}% p.a.'));
        if (h.maturityDate != null) rows.add(_DetailRow('Maturity', '${h.maturityDate!.day}/${h.maturityDate!.month}/${h.maturityDate!.year}'));
      case 'fd':
        if (h.fdPrincipal != null) rows.add(_DetailRow('Principal', '₹${h.fdPrincipal!.toStringAsFixed(0)}'));
        if (h.fdRate != null) rows.add(_DetailRow('Interest Rate', '${h.fdRate!.toStringAsFixed(2)}% p.a.'));
        if (h.fdMaturityAmount != null) rows.add(_DetailRow('Maturity Amount', '₹${h.fdMaturityAmount!.toStringAsFixed(0)}'));
        if (h.maturityDate != null) rows.add(_DetailRow('Matures On', '${h.maturityDate!.day}/${h.maturityDate!.month}/${h.maturityDate!.year}'));
        if (h.fdType != null) rows.add(_DetailRow('Type', h.fdType!.replaceAll('_', ' ').toUpperCase()));
      case 'real_estate':
        if (h.reTotalCost != null) rows.add(_DetailRow('Total Cost', '₹${_compact(h.reTotalCost!)}'));
        if (h.reRentalIncome != null && h.reRentalIncome! > 0)
          rows.add(_DetailRow('Monthly Rent', '₹${h.reRentalIncome!.toStringAsFixed(0)}'));
        if (h.reHasLoan && h.reEmi != null) rows.add(_DetailRow('EMI', '₹${h.reEmi!.toStringAsFixed(0)}/mo'));
        if (h.reRemainingMonths != null) rows.add(_DetailRow('Loan Balance', '${h.reRemainingMonths} months left'));
      default:
        if (h.otherBalance != null) rows.add(_DetailRow('Corpus', '₹${_compact(h.otherBalance!)}'));
        if ((h.meta['interest_rate'] as num?) != null)
          rows.add(_DetailRow('Rate', '${h.meta['interest_rate']}% p.a.'));
        if (h.maturityDate != null)
          rows.add(_DetailRow('Matures', '${h.maturityDate!.day}/${h.maturityDate!.month}/${h.maturityDate!.year}'));
    }

    return Wrap(spacing: 8, runSpacing: 8, children: rows.map((r) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.label, style: GoogleFonts.inter(color: AppColors.text3, fontSize: 10)),
          const SizedBox(height: 2),
          Text(r.value, style: GoogleFonts.inter(
            color: r.color ?? AppColors.text1, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      )).toList());
  }
}

class _DetailRow {
  final String label, value;
  final Color? color;
  const _DetailRow(this.label, this.value, {this.color});
}

// ── Glass stat chip ───────────────────────────────────────────────────────────
class _GlassStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _GlassStat(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: GoogleFonts.inter(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
      Text(label, style: GoogleFonts.inter(color: Colors.white60, fontSize: 10)),
    ]),
  ));
}

// ── Tab bar delegate ──────────────────────────────────────────────────────────
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);
  @override double get minExtent => tabBar.preferredSize.height;
  @override double get maxExtent => tabBar.preferredSize.height;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
    Container(color: AppColors.background, child: tabBar);
  @override bool shouldRebuild(_TabBarDelegate _) => false;
}
