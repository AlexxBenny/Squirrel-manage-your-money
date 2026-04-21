class GoalModel {
  final String id;
  final String title;
  final String emoji;
  final String category; // retirement|house|car|education|vacation|emergency|other
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final List<String> linkedHoldingIds; // auto-sum from portfolio if set
  final String? notes;
  final DateTime createdAt;

  const GoalModel({
    required this.id,
    required this.title,
    required this.emoji,
    required this.category,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    this.linkedHoldingIds = const [],
    this.notes,
    required this.createdAt,
  });

  double get progressPct => targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0;
  bool   get isCompleted => currentAmount >= targetAmount;
  double get remaining   => (targetAmount - currentAmount).clamp(0, double.infinity);

  int? get daysLeft {
    if (targetDate == null) return null;
    return targetDate!.difference(DateTime.now()).inDays;
  }

  /// Monthly saving required to hit goal on time
  double? get monthlySavingNeeded {
    final days = daysLeft;
    if (days == null || days <= 0) return null;
    final months = days / 30.44;
    return months > 0 ? remaining / months : null;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'emoji': emoji,
    'category': category,
    'target_amount': targetAmount,
    'current_amount': currentAmount,
    'target_date': targetDate?.toIso8601String(),
    'linked_holding_ids': linkedHoldingIds.join(','),
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
  };

  factory GoalModel.fromMap(Map<String, dynamic> m) => GoalModel(
    id: m['id'] as String,
    title: m['title'] as String,
    emoji: m['emoji'] as String? ?? '🎯',
    category: m['category'] as String? ?? 'other',
    targetAmount: (m['target_amount'] as num).toDouble(),
    currentAmount: (m['current_amount'] as num? ?? 0).toDouble(),
    targetDate: m['target_date'] != null ? DateTime.tryParse(m['target_date'] as String) : null,
    linkedHoldingIds: (m['linked_holding_ids'] as String?)
        ?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
    notes: m['notes'] as String?,
    createdAt: DateTime.parse(m['created_at'] as String),
  );

  GoalModel copyWith({double? currentAmount, List<String>? linkedHoldingIds}) => GoalModel(
    id: id, title: title, emoji: emoji, category: category,
    targetAmount: targetAmount,
    currentAmount: currentAmount ?? this.currentAmount,
    targetDate: targetDate,
    linkedHoldingIds: linkedHoldingIds ?? this.linkedHoldingIds,
    notes: notes, createdAt: createdAt,
  );

  static const categories = [
    {'id': 'retirement',  'label': 'Retirement',     'emoji': '🏖️'},
    {'id': 'house',       'label': 'Buy a House',     'emoji': '🏠'},
    {'id': 'car',         'label': 'Buy a Car',       'emoji': '🚗'},
    {'id': 'education',   'label': 'Education',       'emoji': '🎓'},
    {'id': 'vacation',    'label': 'Vacation',        'emoji': '✈️'},
    {'id': 'emergency',   'label': 'Emergency Fund',  'emoji': '🛡️'},
    {'id': 'wedding',     'label': 'Wedding',         'emoji': '💍'},
    {'id': 'gadget',      'label': 'Gadget / Tech',   'emoji': '💻'},
    {'id': 'other',       'label': 'Other',           'emoji': '🎯'},
  ];
}
