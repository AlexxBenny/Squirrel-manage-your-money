import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background = Color(0xFF0D0F14);
  static const Color surface = Color(0xFF161B27);
  static const Color surface2 = Color(0xFF1E2536);
  static const Color surface3 = Color(0xFF252D42);

  // Brand
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF8F89FF);
  static const Color primaryDark = Color(0xFF4A42CC);

  // Semantic
  static const Color income = Color(0xFF00D9A3);
  static const Color expense = Color(0xFFFF4D6D);
  static const Color warning = Color(0xFFFFB800);
  static const Color info = Color(0xFF4DA6FF);

  // Text
  static const Color text1 = Color(0xFFF0F2FF);
  static const Color text2 = Color(0xFF8B92A9);
  static const Color text3 = Color(0xFF4A5168);

  // Border
  static const Color border = Color(0xFF2A3148);

  // Chart palette
  static const List<Color> chartPalette = [
    Color(0xFF6C63FF),
    Color(0xFF00D9A3),
    Color(0xFFFFB800),
    Color(0xFFFF4D6D),
    Color(0xFF4DA6FF),
    Color(0xFFFF6B9D),
    Color(0xFF9B59B6),
    Color(0xFF1ABC9C),
    Color(0xFFE67E22),
    Color(0xFF3498DB),
  ];

  // Category colors
  static const Map<String, Color> categoryColors = {
    'food': Color(0xFFFF6B6B),
    'transport': Color(0xFF4DA6FF),
    'shopping': Color(0xFFFFB800),
    'entertainment': Color(0xFF9B59B6),
    'health': Color(0xFF00D9A3),
    'housing': Color(0xFF6C63FF),
    'utilities': Color(0xFF1ABC9C),
    'education': Color(0xFFE67E22),
    'travel': Color(0xFF3498DB),
    'personal': Color(0xFFFF6B9D),
    'salary': Color(0xFF00D9A3),
    'freelance': Color(0xFF4DA6FF),
    'investment': Color(0xFF6C63FF),
    'gift': Color(0xFFFFB800),
    'other': Color(0xFF8B92A9),
  };
}
