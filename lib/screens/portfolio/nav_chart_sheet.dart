import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_colors.dart';
import '../../models/holding_model.dart';

class NavChartSheet extends StatefulWidget {
  final HoldingModel holding;
  const NavChartSheet({super.key, required this.holding});

  static Future<void> show(BuildContext context, HoldingModel h) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NavChartSheet(holding: h),
    );
  }

  @override
  State<NavChartSheet> createState() => _NavChartSheetState();
}

class _NavChartSheetState extends State<NavChartSheet> {
  List<_NavPoint> _data = [];
  bool _loading = true;
  String _error = '';
  String _range = '1Y';

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    final code = widget.holding.mfSchemeCode;
    if (code == null || code.isEmpty) {
      if (!mounted) return;
      setState(() { _error = 'No scheme code — cannot fetch NAV history.\nAdd the scheme code when editing this fund.'; _loading = false; });
      return;
    }
    if (!mounted) return;
    setState(() { _loading = true; _error = ''; });
    try {
      final url = Uri.parse('https://api.mfapi.in/mf/$code');
      final res = await http.get(url).timeout(const Duration(seconds: 15));
      if (!mounted) return; // guard after every await
      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        final rawData = body['data'] as List?;
        if (rawData == null || rawData.isEmpty) {
          setState(() { _error = 'No NAV data found for this fund.'; _loading = false; });
          return;
        }
        // mfapi returns newest first — reverse to chronological
        final points = <_NavPoint>[];
        for (final item in rawData.reversed) {
          final nav = double.tryParse(item['nav'] as String? ?? '');
          final dateStr = item['date'] as String?;
          if (nav == null || dateStr == null) continue;
          final parts = dateStr.split('-');
          if (parts.length != 3) continue;
          final d = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          points.add(_NavPoint(date: d, nav: nav));
        }
        setState(() { _data = points; _loading = false; });
      } else {
        setState(() { _error = 'Failed to load data (${res.statusCode})'; _loading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'No connection. Try again later.'; _loading = false; });
    }
  }

  List<_NavPoint> get _filtered {
    if (_data.isEmpty) return [];
    final now = _data.last.date;
    final cutoff = switch (_range) {
      '1M'  => now.subtract(const Duration(days: 30)),
      '3M'  => now.subtract(const Duration(days: 90)),
      '6M'  => now.subtract(const Duration(days: 180)),
      '1Y'  => now.subtract(const Duration(days: 365)),
      '3Y'  => now.subtract(const Duration(days: 365 * 3)),
      _     => _data.first.date,
    };
    return _data.where((p) => !p.date.isBefore(cutoff)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final minNav = filtered.isEmpty ? 0.0 : filtered.map((p) => p.nav).reduce((a, b) => a < b ? a : b);
    final maxNav = filtered.isEmpty ? 0.0 : filtered.map((p) => p.nav).reduce((a, b) => a > b ? a : b);
    final startNav = filtered.isEmpty ? 0.0 : filtered.first.nav;
    final endNav   = filtered.isEmpty ? 0.0 : filtered.last.nav;
    final change   = startNav > 0 ? (endNav - startNav) / startNav * 100 : 0.0;
    final isUp     = change >= 0;
    final chartColor = isUp ? AppColors.income : AppColors.expense;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),

        // Header
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: const Color(0xFF00D9A3).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: const Text('📊', style: TextStyle(fontSize: 20))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.holding.name,
              style: GoogleFonts.inter(color: AppColors.text1, fontSize: 14, fontWeight: FontWeight.w700),
              maxLines: 2, overflow: TextOverflow.ellipsis),
            Text('NAV History', style: GoogleFonts.inter(color: AppColors.text3, fontSize: 12)),
          ])),
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppColors.text3))),
        ])),
        const SizedBox(height: 16),

        if (_loading)
          const Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text('Loading NAV history…'),
          ])))
        else if (_error.isNotEmpty)
          Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('📡', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(_error, style: GoogleFonts.inter(color: AppColors.text2, fontSize: 14),
                textAlign: TextAlign.center),
            ]))))
        else ...[
          // Stats row
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
            _StatChip('Current NAV', '₹${endNav.toStringAsFixed(2)}', AppColors.text1),
            const SizedBox(width: 8),
            _StatChip('$_range Change', '${isUp ? '+' : ''}${change.toStringAsFixed(2)}%', chartColor),
            const SizedBox(width: 8),
            _StatChip('Low', '₹${minNav.toStringAsFixed(2)}', AppColors.text2),
            const SizedBox(width: 8),
            _StatChip('High', '₹${maxNav.toStringAsFixed(2)}', AppColors.text2),
          ])),
          const SizedBox(height: 16),

          // Range selector
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ['1M', '3M', '6M', '1Y', '3Y', 'All'].map((r) {
              final sel = _range == r;
              return GestureDetector(
                onTap: () => setState(() { _range = r; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? chartColor : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? chartColor : AppColors.border)),
                  child: Text(r, style: GoogleFonts.inter(
                    color: sel ? Colors.white : AppColors.text2,
                    fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              );
            }).toList(),
          )),
          const SizedBox(height: 20),

          // Chart
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 16, 16),
            child: filtered.length < 2
                ? Center(child: Text('Not enough data for this range',
                    style: GoogleFonts.inter(color: AppColors.text3)))
                : LineChart(LineChartData(
                    minY: minNav * 0.97,
                    maxY: maxNav * 1.03,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: (maxNav - minNav) / 4,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: AppColors.border.withValues(alpha: 0.5), strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true, reservedSize: 52,
                        getTitlesWidget: (v, _) => Text('₹${v.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(color: AppColors.text3, fontSize: 9)),
                      )),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true, reservedSize: 24,
                        interval: (filtered.length / 4).roundToDouble().clamp(1, 9999),
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= filtered.length) return const SizedBox.shrink();
                          final d = filtered[i].date;
                          return Text('${d.day}/${d.month}',
                            style: GoogleFonts.inter(color: AppColors.text3, fontSize: 9));
                        },
                      )),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                     ),
                    lineTouchData: LineTouchData(
                      touchCallback: (_, r) => setState(() {}),
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) => spots.map((s) {
                          final i = s.spotIndex;
                          if (i < 0 || i >= filtered.length) return null;
                          final d = filtered[i].date;
                          return LineTooltipItem(
                            '₹${s.y.toStringAsFixed(2)}\n${d.day}/${d.month}/${d.year}',
                            GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          );
                        }).toList(),
                      ),
                    ),
                    lineBarsData: [LineChartBarData(
                      spots: filtered.asMap().entries.map((e) =>
                        FlSpot(e.key.toDouble(), e.value.nav)).toList(),
                      isCurved: true, curveSmoothness: 0.3,
                      color: chartColor, barWidth: 2.5,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [chartColor.withValues(alpha: 0.25), chartColor.withValues(alpha: 0)]),
                      ),
                    )],
                  )),
          )),

          // Avg buy price line indicator
          if (widget.holding.avgBuyPrice != null)
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Container(width: 3, height: 24, color: AppColors.warning,
                  margin: const EdgeInsets.only(right: 10)),
                Text('Your Avg Buy NAV: ₹${widget.holding.avgBuyPrice!.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(color: AppColors.text2, fontSize: 12)),
                const Spacer(),
                Text('Current: ₹${endNav.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    color: endNav >= widget.holding.avgBuyPrice! ? AppColors.income : AppColors.expense,
                    fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            )),
        ],
      ]),
    );
  }
}

class _NavPoint { final DateTime date; final double nav; const _NavPoint({required this.date, required this.nav}); }

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(color: AppColors.text3, fontSize: 9)),
      const SizedBox(height: 2),
      Text(value, style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w800),
        overflow: TextOverflow.ellipsis),
    ]),
  ));
}
