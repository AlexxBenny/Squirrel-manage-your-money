import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/database/database_helper.dart';
import '../models/custom_tag_model.dart';
import '../models/transaction_model.dart';

class TagProvider extends ChangeNotifier {
  List<CustomTagModel> _tags = [];
  Map<String, double> _tagTotals = {};
  bool _isLoading = false;

  List<CustomTagModel> get tags => _tags;
  Map<String, double> get tagTotals => _tagTotals;
  bool get isLoading => _isLoading;

  Future<void> loadTags() async {
    _isLoading = true;
    notifyListeners();
    final maps = await DatabaseHelper.instance.getTags();
    _tags = maps.map(CustomTagModel.fromMap).toList();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTagTotals({DateTime? from, DateTime? to}) async {
    _tagTotals = await DatabaseHelper.instance.getTagTotals(from: from, to: to);
    notifyListeners();
  }

  Future<CustomTagModel> createTag({
    required String name,
    required String emoji,
    required Color color,
  }) async {
    final tag = CustomTagModel(
      id: const Uuid().v4(),
      name: name.trim(),
      emoji: emoji,
      colorValue: color.value,
      createdAt: DateTime.now(),
    );
    await DatabaseHelper.instance.insertTag(tag.toMap());
    _tags.add(tag);
    notifyListeners();
    return tag;
  }

  Future<void> deleteTag(String id) async {
    await DatabaseHelper.instance.deleteTag(id);
    _tags.removeWhere((t) => t.id == id);
    _tagTotals.remove(id);
    notifyListeners();
  }

  /// Returns tags attached to a transaction
  List<CustomTagModel> tagsForTransaction(TransactionModel tx) {
    final ids = CustomTagModel.parseIds(tx.tags);
    return _tags.where((t) => ids.contains(t.id)).toList();
  }

  /// Returns tag by ID (null if not found)
  CustomTagModel? findById(String id) {
    try { return _tags.firstWhere((t) => t.id == id); }
    catch (_) { return null; }
  }

  /// Sorted tag spending for analytics — highest first
  List<MapEntry<CustomTagModel, double>> get sortedTagSpending {
    final result = <MapEntry<CustomTagModel, double>>[];
    for (final entry in _tagTotals.entries) {
      final tag = findById(entry.key);
      if (tag != null) result.add(MapEntry(tag, entry.value));
    }
    result.sort((a, b) => b.value.compareTo(a.value));
    return result;
  }
}
