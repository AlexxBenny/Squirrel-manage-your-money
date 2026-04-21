class ReminderModel {
  final String id;
  final String title;
  final String? description;
  final DateTime dueDate;
  final String repeat; // 'none' | 'monthly' | 'yearly'
  final bool isDone;
  final String category; // 'bill' | 'tax' | 'custom'
  final double? amount;

  const ReminderModel({
    required this.id,
    required this.title,
    this.description,
    required this.dueDate,
    this.repeat = 'none',
    this.isDone = false,
    this.category = 'custom',
    this.amount,
  });

  bool get isOverdue => !isDone && dueDate.isBefore(DateTime.now());
  bool get isDueSoon {
    final diff = dueDate.difference(DateTime.now()).inDays;
    return !isDone && diff >= 0 && diff <= 7;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'due_date': dueDate.toIso8601String(),
      'repeat': repeat,
      'is_done': isDone ? 1 : 0,
      'category': category,
      'amount': amount,
    };
  }

  factory ReminderModel.fromMap(Map<String, dynamic> map) {
    return ReminderModel(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      dueDate: DateTime.parse(map['due_date'] as String),
      repeat: map['repeat'] as String? ?? 'none',
      isDone: (map['is_done'] as int? ?? 0) == 1,
      category: map['category'] as String? ?? 'custom',
      amount: (map['amount'] as num?)?.toDouble(),
    );
  }

  ReminderModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    String? repeat,
    bool? isDone,
    String? category,
    double? amount,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      repeat: repeat ?? this.repeat,
      isDone: isDone ?? this.isDone,
      category: category ?? this.category,
      amount: amount ?? this.amount,
    );
  }
}
