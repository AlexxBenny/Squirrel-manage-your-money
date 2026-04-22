import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_colors.dart';

class MfSearchResult {
  final int schemeCode;
  final String schemeName;
  final String? fundHouse;
  final String? plan;       // 'direct' | 'regular'
  final String? category;   // internal category key
  final bool isElss;
  final double? latestNav;  // from full scheme API — auto-fills Current NAV
  final bool isEnriched;    // true = came from full scheme API, not just search list

  MfSearchResult({
    required this.schemeCode,
    required this.schemeName,
    this.fundHouse,
    this.plan,
    this.category,
    this.isElss = false,
    this.latestNav,
    this.isEnriched = false,
  });

  /// Basic parse from the search-list API (only schemeCode + schemeName).
  /// Category here is a name-based hint for display only — not yet authoritative.
  factory MfSearchResult.fromMap(Map<String, dynamic> m) {
    final name  = m['schemeName'] as String? ?? '';
    final lower = name.toLowerCase();
    String? plan;
    if (lower.contains('direct'))       plan = 'direct';
    else if (lower.contains('regular')) plan = 'regular';
    String? house;
    for (final h in _knownHouses) {
      if (lower.contains(h.toLowerCase())) { house = h; break; }
    }
    final cat = _detectCategoryFromName(lower);
    return MfSearchResult(
      schemeCode: m['schemeCode'] as int,
      schemeName: name,
      fundHouse:  house,
      plan:       plan,
      category:   cat,
      isElss:     cat == 'elss',
      isEnriched: false,
    );
  }

  // ── Official mapping — uses scheme_category from mfapi.in full API ─────────
  // Input: raw string like "Equity Scheme - Large Cap Fund"
  // This is NOT guessing — it comes directly from the AMFI/mfapi database.
  static String? mapSchemeCategory(String raw, String schemeName) {
    final s    = raw.toLowerCase().trim();
    final name = schemeName.toLowerCase();
    // Equity
    if (s.contains('large & mid cap') ||
        s.contains('large and mid cap'))  return 'equity_large_mid';
    if (s.contains('large cap'))          return 'equity_large_cap';
    if (s.contains('mid cap'))            return 'equity_mid_cap';
    if (s.contains('small cap'))          return 'equity_small_cap';
    if (s.contains('multi cap'))          return 'equity_multi_cap';
    if (s.contains('flexi cap') ||
        s.contains('flexi-cap'))          return 'equity_flexi';
    if (s.contains('sectoral') ||
        s.contains('thematic'))           return 'equity_sectoral';
    if (s.contains('value fund') ||
        s.contains('contra fund') ||
        s.contains('dividend yield'))     return 'equity_value';
    if (s.contains('focused fund'))       return 'equity_focused';
    if (s.contains('elss') ||
        s.contains('tax saver'))          return 'elss';
    // Hybrid
    if (s.contains('balanced advantage')) return 'hybrid_balanced_advantage';
    if (s.contains('equity savings'))     return 'hybrid_equity_savings';
    if (s.contains('arbitrage'))          return 'hybrid_arbitrage';
    if (s.contains('multi asset'))        return 'hybrid_multi_asset';
    if (s.contains('conservative hybrid')) return 'hybrid_conservative';
    if (s.contains('hybrid'))             return 'hybrid';
    // Debt
    if (s.contains('overnight') ||
        s.contains('liquid fund'))        return 'debt_liquid';
    if (s.contains('gilt'))               return 'debt_gilt';
    if (s.contains('corporate bond'))     return 'debt_corporate_bond';
    if (s.contains('credit risk'))        return 'debt_credit_risk';
    if (s.contains('banking and psu') ||
        s.contains('banking & psu'))      return 'debt_banking_psu';
    if (s.contains('dynamic bond'))       return 'debt_dynamic';
    if (s.contains('medium duration') ||
        s.contains('medium term'))        return 'debt_medium';
    if (s.contains('long duration'))      return 'debt_long';
    if (s.contains('ultra short duration') ||
        s.contains('low duration') ||
        s.contains('money market') ||
        s.contains('short duration') ||
        s.contains('ultra short'))        return 'debt_short';
    if (s.contains('debt scheme') ||
        s.contains('debt fund'))          return 'debt_short';
    // Passive
    if (s.contains('index fund') ||
        s.contains('index funds'))        return 'index';
    if (s.contains('gold etf'))           return 'commodity_gold_etf';
    if (s.contains('silver etf'))         return 'commodity_silver_etf';
    if (s.contains('etf'))                return 'index';
    // Fund of Funds — use scheme name to narrow sub-type
    // mfapi returns "Other Scheme - FoF Domestic" or "Other Scheme - FoF Overseas"
    if (s.contains('fund of fund') || s.contains('fof domestic') ||
        s.contains('fof overseas') || s.contains('fof')) {
      if (name.contains('gold')) {
        return name.contains('etf') ? 'commodity_gold_etf' : 'commodity_gold_fof';
      }
      if (name.contains('silver')) {
        return name.contains('etf') ? 'commodity_silver_etf' : 'commodity_silver_fof';
      }
      if (s.contains('fof overseas') || name.contains('international') ||
          name.contains('global') || name.contains('overseas') ||
          name.contains('nasdaq') || name.contains('s&p') ||
          name.contains('us equity')) {
        return 'international_fof';
      }
      return 'fof';
    }
    return null;
  }

  // ── Name-based hint — used ONLY for display badge in search results ─────────
  // NOT applied to the form; the form waits for the API-enriched result.
  static String? _detectCategoryFromName(String lower) {
    if (lower.contains('gold'))   return lower.contains('etf') ? 'commodity_gold_etf' : 'commodity_gold_fof';
    if (lower.contains('silver')) return lower.contains('etf') ? 'commodity_silver_etf' : 'commodity_silver_fof';
    if (lower.contains('elss') || lower.contains('tax saver') || lower.contains('tax saving')) return 'elss';
    if (lower.contains('etf') || lower.contains('nifty') || lower.contains('sensex') || lower.contains('nasdaq')) return 'index';
    if (lower.contains('international') || lower.contains('global') || lower.contains('overseas')) return 'international_fof';
    if (lower.contains('large & mid cap') || lower.contains('large and mid cap')) return 'equity_large_mid';
    if (lower.contains('multi cap') || lower.contains('multicap')) return 'equity_multi_cap';
    if (lower.contains('flexi cap') || lower.contains('flexicap')) return 'equity_flexi';
    if (lower.contains('small cap') || lower.contains('smallcap')) return 'equity_small_cap';
    if (lower.contains('mid cap')   || lower.contains('midcap'))   return 'equity_mid_cap';
    if (lower.contains('large cap') || lower.contains('largecap') || lower.contains('bluechip') || lower.contains('blue chip')) return 'equity_large_cap';
    if (lower.contains('sectoral')  || lower.contains('thematic') || lower.contains('pharma') ||
        lower.contains('healthcare')|| lower.contains('infra')     || lower.contains('technology') ||
        lower.contains('banking fund') || lower.contains('fmcg'))  return 'equity_sectoral';
    if (lower.contains('value fund') || lower.contains('contra') || lower.contains('dividend yield')) return 'equity_value';
    if (lower.contains('focused'))    return 'equity_focused';
    if (lower.contains('balanced advantage') || lower.contains('dynamic asset')) return 'hybrid_balanced_advantage';
    if (lower.contains('equity savings')) return 'hybrid_equity_savings';
    if (lower.contains('arbitrage'))      return 'hybrid_arbitrage';
    if (lower.contains('multi asset') || lower.contains('multi-asset')) return 'hybrid_multi_asset';
    if (lower.contains('conservative hybrid')) return 'hybrid_conservative';
    if (lower.contains('hybrid') || lower.contains('balanced')) return 'hybrid';
    if (lower.contains('overnight') || lower.contains('liquid fund')) return 'debt_liquid';
    if (lower.contains('gilt'))           return 'debt_gilt';
    if (lower.contains('corporate bond')) return 'debt_corporate_bond';
    if (lower.contains('credit risk'))    return 'debt_credit_risk';
    if (lower.contains('banking and psu') || lower.contains('banking & psu')) return 'debt_banking_psu';
    if (lower.contains('dynamic bond'))   return 'debt_dynamic';
    if (lower.contains('medium duration') || lower.contains('medium term')) return 'debt_medium';
    if (lower.contains('long duration'))  return 'debt_long';
    if (lower.contains('short duration') || lower.contains('ultra short') || lower.contains('low duration')) return 'debt_short';
    if (lower.contains('debt') || lower.contains('fixed income')) return 'debt_short';
    if (lower.contains('fund of fund') || lower.contains(' fof')) return 'fof';
    return null;
  }



  static const _knownHouses = [
    'Mirae Asset', 'HDFC', 'SBI', 'Axis', 'ICICI Prudential', 'Kotak',
    'Nippon India', 'DSP', 'Motilal Oswal', 'Parag Parikh', 'Quant',
    'Canara Robeco', 'Edelweiss', 'Franklin Templeton', 'Aditya Birla',
    'UTI', 'Tata', 'Sundaram', 'Union', 'Invesco', 'PGIM', 'Navi',
    'WhiteOak', 'Bajaj Finserv', 'Mahindra Manulife', 'LIC',
  ];
}

class MfSearchDialog extends StatefulWidget {
  const MfSearchDialog({super.key});

  /// Shows the dialog and returns [MfSearchResult] or null if cancelled.
  static Future<MfSearchResult?> show(BuildContext context) {
    return showModalBottomSheet<MfSearchResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MfSearchDialog(),
    );
  }

  @override
  State<MfSearchDialog> createState() => _MfSearchDialogState();
}

class _MfSearchDialogState extends State<MfSearchDialog> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  List<MfSearchResult> _results = [];
  bool   _loading       = false;
  String _error         = '';
  int?   _selectingCode; // scheme code currently being enriched via API
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() { _results = []; _error = ''; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    setState(() { _loading = true; _error = ''; });
    try {
      final url = Uri.parse('https://api.mfapi.in/mf/search?q=${Uri.encodeComponent(q)}');
      final res = await http.get(url).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final list = json.decode(res.body) as List;
        setState(() {
          _results = list.map((e) => MfSearchResult.fromMap(e as Map<String, dynamic>)).toList();
          _loading = false;
        });
      } else {
        setState(() { _error = 'Search failed (${res.statusCode})'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'No connection'; _loading = false; });
    }
  }

  /// Fetches the full scheme details from mfapi.in and returns an enriched result.
  /// Fields populated from the API (not guessed):
  ///   • category   — from meta.scheme_category (official SEBI/AMFI classification)
  ///   • fundHouse  — from meta.fund_house (full fund house name)
  ///   • latestNav  — first entry in data[] (most recent NAV date)
  Future<void> _selectFund(MfSearchResult r) async {
    setState(() => _selectingCode = r.schemeCode);
    try {
      final url = Uri.parse('https://api.mfapi.in/mf/${r.schemeCode}');
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body      = json.decode(res.body) as Map<String, dynamic>;
        final meta      = body['meta']  as Map<String, dynamic>?;
        final data      = body['data']  as List?;
        final rawCat    = (meta?['scheme_category'] as String?) ?? '';
        final apiHouse  = (meta?['fund_house']      as String?) ?? '';
        final latestNav = (data != null && data.isNotEmpty)
            ? double.tryParse((data.first['nav'] as String?) ?? '')
            : null;
        final mappedCat = MfSearchResult.mapSchemeCategory(rawCat, r.schemeName);
        if (mounted) {
          Navigator.pop(context, MfSearchResult(
            schemeCode: r.schemeCode,
            schemeName: r.schemeName,
            fundHouse:  apiHouse.isNotEmpty ? apiHouse : r.fundHouse,
            plan:       r.plan,
            category:   mappedCat ?? r.category,
            isElss:     mappedCat == 'elss',
            latestNav:  latestNav,
            isEnriched: true,
          ));
        }
        return;
      }
    } catch (_) {}
    // Fallback: return name-based result if API fails
    if (mounted) Navigator.pop(context, r);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text('Search Mutual Funds', style: GoogleFonts.inter(
              color: AppColors.text1, fontSize: 18, fontWeight: FontWeight.w800)),
            const Spacer(),
            TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.text3))),
          ]),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            onChanged: _onChanged,
            style: GoogleFonts.inter(color: AppColors.text1, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Try "Mirae Large Cap", "Parag Parikh", "Nifty 50"…',
              hintStyle: GoogleFonts.inter(color: AppColors.text3, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.text3, size: 20),
              suffixIcon: _ctrl.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear_rounded, color: AppColors.text3, size: 18),
                      onPressed: () { _ctrl.clear(); setState(() { _results = []; }); })
                  : null,
              filled: true, fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Results count
        if (_results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text('${_results.length} funds found',
                style: GoogleFonts.inter(color: AppColors.text3, fontSize: 12)),
              const Spacer(),
              Text('Powered by mfapi.in',
                style: GoogleFonts.inter(color: AppColors.text3, fontSize: 10)),
            ]),
          ),

        const SizedBox(height: 4),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_error.isNotEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🔌', style: TextStyle(fontSize: 40)),
      const SizedBox(height: 12),
      Text(_error, style: GoogleFonts.inter(color: AppColors.text2)),
    ]));
    if (_ctrl.text.length < 2) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🔍', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      Text('Search from 16,000+ schemes', style: GoogleFonts.inter(color: AppColors.text2, fontSize: 14)),
      const SizedBox(height: 4),
      Text('Type at least 2 characters', style: GoogleFonts.inter(color: AppColors.text3, fontSize: 12)),
    ]));
    if (_results.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🤔', style: TextStyle(fontSize: 40)),
      const SizedBox(height: 12),
      Text('No funds found for "${_ctrl.text}"', style: GoogleFonts.inter(color: AppColors.text2)),
      const SizedBox(height: 4),
      Text('Try a shorter or different name', style: GoogleFonts.inter(color: AppColors.text3, fontSize: 12)),
    ]));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r         = _results[i];
        final isDirect  = r.plan == 'direct';
        final isBusy    = _selectingCode == r.schemeCode;
        final catLabel  = _catLabel(r.category);
        return GestureDetector(
          onTap: isBusy || _selectingCode != null ? null : () => _selectFund(r),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: (_selectingCode != null && !isBusy) ? 0.45 : 1.0,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isBusy ? AppColors.primary : AppColors.border,
                  width: isBusy ? 1.5 : 1.0,
                ),
              ),
              child: Row(children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D9A3).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: isBusy
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary))
                      : const Text('📊', style: TextStyle(fontSize: 20))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.schemeName,
                    style: GoogleFonts.inter(
                      color: AppColors.text1, fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('Code: ${r.schemeCode}',
                      style: GoogleFonts.inter(color: AppColors.text3, fontSize: 11)),
                    if (r.plan != null) ...[
                      const SizedBox(width: 6),
                      _chip(
                        isDirect ? 'Direct' : 'Regular',
                        isDirect ? const Color(0xFF00D9A3) : const Color(0xFFFFB800),
                      ),
                    ],
                    if (catLabel != null) ...[
                      const SizedBox(width: 6),
                      _chip(catLabel, const Color(0xFF8B5CF6)),
                    ],
                  ]),
                  if (isBusy)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Fetching official details…',
                        style: GoogleFonts.inter(
                          color: AppColors.primary, fontSize: 10,
                          fontStyle: FontStyle.italic)),
                    ),
                ])),
                if (!isBusy)
                  const Icon(Icons.chevron_right_rounded,
                    color: AppColors.text3, size: 18),
              ]),
            ),
          ),
        );
      },
    );
  }

  static Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(5)),
    child: Text(label,
      style: GoogleFonts.inter(
        color: color, fontSize: 9, fontWeight: FontWeight.w700)),
  );

  /// Short display label for a category key, shown as a hint badge.
  static String? _catLabel(String? cat) {
    const m = <String, String>{
      'commodity_gold_fof': '🥇 Gold FoF', 'commodity_gold_etf': '🥇 Gold ETF',
      'commodity_silver_fof': '🥈 Silver FoF', 'commodity_silver_etf': '🥈 Silver ETF',
      'elss': 'ELSS', 'index': 'Index/ETF',
      'equity_large_cap': 'Large Cap', 'equity_mid_cap': 'Mid Cap',
      'equity_small_cap': 'Small Cap', 'equity_multi_cap': 'Multi Cap',
      'equity_flexi': 'Flexi Cap', 'equity_large_mid': 'Lg & Mid',
      'equity_sectoral': 'Sectoral', 'equity_value': 'Value',
      'equity_focused': 'Focused', 'hybrid': 'Hybrid',
      'hybrid_balanced_advantage': 'BAF', 'hybrid_arbitrage': 'Arbitrage',
      'hybrid_equity_savings': 'Eq Savings', 'hybrid_multi_asset': 'Multi-Asset',
      'hybrid_conservative': 'Cons Hybrid',
      'debt_liquid': 'Liquid', 'debt_short': 'Debt ST',
      'debt_medium': 'Debt MT', 'debt_long': 'Debt LT',
      'debt_gilt': 'Gilt', 'debt_corporate_bond': 'Corp Bond',
      'debt_credit_risk': 'Credit Risk', 'debt_banking_psu': 'Bank/PSU',
      'debt_dynamic': 'Dyn Bond',
      'international_fof': '🌐 Intl FoF', 'fof': 'FoF',
    };
    return m[cat];
  }
}
