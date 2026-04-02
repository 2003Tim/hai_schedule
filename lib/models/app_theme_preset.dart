import 'package:flutter/material.dart';

class AppThemePreset {
  final String id;
  final String name;
  final String emoji;
  final Color primaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final Color cardColor;
  final Color textColor;
  final Color subtextColor;
  final Brightness brightness;
  final List<Color> courseColors;

  const AppThemePreset({
    required this.id,
    required this.name,
    required this.emoji,
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.cardColor,
    required this.textColor,
    required this.subtextColor,
    required this.brightness,
    required this.courseColors,
  });
}

class AppThemes {
  const AppThemes._();

  static const presets = <AppThemePreset>[
    AppThemePreset(
      id: 'blue',
      name: '清新蓝',
      emoji: '🌊',
      primaryColor: Color(0xFF2563EB),
      accentColor: Color(0xFF3B82F6),
      backgroundColor: Color(0xFFF0F5FF),
      cardColor: Color(0xFFFFFFFF),
      textColor: Color(0xFF0F172A),
      subtextColor: Color(0xFF64748B),
      brightness: Brightness.light,
      courseColors: [
        Color(0xFF5B8FF9),
        Color(0xFF43C59E),
        Color(0xFFFF8C6B),
        Color(0xFFE8684A),
        Color(0xFF9270CA),
        Color(0xFF47B8E0),
        Color(0xFFF06292),
        Color(0xFF81C784),
        Color(0xFFFFB74D),
        Color(0xFF7986CB),
      ],
    ),
    AppThemePreset(
      id: 'pink',
      name: '樱花粉',
      emoji: '🌸',
      primaryColor: Color(0xFFE91E63),
      accentColor: Color(0xFFF48FB1),
      backgroundColor: Color(0xFFFFF0F3),
      cardColor: Color(0xFFFFFFFF),
      textColor: Color(0xFF37474F),
      subtextColor: Color(0xFF78909C),
      brightness: Brightness.light,
      courseColors: [
        Color(0xFFF48FB1),
        Color(0xFFCE93D8),
        Color(0xFF90CAF9),
        Color(0xFFA5D6A7),
        Color(0xFFFFCC80),
        Color(0xFFEF9A9A),
        Color(0xFF80DEEA),
        Color(0xFFE6EE9C),
        Color(0xFFFFAB91),
        Color(0xFFB39DDB),
      ],
    ),
    AppThemePreset(
      id: 'green',
      name: '森林绿',
      emoji: '🌿',
      primaryColor: Color(0xFF2E7D32),
      accentColor: Color(0xFF66BB6A),
      backgroundColor: Color(0xFFF1F8E9),
      cardColor: Color(0xFFFFFFFF),
      textColor: Color(0xFF1B5E20),
      subtextColor: Color(0xFF558B2F),
      brightness: Brightness.light,
      courseColors: [
        Color(0xFF66BB6A),
        Color(0xFF42A5F5),
        Color(0xFFFFCA28),
        Color(0xFFEF5350),
        Color(0xFF7E57C2),
        Color(0xFF26C6DA),
        Color(0xFFFF7043),
        Color(0xFF8D6E63),
        Color(0xFF78909C),
        Color(0xFFD4E157),
      ],
    ),
    AppThemePreset(
      id: 'purple',
      name: '暗夜紫',
      emoji: '🌙',
      primaryColor: Color(0xFF7C3AED),
      accentColor: Color(0xFFA78BFA),
      backgroundColor: Color(0xFF1E1B2E),
      cardColor: Color(0xFF2D2A3E),
      textColor: Color(0xFFE8E0F0),
      subtextColor: Color(0xFF9D93B0),
      brightness: Brightness.dark,
      courseColors: [
        Color(0xFFA78BFA),
        Color(0xFF60A5FA),
        Color(0xFF34D399),
        Color(0xFFFBBF24),
        Color(0xFFF87171),
        Color(0xFF38BDF8),
        Color(0xFFFB923C),
        Color(0xFF4ADE80),
        Color(0xFFF472B6),
        Color(0xFF818CF8),
      ],
    ),
    AppThemePreset(
      id: 'white',
      name: '纯净白',
      emoji: '☁️',
      primaryColor: Color(0xFF1F2937),
      accentColor: Color(0xFF6B7280),
      backgroundColor: Color(0xFFFFFFFF),
      cardColor: Color(0xFFF9FAFB),
      textColor: Color(0xFF111827),
      subtextColor: Color(0xFF6B7280),
      brightness: Brightness.light,
      courseColors: [
        Color(0xFF6366F1),
        Color(0xFF14B8A6),
        Color(0xFFF59E0B),
        Color(0xFFEF4444),
        Color(0xFF8B5CF6),
        Color(0xFF06B6D4),
        Color(0xFFF97316),
        Color(0xFF22C55E),
        Color(0xFFEC4899),
        Color(0xFF3B82F6),
      ],
    ),
    AppThemePreset(
      id: 'dark',
      name: '深色模式',
      emoji: '🌌',
      primaryColor: Color(0xFF60A5FA),
      accentColor: Color(0xFF93C5FD),
      backgroundColor: Color(0xFF0F172A),
      cardColor: Color(0xFF1E293B),
      textColor: Color(0xFFF1F5F9),
      subtextColor: Color(0xFF94A3B8),
      brightness: Brightness.dark,
      courseColors: [
        Color(0xFF60A5FA),
        Color(0xFF34D399),
        Color(0xFFFBBF24),
        Color(0xFFF87171),
        Color(0xFFA78BFA),
        Color(0xFF22D3EE),
        Color(0xFFFB923C),
        Color(0xFF4ADE80),
        Color(0xFFF472B6),
        Color(0xFF818CF8),
      ],
    ),
  ];

  static AppThemePreset getById(String id) {
    return presets.firstWhere(
      (preset) => preset.id == id,
      orElse: () => presets.first,
    );
  }

  static List<AppThemePreset> get lightPresets =>
      presets.where((preset) => preset.brightness == Brightness.light).toList();

  static List<AppThemePreset> get darkPresets =>
      presets.where((preset) => preset.brightness == Brightness.dark).toList();
}
