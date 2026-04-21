class TransactionModel {
  final String id;
  final String type; // 'income' | 'expense'
  final double amount;
  final String currency;
  final String category;
  final String? note;
  final DateTime date;
  final String? tags;
  final bool isRecurring;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    this.currency = 'INR',
    required this.category,
    this.note,
    required this.date,
    this.tags,
    this.isRecurring = false,
    required this.createdAt,
  });

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'currency': currency,
      'category': category,
      'note': note,
      'date': date.toIso8601String(),
      'tags': tags,
      'is_recurring': isRecurring ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'INR',
      category: map['category'] as String,
      note: map['note'] as String?,
      date: DateTime.parse(map['date'] as String),
      tags: map['tags'] as String?,
      isRecurring: (map['is_recurring'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  TransactionModel copyWith({
    String? id,
    String? type,
    double? amount,
    String? currency,
    String? category,
    String? note,
    DateTime? date,
    String? tags,
    bool? isRecurring,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      category: category ?? this.category,
      note: note ?? this.note,
      date: date ?? this.date,
      tags: tags ?? this.tags,
      isRecurring: isRecurring ?? this.isRecurring,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
