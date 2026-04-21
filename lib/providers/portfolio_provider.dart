import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../core/database/database_helper.dart';
import '../models/holding_model.dart';

class PortfolioProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  final _uuid = const Uuid();

  List<HoldingModel> _holdings = [];
  bool _isLoading = false;
  bool _isFetchingPrices = false;
  String? _error;

  List<HoldingModel> get holdings => _holdings;
  bool get isLoading => _isLoading;
  bool get isFetchingPrices => _isFetchingPrices;
  String? get error => _error;

  double get totalInvested => _holdings.fold(0, (s, h) => s + h.investedValue);
  double get totalCurrentValue => _holdings.fold(0, (s, h) => s + h.currentValue);
  double get totalPnL => totalCurrentValue - totalInvested;
  double get totalPnLPct => totalInvested > 0 ? (totalPnL / totalInvested) * 100 : 0;

  Map<String, double> get byAssetClass {
    final map = <String, double>{};
    for (final h in _holdings) {
      map[h.assetClass] = (map[h.assetClass] ?? 0) + h.currentValue;
    }
    return map;
  }

  Future<void> loadHoldings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final maps = await _db.getHoldings();
      _holdings = maps.map(HoldingModel.fromMap).toList();
      await _loadCachedPrices();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCachedPrices() async {
    final updated = <HoldingModel>[];
    for (final h in _holdings) {
      final cached = await _db.getCachedPrice(h.ticker);
      if (cached != null) {
        final fetchedAt = DateTime.parse(cached['fetched_at'] as String);
        if (DateTime.now().difference(fetchedAt).inMinutes < 30) {
          updated.add(h.copyWith(
            currentPrice: (cached['price'] as num).toDouble(),
            changePct: (cached['change_pct'] as num?)?.toDouble(),
          ));
          continue;
        }
      }
      updated.add(h);
    }
    _holdings = updated;
  }

  Future<void> fetchLivePrices() async {
    _isFetchingPrices = true;
    notifyListeners();

    final cryptoHoldings = _holdings.where((h) => h.assetClass == 'crypto').toList();
    final stockHoldings = _holdings
        .where((h) => h.assetClass == 'stock' || h.assetClass == 'mutual_fund')
        .toList();

    if (cryptoHoldings.isNotEmpty) {
      await _fetchCryptoPrices(cryptoHoldings);
    }
    if (stockHoldings.isNotEmpty) {
      await _fetchStockPrices(stockHoldings);
    }

    _isFetchingPrices = false;
    notifyListeners();
  }

  Future<void> _fetchCryptoPrices(List<HoldingModel> holdings) async {
    try {
      final ids = holdings.map((h) => h.ticker.toLowerCase()).join(',');
      final url = Uri.parse(
          'https://api.coingecko.com/api/v3/simple/price?ids=$ids&vs_currencies=inr&include_24hr_change=true');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final updated = <HoldingModel>[];
        for (final h in _holdings) {
          final priceData = data[h.ticker.toLowerCase()] as Map<String, dynamic>?;
          if (priceData != null) {
            final price = (priceData['inr'] as num).toDouble();
            final change = (priceData['inr_24h_change'] as num?)?.toDouble();
            await _db.upsertPrice(h.ticker, price, change);
            updated.add(h.copyWith(currentPrice: price, changePct: change));
          } else {
            updated.add(h);
          }
        }
        _holdings = updated;
      }
    } catch (_) {
      // silently fail, use cached or avg price
    }
  }

  Future<void> _fetchStockPrices(List<HoldingModel> holdings) async {
    for (final h in holdings) {
      try {
        final ticker = h.exchange == 'NSE' ? '${h.ticker}.NS' : h.ticker;
        final url = Uri.parse(
            'https://query1.finance.yahoo.com/v8/finance/chart/$ticker?interval=1d&range=1d');
        final response = await http.get(url, headers: {
          'User-Agent': 'Mozilla/5.0',
        }).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final result = data['chart']?['result'] as List?;
          if (result != null && result.isNotEmpty) {
            final meta = result[0]['meta'] as Map<String, dynamic>;
            final price = (meta['regularMarketPrice'] as num).toDouble();
            final prevClose = (meta['chartPreviousClose'] as num?)?.toDouble();
            final changePct = prevClose != null ? ((price - prevClose) / prevClose) * 100 : null;
            await _db.upsertPrice(h.ticker, price, changePct);
            final idx = _holdings.indexWhere((x) => x.id == h.id);
            if (idx != -1) {
              _holdings[idx] = h.copyWith(currentPrice: price, changePct: changePct);
            }
          }
        }
      } catch (_) {
        // skip this ticker
      }
    }
  }

  Future<void> addHolding({
    required String name,
    required String ticker,
    required String assetClass,
    required double quantity,
    required double avgBuyPrice,
    String? exchange,
    String? notes,
  }) async {
    final holding = HoldingModel(
      id: _uuid.v4(),
      name: name,
      ticker: ticker,
      assetClass: assetClass,
      quantity: quantity,
      avgBuyPrice: avgBuyPrice,
      exchange: exchange,
      notes: notes,
      createdAt: DateTime.now(),
    );
    await _db.insertHolding(holding.toMap());
    await loadHoldings();
  }

  Future<void> updateHolding(HoldingModel holding) async {
    await _db.updateHolding(holding.toMap());
    await loadHoldings();
  }

  Future<void> deleteHolding(String id) async {
    await _db.deleteHolding(id);
    _holdings.removeWhere((h) => h.id == id);
    notifyListeners();
  }
}
