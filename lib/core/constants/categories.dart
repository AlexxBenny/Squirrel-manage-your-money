import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppCategory {
  final String id;
  final String name;
  final String emoji;
  final Color color;
  final bool isIncome;

  const AppCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    this.isIncome = false,
  });
}

class Categories {
  Categories._();

  static const List<AppCategory> expense = [
    AppCategory(id: 'food', name: 'Food & Dining', emoji: '🍔', color: Color(0xFFFF6B6B)),
    AppCategory(id: 'transport', name: 'Transport', emoji: '🚗', color: Color(0xFF4DA6FF)),
    AppCategory(id: 'shopping', name: 'Shopping', emoji: '🛍️', color: Color(0xFFFFB800)),
    AppCategory(id: 'entertainment', name: 'Entertainment', emoji: '🎬', color: Color(0xFF9B59B6)),
    AppCategory(id: 'health', name: 'Health', emoji: '🏥', color: Color(0xFF00D9A3)),
    AppCategory(id: 'housing', name: 'Housing & Rent', emoji: '🏠', color: Color(0xFF6C63FF)),
    AppCategory(id: 'utilities', name: 'Utilities', emoji: '💡', color: Color(0xFF1ABC9C)),
    AppCategory(id: 'education', name: 'Education', emoji: '📚', color: Color(0xFFE67E22)),
    AppCategory(id: 'travel', name: 'Travel', emoji: '✈️', color: Color(0xFF3498DB)),
    AppCategory(id: 'personal', name: 'Personal Care', emoji: '💅', color: Color(0xFFFF6B9D)),
    AppCategory(id: 'subscriptions', name: 'Subscriptions', emoji: '📱', color: Color(0xFF8B92A9)),
    AppCategory(id: 'other_expense', name: 'Other', emoji: '💸', color: Color(0xFF8B92A9)),
  ];

  static const List<AppCategory> income = [
    AppCategory(id: 'salary', name: 'Salary', emoji: '💼', color: Color(0xFF00D9A3), isIncome: true),
    AppCategory(id: 'freelance', name: 'Freelance', emoji: '💻', color: Color(0xFF4DA6FF), isIncome: true),
    AppCategory(id: 'investment_return', name: 'Investment Return', emoji: '📈', color: Color(0xFF6C63FF), isIncome: true),
    AppCategory(id: 'gift', name: 'Gift', emoji: '🎁', color: Color(0xFFFFB800), isIncome: true),
    AppCategory(id: 'rental', name: 'Rental Income', emoji: '🏘️', color: Color(0xFF1ABC9C), isIncome: true),
    AppCategory(id: 'business', name: 'Business', emoji: '🏢', color: Color(0xFF9B59B6), isIncome: true),
    AppCategory(id: 'other_income', name: 'Other Income', emoji: '💰', color: Color(0xFF8B92A9), isIncome: true),
  ];

  static AppCategory? findById(String id) {
    try {
      return [...expense, ...income].firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  static Color colorFor(String categoryId) {
    return AppColors.categoryColors[categoryId] ?? AppColors.text2;
  }

  static String emojiFor(String categoryId) {
    return findById(categoryId)?.emoji ?? '💰';
  }
}

class AssetClasses {
  static const List<Map<String, dynamic>> all = [
    {'id': 'stock', 'name': 'Stocks', 'emoji': '📈', 'color': 0xFF6C63FF},
    {'id': 'crypto', 'name': 'Crypto', 'emoji': '🪙', 'color': 0xFFFFB800},
    {'id': 'mutual_fund', 'name': 'Mutual Funds', 'emoji': '📊', 'color': 0xFF00D9A3},
    {'id': 'gold', 'name': 'Gold', 'emoji': '🥇', 'color': 0xFFE67E22},
    {'id': 'fd', 'name': 'Fixed Deposit', 'emoji': '🏦', 'color': 0xFF4DA6FF},
    {'id': 'real_estate', 'name': 'Real Estate', 'emoji': '🏠', 'color': 0xFF9B59B6},
    {'id': 'other_asset', 'name': 'Other', 'emoji': '💼', 'color': 0xFF8B92A9},
  ];
}
