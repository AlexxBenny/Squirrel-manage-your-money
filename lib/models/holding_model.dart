import 'dart:convert';

/// The full rich HoldingModel. Asset-class-specific fields
/// are stored as JSON in [meta]; core financials are top-level
/// for quick aggregation without JSON parsing.
class HoldingModel {
  final String id;
  final String name;
  final String assetClass; // stock|crypto|mutual_fund|gold|fd|real_estate|other

  // Core financials — stored in DB columns for fast aggregation
  final double investedAmount;     // total cash put in
  final double? currentValueOverride; // manual override (FD maturity, RE estimate)

  // Market-linked assets
  final String? ticker;
  final String? exchange;
  final double? quantity;       // shares/units/grams
  final double? avgBuyPrice;    // per unit

  // Alert fields (indexed DB columns)
  final int? sipDay;            // 1–31, day of month for SIP
  final DateTime? maturityDate; // FD / SGB / Bond maturity
  final bool alertEnabled;

  // Asset-specific JSON blob (all fields not in core)
  final Map<String, dynamic> meta;

  // Runtime-only (not persisted)
  final double? currentPrice;
  final double? changePct;

  final DateTime createdAt;
  final String? notes;

  HoldingModel({
    required this.id,
    required this.name,
    required this.assetClass,
    required this.investedAmount,
    this.currentValueOverride,
    this.ticker,
    this.exchange,
    this.quantity,
    this.avgBuyPrice,
    this.sipDay,
    this.maturityDate,
    this.alertEnabled = true,
    this.meta = const {},
    this.currentPrice,
    this.changePct,
    required this.createdAt,
    this.notes,
  });

  // ── Computed values ────────────────────────────────────────────────────────

  double get currentValue {
    if (currentValueOverride != null) return currentValueOverride!;
    if (quantity != null && currentPrice != null) return quantity! * currentPrice!;
    if (quantity != null && avgBuyPrice != null) return quantity! * avgBuyPrice!;
    return investedAmount;
  }

  double get profitLoss => currentValue - investedAmount;
  double get profitLossPct =>
      investedAmount > 0 ? (profitLoss / investedAmount) * 100 : 0;
  bool get isProfit => profitLoss >= 0;

  String get assetClassName {
    const names = {
      'stock': 'Stocks', 'mutual_fund': 'Mutual Fund', 'crypto': 'Crypto',
      'gold': 'Gold', 'fd': 'Fixed Deposit', 'real_estate': 'Real Estate',
      'other_asset': 'Other',
    };
    return names[assetClass] ?? assetClass;
  }

  String get emoji {
    const emojis = {
      'stock': '📈', 'mutual_fund': '📊', 'crypto': '🪙',
      'gold': '🥇', 'fd': '🏛️', 'real_estate': '🏠', 'other_asset': '💼',
    };
    return emojis[assetClass] ?? '💼';
  }

  // ── Asset-specific meta accessors ─────────────────────────────────────────

  // Mutual Fund
  String? get mfFundHouse    => meta['fund_house'] as String?;
  String? get mfFolio        => meta['folio'] as String?;
  String? get mfPlan         => meta['plan'] as String?;         // 'direct'|'regular'
  String? get mfCategory     => meta['category'] as String?;
  String? get mfType         => meta['investment_type'] as String?; // 'sip'|'lumpsum'
  double? get mfSipAmount    => (meta['sip_amount'] as num?)?.toDouble();
  String? get mfSchemeCode   => meta['scheme_code'] as String?;
  double? get mfUnits        => (meta['units'] as num?)?.toDouble();
  double? get mfCurrentNav   => (meta['current_nav'] as num?)?.toDouble();
  bool   get mfIsELSS        => meta['is_elss'] as bool? ?? false;
  DateTime? get mfSipStart {
    final s = meta['sip_start'] as String?;
    return s != null ? DateTime.tryParse(s) : null;
  }

  // Fixed Deposit
  String? get fdBank          => meta['bank_name'] as String?;
  double? get fdPrincipal     => (meta['principal'] as num?)?.toDouble();
  double? get fdRate          => (meta['interest_rate'] as num?)?.toDouble();
  int?    get fdTenureMonths  => meta['tenure_months'] as int?;
  String? get fdCompounding   => meta['compounding'] as String?;
  String? get fdType          => meta['fd_type'] as String?;
  String? get fdInterestType  => meta['interest_type'] as String?;
  double? get fdMaturityAmount => (meta['maturity_amount'] as num?)?.toDouble();

  // Gold
  String? get goldType        => meta['gold_type'] as String?;
  String? get goldPurity      => meta['purity'] as String?;
  double? get goldGrams       => (meta['quantity_grams'] as num?)?.toDouble();
  double? get goldCurrentPricePerGram => (meta['current_price_per_gram'] as num?)?.toDouble();
  double? get sgbInterestRate => (meta['sgb_interest_rate'] as num?)?.toDouble();

  // Real Estate
  String? get rePropType      => meta['property_type'] as String?;
  String? get reLocation      => meta['location'] as String?;
  double? get reTotalCost     => (meta['total_cost'] as num?)?.toDouble();
  bool   get reHasLoan        => meta['has_loan'] as bool? ?? false;
  double? get reEmi           => (meta['emi_amount'] as num?)?.toDouble();
  int?   get reRemainingMonths => meta['remaining_months'] as int?;
  double? get reRentalIncome  => (meta['rental_income'] as num?)?.toDouble();

  // Other
  String? get otherInstrument => meta['instrument'] as String?;
  double? get otherBalance    => (meta['current_balance'] as num?)?.toDouble();

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'asset_class': assetClass,
    'invested_amount': investedAmount,
    'current_value_override': currentValueOverride,
    'ticker': ticker,
    'exchange': exchange,
    'quantity': quantity,
    'avg_buy_price': avgBuyPrice,
    'sip_day': sipDay,
    'maturity_date': maturityDate?.toIso8601String(),
    'alert_enabled': alertEnabled ? 1 : 0,
    'meta': meta.isEmpty ? null : json.encode(meta),
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
  };

  factory HoldingModel.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> metaMap = {};
    final metaStr = map['meta'] as String?;
    if (metaStr != null && metaStr.isNotEmpty) {
      try { metaMap = json.decode(metaStr) as Map<String, dynamic>; } catch (_) {}
    }
    return HoldingModel(
      id: map['id'] as String,
      name: map['name'] as String,
      assetClass: map['asset_class'] as String,
      investedAmount: (map['invested_amount'] as num?)?.toDouble() ??
          ((map['quantity'] as num?)?.toDouble() ?? 0) *
          ((map['avg_buy_price'] as num?)?.toDouble() ?? 0),
      currentValueOverride: (map['current_value_override'] as num?)?.toDouble(),
      ticker: map['ticker'] as String?,
      exchange: map['exchange'] as String?,
      quantity: (map['quantity'] as num?)?.toDouble(),
      avgBuyPrice: (map['avg_buy_price'] as num?)?.toDouble(),
      sipDay: map['sip_day'] as int?,
      maturityDate: map['maturity_date'] != null
          ? DateTime.tryParse(map['maturity_date'] as String)
          : null,
      alertEnabled: (map['alert_enabled'] as int? ?? 1) == 1,
      meta: metaMap,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  HoldingModel copyWith({
    double? currentPrice,
    double? changePct,
    double? currentValueOverride,
    Map<String, dynamic>? meta,
    int? reRemainingMonths,
  }) {
    final newMeta = meta ?? Map<String, dynamic>.from(this.meta);
    if (reRemainingMonths != null) newMeta['remaining_months'] = reRemainingMonths;
    return HoldingModel(
      id: id, name: name, assetClass: assetClass,
      investedAmount: investedAmount,
      currentValueOverride: currentValueOverride ?? this.currentValueOverride,
      ticker: ticker, exchange: exchange,
      quantity: quantity, avgBuyPrice: avgBuyPrice,
      sipDay: sipDay, maturityDate: maturityDate,
      alertEnabled: alertEnabled,
      meta: newMeta,
      currentPrice: currentPrice ?? this.currentPrice,
      changePct: changePct ?? this.changePct,
      createdAt: createdAt, notes: notes,
    );
  }
}

// ── Portfolio Alert ────────────────────────────────────────────────────────

enum AlertSeverity { info, warning, urgent }

class PortfolioAlert {
  final String holdingId;
  final String title;
  final String subtitle;
  final String emoji;
  final AlertSeverity severity;
  final DateTime dueDate;

  const PortfolioAlert({
    required this.holdingId,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.severity,
    required this.dueDate,
  });
}
