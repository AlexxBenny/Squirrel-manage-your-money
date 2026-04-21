import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Primary Blue Palette ───────────────────────────────────────────────────
  static const Color primary        = Color(0xFF2563EB); // Electric blue
  static const Color primaryDark    = Color(0xFF1D4ED8);
  static const Color primaryLight   = Color(0xFF60A5FA);
  static const Color primarySurface = Color(0xFFEFF6FF); // Lightest blue tint

  // ─── Gradient ────────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF1A3A8F), Color(0xFF2563EB), Color(0xFF60A5FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient incomeGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient expenseGradient = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  // ─── Semantic ─────────────────────────────────────────────────────────────
  static const Color income  = Color(0xFF10B981); // Emerald green
  static const Color expense = Color(0xFFEF4444); // Red
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color info    = Color(0xFF06B6D4); // Cyan

  // ─── Background & Surface ─────────────────────────────────────────────────
  static const Color background = Color(0xFFF8FAFC); // Very light blue-grey
  static const Color surface    = Color(0xFFFFFFFF); // Pure white
  static const Color surface2   = Color(0xFFF1F5F9); // Light grey
  static const Color surface3   = Color(0xFFE2E8F0); // Border grey

  // ─── Text ─────────────────────────────────────────────────────────────────
  static const Color text1  = Color(0xFF0F172A); // Near black (slate-900)
  static const Color text2  = Color(0xFF475569); // Grey (slate-600)
  static const Color text3  = Color(0xFF94A3B8); // Light grey (slate-400)
  static const Color border = Color(0xFFE2E8F0); // Slate-200

  // ─── Chart Palette ────────────────────────────────────────────────────────
  static const List<Color> chartPalette = [
    Color(0xFF2563EB),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
    Color(0xFF6366F1),
  ];

  // ─── Category Colors ──────────────────────────────────────────────────────
  static const Map<String, Color> categoryColors = {
    'food':            Color(0xFFF97316),
    'transport':       Color(0xFF2563EB),
    'shopping':        Color(0xFF8B5CF6),
    'entertainment':   Color(0xFFEC4899),
    'health':          Color(0xFF10B981),
    'housing':         Color(0xFF6366F1),
    'utilities':       Color(0xFF06B6D4),
    'education':       Color(0xFFF59E0B),
    'travel':          Color(0xFF14B8A6),
    'personal':        Color(0xFFEF4444),
    'subscriptions':   Color(0xFF64748B),
    'salary':          Color(0xFF10B981),
    'freelance':       Color(0xFF2563EB),
    'investment_return': Color(0xFF8B5CF6),
    'gift':            Color(0xFFF59E0B),
    'rental':          Color(0xFF06B6D4),
    'business':        Color(0xFF6366F1),
    'other_expense':   Color(0xFF94A3B8),
    'other_income':    Color(0xFF94A3B8),
  };
}
