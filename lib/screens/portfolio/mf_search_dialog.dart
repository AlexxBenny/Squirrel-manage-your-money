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
  final String? plan; // Direct/Regular

  MfSearchResult({
    required this.schemeCode,
    required this.schemeName,
    this.fundHouse,
    this.plan,
  });

  factory MfSearchResult.fromMap(Map<String, dynamic> m) {
    final name = m['schemeName'] as String? ?? '';
    // Parse fund house from scheme name (usually first part before "-" or " ")
    String? house;
    String? plan;
    final lower = name.toLowerCase();
    if (lower.contains('direct')) plan = 'direct';
    else if (lower.contains('regular')) plan = 'regular';
    // Common fund houses
    for (final h in _knownHouses) {
      if (lower.contains(h.toLowerCase())) { house = h; break; }
    }
    return MfSearchResult(
      schemeCode: m['schemeCode'] as int,
      schemeName: name,
      fundHouse: house,
      plan: plan,
    );
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
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<MfSearchResult> _results = [];
  bool _loading = false;
  String _error = '';
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
        final r = _results[i];
        final isDirect = r.plan == 'direct';
        return GestureDetector(
          onTap: () => Navigator.pop(context, r),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9A3).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: const Text('📊', style: TextStyle(fontSize: 20))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.schemeName,
                  style: GoogleFonts.inter(color: AppColors.text1, fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Text('Code: ${r.schemeCode}',
                    style: GoogleFonts.inter(color: AppColors.text3, fontSize: 11)),
                  if (r.plan != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDirect
                            ? const Color(0xFF00D9A3).withValues(alpha: 0.1)
                            : const Color(0xFFFFB800).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6)),
                      child: Text(isDirect ? 'Direct' : 'Regular',
                        style: GoogleFonts.inter(
                          color: isDirect ? const Color(0xFF00D9A3) : const Color(0xFFFFB800),
                          fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
              ])),
              const Icon(Icons.chevron_right_rounded, color: AppColors.text3, size: 18),
            ]),
          ),
        );
      },
    );
  }
}
