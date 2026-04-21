import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/database/database_helper.dart';
import '../models/transaction_model.dart';
import '../core/utils/date_helpers.dart';

class TransactionProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  final _uuid = const Uuid();

  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _error;

  DateTime _selectedMonth = DateTime.now();

  List<TransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime get selectedMonth => _selectedMonth;

  List<TransactionModel> get expenses =>
      _transactions.where((t) => t.isExpense).toList();
  List<TransactionModel> get incomes =>
      _transactions.where((t) => t.isIncome).toList();

  double get totalExpenses => expenses.fold(0, (s, t) => s + t.amount);
  double get totalIncome => incomes.fold(0, (s, t) => s + t.amount);
  double get netSavings => totalIncome - totalExpenses;
  double get savingsRate => totalIncome > 0 ? (netSavings / totalIncome) * 100 : 0;

  Map<String, double> get expenseByCategory {
    final map = <String, double>{};
    for (final t in expenses) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map;
  }

  Future<void> loadTransactions({DateTime? month}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final targetMonth = month ?? _selectedMonth;
      _selectedMonth = targetMonth;
      final from = DateHelpers.startOfMonth(targetMonth);
      final to = DateHelpers.endOfMonth(targetMonth);

      final maps = await _db.getTransactions(from: from, to: to);
      _transactions = maps.map(TransactionModel.fromMap).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<TransactionModel>> getRecentTransactions({int limit = 20}) async {
    final maps = await _db.getTransactions(limit: limit);
    return maps.map(TransactionModel.fromMap).toList();
  }

  Future<void> addTransaction({
    required String type,
    required double amount,
    required String category,
    required DateTime date,
    String? note,
    String? tags,
    bool isRecurring = false,
  }) async {
    final tx = TransactionModel(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      category: category,
      note: note,
      date: date,
      tags: tags,
      isRecurring: isRecurring,
      createdAt: DateTime.now(),
    );
    await _db.insertTransaction(tx.toMap());
    await loadTransactions();
  }

  Future<void> updateTransaction(TransactionModel tx) async {
    await _db.updateTransaction(tx.toMap());
    await loadTransactions();
  }

  Future<void> deleteTransaction(String id) async {
    await _db.deleteTransaction(id);
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  /// FIX #8: Single grouped SQL query replaces 24 sequential DB round-trips.
  Future<Map<String, List<double>>> getMonthlyTrend() async {
    final months = DateHelpers.last12Months();
    final from   = DateHelpers.startOfMonth(months.first);
    // One query returns all months at once, grouped by month+type
    final raw = await _db.getMonthlyTotals(from: from);
    final incomeData  = <double>[];
    final expenseData = <double>[];
    for (final month in months) {
      final key  = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      final data = raw[key] ?? {};
      incomeData.add(data['income']  ?? 0);
      expenseData.add(data['expense'] ?? 0);
    }
    return {'income': incomeData, 'expense': expenseData};
  }

  Future<List<TransactionModel>> searchTransactions(String query) async {
    final all = await _db.getTransactions();
    final q = query.toLowerCase();
    return all
        .map(TransactionModel.fromMap)
        .where((t) =>
            (t.note?.toLowerCase().contains(q) ?? false) ||
            t.category.toLowerCase().contains(q))
        .toList();
  }

  Future<List<TransactionModel>> getAnomalies() async {
    // Flag transactions > 2× average for their category this month
    final anomalies = <TransactionModel>[];
    final byCategory = <String, List<double>>{};

    for (final t in expenses) {
      byCategory.putIfAbsent(t.category, () => []).add(t.amount);
    }

    for (final t in expenses) {
      final amounts = byCategory[t.category]!;
      if (amounts.length < 2) continue;
      final avg = amounts.fold(0.0, (s, a) => s + a) / amounts.length;
      if (t.amount > avg * 2.5) anomalies.add(t);
    }
    return anomalies;
  }

  void changeMonth(DateTime month) {
    loadTransactions(month: month);
  }
}
