import 'package:flutter/material.dart';

class CustomTagModel {
  final String id;
  final String name;
  final String emoji;
  final int colorValue; // stored as int (Color.value)
  final DateTime createdAt;

  const CustomTagModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorValue,
    required this.createdAt,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'color_value': colorValue,
    'created_at': createdAt.toIso8601String(),
  };

  factory CustomTagModel.fromMap(Map<String, dynamic> map) => CustomTagModel(
    id: map['id'] as String,
    name: map['name'] as String,
    emoji: map['emoji'] as String? ?? '🏷️',
    colorValue: map['color_value'] as int? ?? 0xFF2563EB,
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  // Parse tag IDs from comma-separated transaction.tags string
  static List<String> parseIds(String? tags) {
    if (tags == null || tags.isEmpty) return [];
    return tags.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  // Serialize list of tag IDs to comma-separated string
  static String serializeIds(List<String> ids) => ids.join(',');
}
