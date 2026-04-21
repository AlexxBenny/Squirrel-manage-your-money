import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/categories.dart';
import '../core/database/database_helper.dart';

class CategoryProvider extends ChangeNotifier {
  List<AppCategory> _custom = [];
  bool _isLoading = false;

  List<AppCategory> get customCategories => _custom;
  bool get isLoading => _isLoading;

  List<AppCategory> get allExpense => [
    ...Categories.expense,
    ..._custom.where((c) => !c.isIncome),
  ];

  List<AppCategory> get allIncome => [
    ...Categories.income,
    ..._custom.where((c) => c.isIncome),
  ];

  List<AppCategory> categoriesForType(String type) =>
      type == 'income' ? allIncome : allExpense;

  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();
    final maps = await DatabaseHelper.instance.getCustomCategories();
    _custom = maps.map(AppCategory.fromMap).toList();
    // Register globally so Categories.findById() resolves custom IDs everywhere
    Categories.setCustom(_custom);
    _isLoading = false;
    notifyListeners();
  }

  Future<AppCategory> createCategory({
    required String name,
    required String emoji,
    required Color color,
    required bool isIncome,
  }) async {
    final id = 'custom_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${const Uuid().v4().substring(0, 6)}';
    final map = {
      'id': id,
      'name': name.trim(),
      'emoji': emoji,
      'color_value': color.value,
      'is_income': isIncome ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    };
    await DatabaseHelper.instance.insertCategory(map);
    final cat = AppCategory.fromMap(map);
    _custom.add(cat);
    Categories.setCustom(_custom);
    notifyListeners();
    return cat;
  }

  Future<void> deleteCategory(String id) async {
    await DatabaseHelper.instance.deleteCategory(id);
    _custom.removeWhere((c) => c.id == id);
    Categories.setCustom(_custom);
    notifyListeners();
  }
}
