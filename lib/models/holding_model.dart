class HoldingModel {
  final String id;
  final String name;
  final String ticker;
  final String assetClass; // 'stock' | 'crypto' | 'mutual_fund' | 'gold' | 'fd'
  final double quantity;
  final double avgBuyPrice;
  final String currency;
  final String? exchange;
  final String? notes;
  final DateTime createdAt;

  // Live data (not stored in DB, fetched at runtime)
  final double? currentPrice;
  final double? changePct;

  const HoldingModel({
    required this.id,
    required this.name,
    required this.ticker,
    required this.assetClass,
    required this.quantity,
    required this.avgBuyPrice,
    this.currency = 'INR',
    this.exchange,
    this.notes,
    required this.createdAt,
    this.currentPrice,
    this.changePct,
  });

  double get investedValue => quantity * avgBuyPrice;
  double get currentValue => quantity * (currentPrice ?? avgBuyPrice);
  double get profitLoss => currentValue - investedValue;
  double get profitLossPct => investedValue > 0 ? (profitLoss / investedValue) * 100 : 0;
  bool get isProfit => profitLoss >= 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'ticker': ticker,
      'asset_class': assetClass,
      'quantity': quantity,
      'avg_buy_price': avgBuyPrice,
      'currency': currency,
      'exchange': exchange,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory HoldingModel.fromMap(Map<String, dynamic> map) {
    return HoldingModel(
      id: map['id'] as String,
      name: map['name'] as String,
      ticker: map['ticker'] as String,
      assetClass: map['asset_class'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      avgBuyPrice: (map['avg_buy_price'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'INR',
      exchange: map['exchange'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  HoldingModel copyWith({
    String? id,
    String? name,
    String? ticker,
    String? assetClass,
    double? quantity,
    double? avgBuyPrice,
    String? currency,
    String? exchange,
    String? notes,
    DateTime? createdAt,
    double? currentPrice,
    double? changePct,
  }) {
    return HoldingModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ticker: ticker ?? this.ticker,
      assetClass: assetClass ?? this.assetClass,
      quantity: quantity ?? this.quantity,
      avgBuyPrice: avgBuyPrice ?? this.avgBuyPrice,
      currency: currency ?? this.currency,
      exchange: exchange ?? this.exchange,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      currentPrice: currentPrice ?? this.currentPrice,
      changePct: changePct ?? this.changePct,
    );
  }
}
