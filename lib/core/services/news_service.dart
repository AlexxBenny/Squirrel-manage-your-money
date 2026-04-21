import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/holding_model.dart';

class NewsItem {
  final String title;
  final String? summary;
  final String? url;
  final String? source;
  final DateTime? publishedAt;
  final List<String> relatedHoldingIds; // matched from portfolio

  const NewsItem({
    required this.title,
    this.summary,
    this.url,
    this.source,
    this.publishedAt,
    this.relatedHoldingIds = const [],
  });
}

class NewsService {
  /// Fetch news from Yahoo Finance for given tickers.
  /// Returns general market news when no tickers provided.
  static Future<List<NewsItem>> fetchForHoldings(List<HoldingModel> holdings) async {
    final tickers = <String>[];
    for (final h in holdings) {
      switch (h.assetClass) {
        case 'stock':
          if (h.ticker != null) {
            tickers.add('${h.ticker}.${h.exchange == 'BSE' ? 'BO' : 'NS'}');
          }
        case 'crypto':
          final t = h.ticker;
          if (t != null) tickers.add('$t-USD');
        case 'mutual_fund':
          // No direct Yahoo Finance ticker for MFs — use fund house name
          break;
        default:
          break;
      }
    }
    // Always include Nifty 50 for general India market news
    tickers.add('^NSEI');

    final allItems = <NewsItem>[];
    // Batch tickers (Yahoo accepts comma-separated)
    final batch = tickers.take(10).join(',');
    try {
      final url = Uri.parse(
        'https://query2.finance.yahoo.com/v2/finance/news?tickers=$batch&count=30&lang=en-US',
      );
      final res = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final items = data['items']?['result'] as List? ?? [];
        for (final item in items) {
          final m = item as Map<String, dynamic>;
          final ts = m['published_at'] as int?;
          final related = _matchHoldings(m['title'] as String? ?? '', holdings);
          allItems.add(NewsItem(
            title: m['title'] as String? ?? '',
            summary: m['summary'] as String?,
            url: m['link'] as String?,
            source: (m['publisher'] as Map<String, dynamic>?)?['name'] as String?,
            publishedAt: ts != null ? DateTime.fromMillisecondsSinceEpoch(ts * 1000) : null,
            relatedHoldingIds: related,
          ));
        }
      }
    } catch (_) {}

    // Fallback: fetch general India news from a secondary endpoint
    if (allItems.isEmpty) {
      try {
        final url2 = Uri.parse(
          'https://query2.finance.yahoo.com/v2/finance/news?tickers=%5ENSEI&count=15&lang=en-US',
        );
        final res = await http.get(url2, headers: {'User-Agent': 'Mozilla/5.0'})
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final data = json.decode(res.body) as Map<String, dynamic>;
          final items = data['items']?['result'] as List? ?? [];
          for (final item in items) {
            final m = item as Map<String, dynamic>;
            final ts = m['published_at'] as int?;
            allItems.add(NewsItem(
              title: m['title'] as String? ?? '',
              summary: m['summary'] as String?,
              url: m['link'] as String?,
              source: (m['publisher'] as Map<String, dynamic>?)?['name'] as String?,
              publishedAt: ts != null ? DateTime.fromMillisecondsSinceEpoch(ts * 1000) : null,
            ));
          }
        }
      } catch (_) {}
    }

    // Sort: portfolio-relevant first, then by date
    allItems.sort((a, b) {
      if (a.relatedHoldingIds.isNotEmpty && b.relatedHoldingIds.isEmpty) return -1;
      if (a.relatedHoldingIds.isEmpty && b.relatedHoldingIds.isNotEmpty) return 1;
      if (a.publishedAt != null && b.publishedAt != null) {
        return b.publishedAt!.compareTo(a.publishedAt!);
      }
      return 0;
    });

    return allItems;
  }

  /// Simple keyword matching: does this article mention any of your holdings?
  static List<String> _matchHoldings(String title, List<HoldingModel> holdings) {
    final lower = title.toLowerCase();
    final matched = <String>[];
    for (final h in holdings) {
      final nameParts = h.name.toLowerCase().split(' ');
      // Match if 2+ significant words from holding name appear in title
      final significant = nameParts.where((w) => w.length > 4).toList();
      final hits = significant.where((w) => lower.contains(w)).length;
      if (hits >= 1) matched.add(h.id);
      // Also match by ticker
      if (h.ticker != null && lower.contains(h.ticker!.toLowerCase())) {
        if (!matched.contains(h.id)) matched.add(h.id);
      }
    }
    return matched;
  }

  static String timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
