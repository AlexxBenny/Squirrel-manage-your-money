import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../core/constants/categories.dart';
import '../core/database/database_helper.dart';
import '../core/utils/xirr_calculator.dart';
import '../models/holding_model.dart';

/// Holds a price update for one holding, keyed by holding ID.
typedef _PriceUpdate = ({
  double price,
  double? changePct,
  double? currentValueOverride,
});

class PortfolioProvider extends ChangeNotifier {
  final _db   = DatabaseHelper.instance;
  final _uuid = const Uuid();

  List<HoldingModel> _holdings = [];
  bool _isLoading      = false;
  bool _isFetching     = false;
  String? _error;

  List<HoldingModel> get holdings      => _holdings;
  bool get isLoading                   => _isLoading;
  bool get isFetchingPrices            => _isFetching;
  String? get error                    => _error;

  // ── Aggregates ─────────────────────────────────────────────────────────────

  double get totalInvested     => _holdings.fold(0, (s, h) => s + h.investedAmount);
  double get totalCurrentValue => _holdings.fold(0, (s, h) => s + h.currentValue);
  double get totalPnL          => totalCurrentValue - totalInvested;
  double get totalPnLPct       => totalInvested > 0 ? totalPnL / totalInvested * 100 : 0;

  /// Portfolio-level XIRR across all SIP holdings (most meaningful metric)
  double? get portfolioXirr {
    final flows = <double>[];
    final dates = <DateTime>[];
    for (final h in _holdings) {
      if (h.assetClass == 'mutual_fund' &&
          h.mfType == 'sip' &&
          h.sipDay != null &&
          h.mfSipAmount != null &&
          h.mfSipStart != null) {
        final (f, d) = XirrCalculator.buildSipCashFlows(
          sipAmount: h.mfSipAmount!,
          sipDay: h.sipDay!,
          startDate: h.mfSipStart!,
          currentValue: h.currentValue,
        );
        flows.addAll(f);
        dates.addAll(d);
      } else if (h.investedAmount > 0) {
        flows.add(-h.investedAmount);
        dates.add(h.createdAt);
      }
    }
    if (flows.isEmpty) return null;
    flows.add(totalCurrentValue);
    dates.add(DateTime.now());
    return XirrCalculator.calculate(flows, dates);
  }

  /// Group by asset class → current value
  Map<String, double> get byAssetClass {
    final map = <String, double>{};
    for (final h in _holdings) {
      map[h.assetClass] = (map[h.assetClass] ?? 0) + h.currentValue;
    }
    return map;
  }

  /// Market-linked vs Fixed-income split
  ({double marketLinked, double fixedIncome}) get riskSplit {
    double ml = 0, fi = 0;
    for (final h in _holdings) {
      if (AssetClasses.isMarketLinked(h.assetClass)) { ml += h.currentValue; }
      else { fi += h.currentValue; }
    }
    return (marketLinked: ml, fixedIncome: fi);
  }

  /// Diversification score 0–100 (higher = more diversified)
  int get diversificationScore {
    if (_holdings.isEmpty) return 0;
    final total = totalCurrentValue;
    if (total <= 0) return 0;
    // Herfindahl-Hirschman Index
    double hhi = 0;
    for (final entry in byAssetClass.entries) {
      final share = entry.value / total;
      hhi += share * share;
    }
    // HHI → 1 = monopoly, 1/n = perfect. Map to 0–100
    final n = byAssetClass.length;
    if (n <= 1) return 0;
    final normalized = (1 / n - hhi) / (1 / n - 1); // 0=monopoly, 1=perfect
    return (normalized.clamp(0, 1) * 100).round();
  }

  // ── Alerts ─────────────────────────────────────────────────────────────────

  List<PortfolioAlert> get alerts {
    final result = <PortfolioAlert>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final h in _holdings) {
      if (!h.alertEnabled) continue;

      // SIP upcoming
      if (h.assetClass == 'mutual_fund' && h.sipDay != null && h.mfSipAmount != null) {
        final nextSip = _nextSipDate(today, h.sipDay!);
        final daysAway = nextSip.difference(today).inDays;
        if (daysAway <= 3) {
          result.add(PortfolioAlert(
            holdingId: h.id,
            title: 'SIP Due ${daysAway == 0 ? 'Today' : 'in $daysAway day${daysAway > 1 ? 's' : ''}'}',
            subtitle: '${h.name} · ₹${h.mfSipAmount!.toStringAsFixed(0)}',
            emoji: '🔔',
            severity: daysAway == 0 ? AlertSeverity.urgent : AlertSeverity.warning,
            dueDate: nextSip,
          ));
        }
      }

      // FD / Bond maturity
      if (h.maturityDate != null) {
        final daysToMaturity = h.maturityDate!.difference(today).inDays;
        if (daysToMaturity >= 0 && daysToMaturity <= 30) {
          result.add(PortfolioAlert(
            holdingId: h.id,
            title: 'Matures ${daysToMaturity == 0 ? 'Today' : 'in $daysToMaturity days'}',
            subtitle: '${h.name} · ₹${(h.fdMaturityAmount ?? h.currentValue).toStringAsFixed(0)}',
            emoji: daysToMaturity <= 7 ? '⚠️' : '⏰',
            severity: daysToMaturity <= 7 ? AlertSeverity.urgent : AlertSeverity.warning,
            dueDate: h.maturityDate!,
          ));
        }
      }

      // EMI due
      if (h.assetClass == 'real_estate' && h.reHasLoan && h.reEmi != null) {
        // Estimate next EMI = same day each month
        final emiDay = h.createdAt.day;
        final nextEmi = _nextSipDate(today, emiDay);
        final daysAway = nextEmi.difference(today).inDays;
        if (daysAway <= 3) {
          result.add(PortfolioAlert(
            holdingId: h.id,
            title: 'EMI Due ${daysAway == 0 ? 'Today' : 'in $daysAway day${daysAway > 1 ? 's' : ''}'}',
            subtitle: '${h.name} · ₹${h.reEmi!.toStringAsFixed(0)}',
            emoji: '🏠',
            severity: daysAway == 0 ? AlertSeverity.urgent : AlertSeverity.warning,
            dueDate: nextEmi,
          ));
        }
      }

      // PPF annual contribution deadline (March 31)
      if (h.assetClass == 'other_asset' && h.otherInstrument == 'ppf') {
        final march31 = DateTime(now.year, 3, 31);
        final deadline = now.month <= 3 ? march31 : DateTime(now.year + 1, 3, 31);
        final days = deadline.difference(today).inDays;
        if (days <= 30) {
          result.add(PortfolioAlert(
            holdingId: h.id,
            title: 'PPF Deadline in $days days',
            subtitle: 'Contribute before 31 March · Max ₹1,50,000',
            emoji: '📋',
            severity: days <= 7 ? AlertSeverity.urgent : AlertSeverity.info,
            dueDate: deadline,
          ));
        }
      }
    }

    result.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return result;
  }

  // ── Load & Persist ──────────────────────────────────────────────────────────

  Future<void> loadHoldings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final maps = await _db.getHoldings();
      _holdings = maps.map(HoldingModel.fromMap).toList();
      await _applyCachedPrices();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// FIX #5: One batch DB query replaces N individual queries (N+1 eliminated).
  Future<void> _applyCachedPrices() async {
    final tickers = _holdings.where((h) => h.ticker != null).map((h) => h.ticker!).toList();
    if (tickers.isEmpty) return;
    final cacheMap = await _db.getCachedPrices(tickers);
    final now = DateTime.now();
    _holdings = _holdings.map((h) {
      if (h.ticker == null) return h;
      final c = cacheMap[h.ticker!];
      if (c == null) return h;
      final ageMin = now.difference(DateTime.parse(c['fetched_at'] as String)).inMinutes;
      if (ageMin >= 60) return h;
      return h.copyWith(
        currentPrice: (c['price'] as num).toDouble(),
        changePct: (c['change_pct'] as num?)?.toDouble(),
      );
    }).toList();
  }

  // ── Live Price Fetching ────────────────────────────────────────────────────

  /// FIX #1 + #4: Updates collected into a shared ID-keyed map, applied
  /// atomically after all fetches complete — no index-based race condition.
  Future<void> fetchLivePrices() async {
    if (_isFetching) return; // prevent overlapping fetch
    _isFetching = true;
    notifyListeners();
    final updates = <String, _PriceUpdate>{};
    await Future.wait([
      _fetchCryptoPrices(updates),
      _fetchStockAndEtfPrices(updates),
      _fetchMfNavs(updates),
    ]);
    if (updates.isNotEmpty) {
      _holdings = _holdings.map((h) {
        final u = updates[h.id];
        if (u == null) return h;
        return h.copyWith(
          currentPrice: u.price,
          changePct: u.changePct,
          currentValueOverride: u.currentValueOverride,
        );
      }).toList();
    }
    _isFetching = false;
    notifyListeners();
  }

  Future<void> _fetchCryptoPrices(Map<String, _PriceUpdate> updates) async {
    final crypto = _holdings.where((h) => h.assetClass == 'crypto' && h.ticker != null).toList();
    if (crypto.isEmpty) return;
    try {
      final ids = crypto.map((h) => (h.meta['coin_id'] as String? ?? h.ticker!).toLowerCase()).join(',');
      final url = Uri.parse('https://api.coingecko.com/api/v3/simple/price?ids=$ids&vs_currencies=inr&include_24hr_change=true');
      final res = await http.get(url).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        for (final h in crypto) {
          final coinId = (h.meta['coin_id'] as String? ?? h.ticker ?? '').toLowerCase();
          final pd = data[coinId] as Map<String, dynamic>?;
          if (pd != null) {
            final price = (pd['inr'] as num).toDouble();
            final chg   = (pd['inr_24h_change'] as num?)?.toDouble();
            await _db.upsertPrice(h.ticker!, price, chg);
            updates[h.id] = (price: price, changePct: chg, currentValueOverride: null);
          }
        }
      }
    } catch (_) {}
  }

  /// FIX #6: All stock requests now run in parallel instead of sequentially.
  Future<void> _fetchStockAndEtfPrices(Map<String, _PriceUpdate> updates) async {
    final holdings = _holdings.where((h) =>
        (h.assetClass == 'stock' || (h.assetClass == 'gold' && h.goldType == 'etf'))
        && h.ticker != null).toList();
    if (holdings.isEmpty) return;
    await Future.wait(holdings.map((h) => _fetchOneStock(h, updates)));
  }

  Future<void> _fetchOneStock(HoldingModel h, Map<String, _PriceUpdate> updates) async {
    try {
      final sym = h.exchange == 'BSE' ? '${h.ticker}.BO' : '${h.ticker}.NS';
      final url = Uri.parse('https://query1.finance.yahoo.com/v8/finance/chart/$sym?interval=1d&range=1d');
      final res = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data   = json.decode(res.body) as Map<String, dynamic>;
        final result = (data['chart']?['result'] as List?)?.firstOrNull as Map<String, dynamic>?;
        if (result != null) {
          final meta  = result['meta'] as Map<String, dynamic>;
          final price = (meta['regularMarketPrice'] as num).toDouble();
          final prev  = (meta['chartPreviousClose'] as num?)?.toDouble();
          final chg   = prev != null ? (price - prev) / prev * 100 : null;
          await _db.upsertPrice(h.ticker!, price, chg);
          updates[h.id] = (price: price, changePct: chg, currentValueOverride: null);
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchMfNavs(Map<String, _PriceUpdate> updates) async {
    final mfs = _holdings.where((h) => h.assetClass == 'mutual_fund' && h.mfSchemeCode != null).toList();
    for (final h in mfs) {
      try {
        final url = Uri.parse('https://api.mfapi.in/mf/${h.mfSchemeCode}/latest');
        final res = await http.get(url).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final data   = json.decode(res.body) as Map<String, dynamic>;
          final navStr = (data['data'] as List?)?.firstOrNull?['nav'] as String?;
          if (navStr != null) {
            final nav = double.tryParse(navStr);
            if (nav != null) {
              final units = (h.meta['units'] as num?)?.toDouble();
              final cv    = units != null ? units * nav : null;
              updates[h.id] = (price: nav, changePct: null, currentValueOverride: cv);
            }
          }
        }
      } catch (_) {}
    }
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// FIX #4: Optimistic local update avoids calling loadHoldings() which
  /// would race with any in-flight fetchLivePrices() operation.
  Future<void> addHolding(HoldingModel holding) async {
    await _db.insertHolding(holding.toMap());
    _holdings = [..._holdings, holding]..sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  Future<void> updateHolding(HoldingModel holding) async {
    await _db.updateHolding(holding.toMap());
    final idx = _holdings.indexWhere((h) => h.id == holding.id);
    if (idx != -1) {
      _holdings = List.of(_holdings)..[idx] = holding;
    }
    notifyListeners();
  }

  Future<void> deleteHolding(String id) async {
    await _db.deleteHolding(id);
    _holdings.removeWhere((h) => h.id == id);
    notifyListeners();
  }

  String newId() => _uuid.v4();

  // ── Helpers ────────────────────────────────────────────────────────────────

  static DateTime _nextSipDate(DateTime from, int day) {
    final now = DateTime.now();
    DateTime candidate = DateTime(from.year, from.month, _clampDay(day, from.year, from.month));
    if (!candidate.isAfter(DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1)))) {
      final next = from.month == 12
          ? DateTime(from.year + 1, 1, 1)
          : DateTime(from.year, from.month + 1, 1);
      candidate = DateTime(next.year, next.month, _clampDay(day, next.year, next.month));
    }
    return candidate;
  }

  static int _clampDay(int day, int year, int month) {
    final max = DateTimeHelper.daysInMonth(year, month);
    return day > max ? max : day;
  }
}
