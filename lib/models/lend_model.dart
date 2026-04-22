/// Represents a single lend or borrow record.
///
/// [type] is either 'lent' (you gave money) or 'borrowed' (you received money).
/// [status] is 'pending' or 'settled'.
class LendModel {
  final String id;
  final String type; // 'lent' | 'borrowed'
  final String personName;
  final double amount;
  final String currency;
  final DateTime date;
  final DateTime? dueDate;
  final String? note;
  final String status; // 'pending' | 'settled'
  final DateTime createdAt;

  const LendModel({
    required this.id,
    required this.type,
    required this.personName,
    required this.amount,
    this.currency = 'INR',
    required this.date,
    this.dueDate,
    this.note,
    this.status = 'pending',
    required this.createdAt,
  });

  bool get isLent => type == 'lent';
  bool get isBorrowed => type == 'borrowed';
  bool get isPending => status == 'pending';
  bool get isSettled => status == 'settled';

  bool get isOverdue {
    if (dueDate == null || isSettled) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'person_name': personName,
        'amount': amount,
        'currency': currency,
        'date': date.toIso8601String(),
        'due_date': dueDate?.toIso8601String(),
        'note': note,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };

  factory LendModel.fromMap(Map<String, dynamic> map) => LendModel(
        id: map['id'] as String,
        type: map['type'] as String,
        personName: map['person_name'] as String,
        amount: (map['amount'] as num).toDouble(),
        currency: map['currency'] as String? ?? 'INR',
        date: DateTime.parse(map['date'] as String),
        dueDate: map['due_date'] != null
            ? DateTime.parse(map['due_date'] as String)
            : null,
        note: map['note'] as String?,
        status: map['status'] as String? ?? 'pending',
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  LendModel copyWith({
    String? id,
    String? type,
    String? personName,
    double? amount,
    String? currency,
    DateTime? date,
    DateTime? dueDate,
    String? note,
    String? status,
    DateTime? createdAt,
  }) =>
      LendModel(
        id: id ?? this.id,
        type: type ?? this.type,
        personName: personName ?? this.personName,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        date: date ?? this.date,
        dueDate: dueDate ?? this.dueDate,
        note: note ?? this.note,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
      );
}
