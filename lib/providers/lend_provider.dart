import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/database/database_helper.dart';
import '../models/lend_model.dart';

class LendProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  final _uuid = const Uuid();

  List<LendModel> _lendings = [];
  bool _isLoading = false;
  String? _error;

  List<LendModel> get lendings => _lendings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Filtered views ─────────────────────────────────────────────────────────

  List<LendModel> get pending =>
      _lendings.where((l) => l.isPending).toList();

  List<LendModel> get settled =>
      _lendings.where((l) => l.isSettled).toList();

  List<LendModel> get lentOut =>
      _lendings.where((l) => l.isLent && l.isPending).toList();

  List<LendModel> get borrowed =>
      _lendings.where((l) => l.isBorrowed && l.isPending).toList();

  List<LendModel> get overdue =>
      _lendings.where((l) => l.isOverdue).toList();

  // ── Summary amounts ────────────────────────────────────────────────────────

  double get totalLentOut =>
      lentOut.fold(0.0, (s, l) => s + l.amount);

  double get totalBorrowed =>
      borrowed.fold(0.0, (s, l) => s + l.amount);

  /// Net position: positive = others owe you, negative = you owe others
  double get netPosition => totalLentOut - totalBorrowed;

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<void> loadLendings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final maps = await _db.getLendings();
      _lendings = maps.map(LendModel.fromMap).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addLending({
    required String type,
    required String personName,
    required double amount,
    required DateTime date,
    DateTime? dueDate,
    String? note,
  }) async {
    final lending = LendModel(
      id: _uuid.v4(),
      type: type,
      personName: personName,
      amount: amount,
      date: date,
      dueDate: dueDate,
      note: note,
      createdAt: DateTime.now(),
    );
    await _db.insertLending(lending.toMap());
    await loadLendings();
  }

  Future<void> updateLending(LendModel lending) async {
    await _db.updateLending(lending.toMap());
    await loadLendings();
  }

  Future<void> markSettled(String id) async {
    final existing = _lendings.firstWhere((l) => l.id == id);
    final updated = existing.copyWith(status: 'settled');
    await _db.updateLending(updated.toMap());
    await loadLendings();
  }

  Future<void> markPending(String id) async {
    final existing = _lendings.firstWhere((l) => l.id == id);
    final updated = existing.copyWith(status: 'pending');
    await _db.updateLending(updated.toMap());
    await loadLendings();
  }

  Future<void> deleteLending(String id) async {
    await _db.deleteLending(id);
    _lendings.removeWhere((l) => l.id == id);
    notifyListeners();
  }
}
