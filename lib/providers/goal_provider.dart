import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/database/database_helper.dart';
import '../models/goal_model.dart';
import '../models/holding_model.dart';

class GoalProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  List<GoalModel> _goals = [];
  bool _loading = false;

  List<GoalModel> get goals => _goals;
  bool get isLoading => _loading;

  double totalTargeted(List<HoldingModel> holdings) =>
      _goals.fold(0, (s, g) => s + g.targetAmount);

  double totalSaved(List<HoldingModel> holdings) =>
      _goals.fold(0, (s, g) => s + _effectiveSaved(g, holdings));

  double _effectiveSaved(GoalModel g, List<HoldingModel> holdings) {
    if (g.linkedHoldingIds.isEmpty) return g.currentAmount;
    final linked = holdings.where((h) => g.linkedHoldingIds.contains(h.id));
    final portfolioValue = linked.fold(0.0, (s, h) => s + h.currentValue);
    return portfolioValue + g.currentAmount;
  }

  /// Public — used by GoalsScreen to build display-copy of goal
  double effectiveSaved(GoalModel g, List<HoldingModel> holdings) =>
      _effectiveSaved(g, holdings);

  /// Portfolio-only portion (excludes manual top-ups)
  double portfolioContribution(GoalModel g, List<HoldingModel> holdings) {
    if (g.linkedHoldingIds.isEmpty) return 0;
    final linked = holdings.where((h) => g.linkedHoldingIds.contains(h.id));
    return linked.fold(0.0, (s, h) => s + h.currentValue);
  }

  Future<void> loadGoals() async {
    _loading = true;
    notifyListeners();
    final maps = await _db.getGoals();
    _goals = maps.map(GoalModel.fromMap).toList();
    _loading = false;
    notifyListeners();
  }

  Future<void> addGoal(GoalModel g) async {
    await _db.insertGoal(g.toMap());
    await loadGoals();
  }

  Future<void> updateGoal(GoalModel g) async {
    await _db.updateGoal(g.toMap());
    await loadGoals();
  }

  Future<void> topUp(String id, double amount, List<HoldingModel> holdings) async {
    final g = _goals.firstWhere((x) => x.id == id);
    await _db.updateGoal(g.copyWith(currentAmount: g.currentAmount + amount).toMap());
    await loadGoals();
  }

  Future<void> deleteGoal(String id) async {
    await _db.deleteGoal(id);
    _goals.removeWhere((g) => g.id == id);
    notifyListeners();
  }

  String newId() => const Uuid().v4();

  GoalModel? goalWithEffectiveSaved(String id, List<HoldingModel> holdings) {
    final g = _goals.where((x) => x.id == id).firstOrNull;
    if (g == null) return null;
    return g.copyWith(currentAmount: _effectiveSaved(g, holdings));
  }
}
