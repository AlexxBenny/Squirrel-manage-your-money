class BudgetModel {
  final String id;
  final String category;
  final double limitAmount;
  final String period; // 'weekly' | 'monthly'
  final double alertAt; // fraction: 0.8 = alert at 80%

  const BudgetModel({
    required this.id,
    required this.category,
    required this.limitAmount,
    this.period = 'monthly',
    this.alertAt = 0.8,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'limit_amount': limitAmount,
      'period': period,
      'alert_at': alertAt,
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'] as String,
      category: map['category'] as String,
      limitAmount: (map['limit_amount'] as num).toDouble(),
      period: map['period'] as String? ?? 'monthly',
      alertAt: (map['alert_at'] as num?)?.toDouble() ?? 0.8,
    );
  }

  BudgetModel copyWith({
    String? id,
    String? category,
    double? limitAmount,
    String? period,
    double? alertAt,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      category: category ?? this.category,
      limitAmount: limitAmount ?? this.limitAmount,
      period: period ?? this.period,
      alertAt: alertAt ?? this.alertAt,
    );
  }
}

class BudgetStatus {
  final BudgetModel budget;
  final double spent;

  const BudgetStatus({required this.budget, required this.spent});

  double get usageRatio => spent / budget.limitAmount;
  double get remaining => (budget.limitAmount - spent).clamp(0, double.infinity);
  bool get isOver => spent > budget.limitAmount;
  bool get isWarning => usageRatio >= budget.alertAt && !isOver;
  bool get isSafe => usageRatio < budget.alertAt;
}
