import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/news_service.dart';
import '../../models/holding_model.dart';
import '../../providers/portfolio_provider.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});
  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<NewsItem> _news = [];
  bool _loading = false;
  String _error = '';
  String _filter = 'all'; // all | portfolio

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final holdings = context.read<PortfolioProvider>().holdings;
      final items = await NewsService.fetchForHoldings(holdings);
      setState(() { _news = items; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load news'; _loading = false; });
    }
  }

  List<NewsItem> get _filtered {
    if (_filter == 'portfolio') return _news.where((n) => n.relatedHoldingIds.isNotEmpty).toList();
    return _news;
  }

  @override
  Widget build(BuildContext context) {
    final holdings = context.read<PortfolioProvider>().holdings;
    final portfolioCount = _news.where((n) => n.relatedHoldingIds.isNotEmpty).length;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _fetch,
        color: AppColors.primary,
        child: CustomScrollView(slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: AppColors.background,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.headerGradient),
                padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Market News', style: GoogleFonts.inter(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Linked to your ${holdings.length} investments',
                    style: GoogleFonts.inter(color: Colors.white60, fontSize: 12)),
                ]),
              ),
            ),
          ),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              _FilterChip('All News', 'all', _news.length, _filter, (v) => setState(() => _filter = v)),
              const SizedBox(width: 8),
              _FilterChip('Your Portfolio', 'portfolio', portfolioCount, _filter, (v) => setState(() => _filter = v), highlight: true),
              const Spacer(),
              if (_loading) const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
            ]),
          )),
          if (_error.isNotEmpty)
            SliverFillRemaining(child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('📡', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(_error, style: GoogleFonts.inter(color: AppColors.text2)),
                const SizedBox(height: 12),
                TextButton(onPressed: _fetch, child: const Text('Retry')),
              ])))
          else if (!_loading && _filtered.isEmpty)
            SliverFillRemaining(child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('📰', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(_filter == 'portfolio'
                    ? 'No news matched your holdings\nTry adding stocks with tickers'
                    : 'No news available — pull to refresh',
                  style: GoogleFonts.inter(color: AppColors.text2, fontSize: 14),
                  textAlign: TextAlign.center),
              ])))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) => _NewsCard(item: _filtered[i], holdings: holdings),
                childCount: _filtered.length,
              )),
            ),
        ]),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label, value, current;
  final int count;
  final ValueChanged<String> onTap;
  final bool highlight;
  const _FilterChip(this.label, this.value, this.count, this.current, this.onTap,
      {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final sel = current == value;
    final color = highlight ? const Color(0xFF6C63FF) : AppColors.primary;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? color : AppColors.border, width: sel ? 1.5 : 1)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: GoogleFonts.inter(
            color: sel ? color : AppColors.text2,
            fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: sel ? color : AppColors.border,
                borderRadius: BorderRadius.circular(10)),
              child: Text('$count', style: GoogleFonts.inter(
                color: sel ? Colors.white : AppColors.text2,
                fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsItem item;
  final List<HoldingModel> holdings;
  const _NewsCard({required this.item, required this.holdings});

  @override
  Widget build(BuildContext context) {
    final isRelevant = item.relatedHoldingIds.isNotEmpty;
    final matched = holdings.where((h) => item.relatedHoldingIds.contains(h.id)).toList();

    return GestureDetector(
      onTap: () async {
        if (item.url != null) {
          final uri = Uri.tryParse(item.url!);
          if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRelevant ? const Color(0xFF6C63FF).withValues(alpha: 0.35) : AppColors.border,
            width: isRelevant ? 1.5 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Portfolio match badge
            if (isRelevant) ...[
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.auto_awesome_rounded, size: 10, color: Color(0xFF6C63FF)),
                    const SizedBox(width: 4),
                    Text('Affects your portfolio', style: GoogleFonts.inter(
                      color: const Color(0xFF6C63FF), fontSize: 10, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(width: 8),
                ...matched.take(2).map((h) => Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(6)),
                  child: Text(h.ticker ?? h.name.split(' ').first,
                    style: GoogleFonts.inter(color: AppColors.text2, fontSize: 10, fontWeight: FontWeight.w600)),
                )),
              ]),
              const SizedBox(height: 8),
            ],
            Text(item.title, style: GoogleFonts.inter(
              color: AppColors.text1, fontSize: 13, fontWeight: FontWeight.w700, height: 1.4),
              maxLines: 3, overflow: TextOverflow.ellipsis),
            if (item.summary?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(item.summary!, style: GoogleFonts.inter(
                color: AppColors.text2, fontSize: 12, height: 1.4),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            Row(children: [
              if (item.source?.isNotEmpty == true) Text(item.source!,
                style: GoogleFonts.inter(color: AppColors.text3, fontSize: 11, fontWeight: FontWeight.w600)),
              if (item.source != null && item.publishedAt != null)
                Text(' · ', style: GoogleFonts.inter(color: AppColors.text3, fontSize: 11)),
              Text(NewsService.timeAgo(item.publishedAt),
                style: GoogleFonts.inter(color: AppColors.text3, fontSize: 11)),
              const Spacer(),
              if (item.url != null) const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.text3),
            ]),
          ]),
        ),
      ),
    );
  }
}
