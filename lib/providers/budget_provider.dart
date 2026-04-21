import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/database/database_helper.dart';
import '../models/budget_model.dart';
import '../models/transaction_model.dart';
import '../core/utils/date_helpers.dart';

class BudgetProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  final _uuid = const Uuid();

  List<BudgetModel> _budgets = [];
  List<BudgetStatus> _statuses = [];
  bool _isLoading = false;
  String _period = 'monthly';

  List<BudgetModel> get budgets => _budgets;
  List<BudgetStatus> get statuses => _statuses;
  bool get isLoading => _isLoading;
  String get period => _period;

  List<BudgetStatus> get overBudget =>
      _statuses.where((s) => s.isOver).toList();
  List<BudgetStatus> get nearLimit =>
      _statuses.where((s) => s.isWarning).toList();

  Future<void> loadBudgets({List<TransactionModel>? transactions}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final maps = await _db.getBudgets();
      _budgets = maps.map(BudgetModel.fromMap).toList();

      if (transactions != null) {
        await _computeStatuses(transactions);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _computeStatuses(List<TransactionModel> transactions) async {
    final now = DateTime.now();
    DateTime from, to;

    if (_period == 'weekly') {
      from = DateHelpers.startOfWeek(now);
      to = DateHelpers.endOfWeek(now);
    } else {
      from = DateHelpers.startOfMonth(now);
      to = DateHelpers.endOfMonth(now);
    }

    _statuses = _budgets.map((budget) {
      final spent = transactions
          .where((t) =>
              t.isExpense &&
              t.category == budget.category &&
              t.date.isAfter(from.subtract(const Duration(seconds: 1))) &&
              t.date.isBefore(to.add(const Duration(seconds: 1))))
          .fold(0.0, (s, t) => s + t.amount);
      return BudgetStatus(budget: budget, spent: spent);
    }).toList();
  }

  Future<void> refreshStatuses(List<TransactionModel> transactions) async {
    await _computeStatuses(transactions);
    notifyListeners();
  }

  Future<void> upsertBudget({
    String? id,
    required String category,
    required double limitAmount,
    String period = 'monthly',
    double alertAt = 0.8,
  }) async {
    final budget = BudgetModel(
      id: id ?? _uuid.v4(),
      category: category,
      limitAmount: limitAmount,
      period: period,
      alertAt: alertAt,
    );
    await _db.upsertBudget(budget.toMap());
    await loadBudgets();
  }

  Future<void> deleteBudget(String id) async {
    await _db.deleteBudget(id);
    _budgets.removeWhere((b) => b.id == id);
    _statuses.removeWhere((s) => s.budget.id == id);
    notifyListeners();
  }

  void setPeriod(String p) {
    _period = p;
    notifyListeners();
  }

  BudgetStatus? statusForCategory(String category) {
    try {
      return _statuses.firstWhere((s) => s.budget.category == category);
    } catch (_) {
      return null;
    }
  }

  double spentForCategory(String category, List<TransactionModel> transactions) {
    final now = DateTime.now();
    final from = _period == 'weekly'
        ? DateHelpers.startOfWeek(now)
        : DateHelpers.startOfMonth(now);
    final to = _period == 'weekly'
        ? DateHelpers.endOfWeek(now)
        : DateHelpers.endOfMonth(now);

    return transactions
        .where((t) =>
            t.isExpense &&
            t.category == category &&
            t.date.isAfter(from) &&
            t.date.isBefore(to))
        .fold(0.0, (s, t) => s + t.amount);
  }
}
