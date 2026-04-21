import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppCategory {
  final String id;
  final String name;
  final String emoji;
  final Color color;
  final bool isIncome;
  final bool isCustom;

  const AppCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    this.isIncome = false,
    this.isCustom = false,
  });

  factory AppCategory.fromMap(Map<String, dynamic> map) => AppCategory(
    id: map['id'] as String,
    name: map['name'] as String,
    emoji: map['emoji'] as String? ?? '💸',
    color: Color(map['color_value'] as int? ?? 0xFF8B92A9),
    isIncome: (map['is_income'] as int? ?? 0) == 1,
    isCustom: true,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'color_value': color.value,
    'is_income': isIncome ? 1 : 0,
  };
}

class Categories {
  Categories._();

  // ── Custom category registry (populated by CategoryProvider on load) ────
  static List<AppCategory> _custom = [];
  static void setCustom(List<AppCategory> cats) { _custom = cats; }
  static List<AppCategory> get custom => _custom;

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
      return [...expense, ...income, ..._custom].firstWhere((c) => c.id == id);
    } catch (_) { return null; }
  }

  static Color colorFor(String categoryId) =>
      findById(categoryId)?.color ?? AppColors.text2;

  static String emojiFor(String categoryId) =>
      findById(categoryId)?.emoji ?? '💰';
}

class AssetClasses {
  static const List<Map<String, dynamic>> all = [
    {
      'id': 'stock', 'name': 'Stocks', 'emoji': '📈', 'color': 0xFF6C63FF,
      'desc': 'Equity shares on NSE/BSE', 'risk': 'market_linked',
    },
    {
      'id': 'mutual_fund', 'name': 'Mutual Fund', 'emoji': '📊', 'color': 0xFF00D9A3,
      'desc': 'SIP or lump sum in any AMC', 'risk': 'market_linked',
    },
    {
      'id': 'crypto', 'name': 'Crypto', 'emoji': '🪙', 'color': 0xFFFFB800,
      'desc': 'Bitcoin, ETH, altcoins', 'risk': 'market_linked',
    },
    {
      'id': 'gold', 'name': 'Gold', 'emoji': '🥇', 'color': 0xFFE67E22,
      'desc': 'Physical, SGB, ETF, Digital', 'risk': 'market_linked',
    },
    {
      'id': 'fd', 'name': 'Fixed Deposit', 'emoji': '🏛️', 'color': 0xFF4DA6FF,
      'desc': 'Bank FD, corporate FD, SCSS', 'risk': 'fixed_income',
    },
    {
      'id': 'real_estate', 'name': 'Real Estate', 'emoji': '🏠', 'color': 0xFF9B59B6,
      'desc': 'Property, REIT', 'risk': 'fixed_income',
    },
    {
      'id': 'other_asset', 'name': 'Other', 'emoji': '💼', 'color': 0xFF8B92A9,
      'desc': 'PPF, NPS, EPF, Bonds, P2P', 'risk': 'fixed_income',
    },
  ];

  static Map<String, dynamic>? findById(String id) {
    try { return all.firstWhere((a) => a['id'] == id); } catch (_) { return null; }
  }

  static String emojiFor(String id) => findById(id)?['emoji'] as String? ?? '💼';
  static String nameFor(String id)  => findById(id)?['name']  as String? ?? id;
  static int    colorFor(String id) => findById(id)?['color'] as int?    ?? 0xFF8B92A9;
  static bool   isMarketLinked(String id) => findById(id)?['risk'] == 'market_linked';
}
