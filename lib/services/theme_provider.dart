import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widget_sync_service.dart';

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
      emoji: '🔮',
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
      emoji: '🌙',
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
    return presets.firstWhere((t) => t.id == id, orElse: () => presets.first);
  }

  static List<AppThemePreset> get lightPresets =>
      presets.where((e) => e.brightness == Brightness.light).toList();

  static List<AppThemePreset> get darkPresets =>
      presets.where((e) => e.brightness == Brightness.dark).toList();
}

class ThemeProvider extends ChangeNotifier {
  static const String _prefsThemeId = 'theme_id';
  static const String _prefsBgPath = 'custom_bg_path';
  static const String _prefsBgOpacity = 'bg_opacity';
  static const String _prefsBgBlur = 'bg_blur';
  static const String _prefsCardOpacity = 'card_opacity';
  static const String _prefsFollowSystem = 'follow_system_theme';
  static const String _prefsSystemLightThemeId = 'system_light_theme_id';
  static const String _prefsSystemDarkThemeId = 'system_dark_theme_id';

  static const double recommendedBgOpacity = 0.26;
  static const double recommendedBgBlur = 18.0;
  static const double recommendedCardOpacity = 0.92;

  String _themeId = 'blue';
  String _systemLightThemeId = 'blue';
  String _systemDarkThemeId = 'dark';
  bool _followSystemTheme = false;
  String? _customBgPath;
  double _bgOpacity = recommendedBgOpacity;
  double _bgBlur = recommendedBgBlur;
  double _cardOpacity = recommendedCardOpacity;

  ThemeProvider() {
    _loadPrefs();
  }

  String get themeId => _themeId;
  String get systemLightThemeId => _systemLightThemeId;
  String get systemDarkThemeId => _systemDarkThemeId;
  bool get followSystemTheme => _followSystemTheme;
  String? get customBgPath => _customBgPath;
  double get bgOpacity => _bgOpacity;
  double get bgBlur => _bgBlur;
  double get cardOpacity => _cardOpacity;
  bool get hasCustomBg => _customBgPath != null && _customBgPath!.isNotEmpty;

  AppThemePreset get currentPreset => AppThemes.getById(_themeId);
  AppThemePreset get systemLightPreset =>
      AppThemes.getById(_systemLightThemeId);
  AppThemePreset get systemDarkPreset => AppThemes.getById(_systemDarkThemeId);

  ThemeMode get themeMode {
    if (_followSystemTheme) return ThemeMode.system;
    return currentPreset.brightness == Brightness.dark
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  AppThemePreset presetForBrightness(Brightness brightness) {
    if (_followSystemTheme) {
      return brightness == Brightness.dark
          ? systemDarkPreset
          : systemLightPreset;
    }
    return currentPreset;
  }

  Color _tintedGlassBase(AppThemePreset preset) {
    final liftedCard = Color.alphaBlend(
      preset.backgroundColor.withValues(
        alpha: preset.brightness == Brightness.dark ? 0.10 : 0.06,
      ),
      preset.cardColor,
    );
    return Color.alphaBlend(
      preset.primaryColor.withValues(
        alpha: preset.brightness == Brightness.dark ? 0.14 : 0.09,
      ),
      liftedCard,
    );
  }

  Color glassPanelFill(Brightness brightness, {double strength = 1.0}) {
    final preset = presetForBrightness(brightness);
    if (!hasCustomBg) {
      return Color.alphaBlend(
        preset.cardColor.withValues(
          alpha: preset.brightness == Brightness.dark ? 0.80 : 0.93,
        ),
        preset.backgroundColor,
      );
    }
    final base = _tintedGlassBase(preset);
    final baseOpacity = preset.brightness == Brightness.dark ? 0.26 : 0.30;
    return base.withValues(
      alpha: ((baseOpacity * strength).clamp(0.0, 0.95) as num).toDouble(),
    );
  }

  Color glassPanelStrongFill(Brightness brightness, {double strength = 1.0}) {
    final preset = presetForBrightness(brightness);
    if (!hasCustomBg) {
      return Color.alphaBlend(
        preset.cardColor.withValues(
          alpha: preset.brightness == Brightness.dark ? 0.88 : 0.98,
        ),
        preset.backgroundColor,
      );
    }
    final base = Color.alphaBlend(
      preset.primaryColor.withValues(
        alpha: preset.brightness == Brightness.dark ? 0.22 : 0.14,
      ),
      _tintedGlassBase(preset),
    );
    final baseOpacity = preset.brightness == Brightness.dark ? 0.34 : 0.40;
    return base.withValues(
      alpha: ((baseOpacity * strength).clamp(0.0, 0.98) as num).toDouble(),
    );
  }

  Color glassOutline(Brightness brightness, {double strength = 1.0}) {
    final preset = presetForBrightness(brightness);
    final opacity = preset.brightness == Brightness.dark ? 0.22 : 0.14;
    return preset.subtextColor.withValues(
      alpha: ((opacity * strength).clamp(0.0, 0.60) as num).toDouble(),
    );
  }

  Color glassHighlight(Brightness brightness, {double strength = 1.0}) {
    final preset = presetForBrightness(brightness);
    final opacity = preset.brightness == Brightness.dark ? 0.10 : 0.20;
    return Colors.white.withValues(
      alpha: ((opacity * strength).clamp(0.0, 0.40) as num).toDouble(),
    );
  }

  ThemeData themeDataFor(Brightness brightness) {
    final preset = presetForBrightness(brightness);
    final scheme = ColorScheme.fromSeed(
      seedColor: preset.primaryColor,
      brightness: preset.brightness,
    );

    final surface =
        hasCustomBg
            ? glassPanelFill(brightness, strength: 0.94)
            : Color.alphaBlend(
              preset.cardColor.withValues(
                alpha: preset.brightness == Brightness.dark ? 0.80 : 0.94,
              ),
              preset.backgroundColor,
            );

    final surfaceHigh =
        hasCustomBg
            ? glassPanelStrongFill(brightness, strength: 0.94)
            : Color.alphaBlend(
              preset.cardColor.withValues(
                alpha: preset.brightness == Brightness.dark ? 0.88 : 0.98,
              ),
              preset.backgroundColor,
            );

    return ThemeData(
      useMaterial3: true,
      brightness: preset.brightness,
      colorScheme: scheme.copyWith(
        surface: surface,
        surfaceContainerHighest: surfaceHigh,
      ),
      scaffoldBackgroundColor: preset.backgroundColor,
      cardColor: preset.cardColor,
      dividerColor: preset.subtextColor.withValues(alpha: 0.12),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: preset.textColor),
        bodyMedium: TextStyle(color: preset.textColor),
        bodySmall: TextStyle(color: preset.subtextColor),
        titleLarge: TextStyle(
          color: preset.textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: preset.textColor,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
    );
  }

  ThemeData get themeData => themeDataFor(Brightness.light);
  ThemeData get darkThemeData => themeDataFor(Brightness.dark);

  void setTheme(String id) {
    _themeId = id;
    _savePrefs();
    _refreshWidgetAppearance();
    notifyListeners();
  }

  void setFollowSystemTheme(bool value) {
    _followSystemTheme = value;
    _savePrefs();
    _refreshWidgetAppearance();
    notifyListeners();
  }

  void setSystemLightTheme(String id) {
    _systemLightThemeId = id;
    _savePrefs();
    _refreshWidgetAppearance();
    notifyListeners();
  }

  void setSystemDarkTheme(String id) {
    _systemDarkThemeId = id;
    _savePrefs();
    _refreshWidgetAppearance();
    notifyListeners();
  }

  Future<void> setCustomBackground(String imagePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final bgDir = Directory('${appDir.path}/backgrounds');
    if (!await bgDir.exists()) {
      await bgDir.create(recursive: true);
    }

    final previousPath = _customBgPath;
    final ext = _normalizeImageExtension(imagePath);
    final destPath =
        '${bgDir.path}/custom_bg_${DateTime.now().microsecondsSinceEpoch}.$ext';

    await File(imagePath).copy(destPath);

    _customBgPath = destPath;
    await _savePrefs();
    await _evictBackgroundImage(previousPath);
    await _deleteBackgroundFile(previousPath);
    notifyListeners();
  }

  Future<void> removeCustomBackground() async {
    final previousPath = _customBgPath;
    _customBgPath = null;
    await _savePrefs();
    await _evictBackgroundImage(previousPath);
    await _deleteBackgroundFile(previousPath);
    notifyListeners();
  }

  void applyRecommendedGlassTuning() {
    _bgOpacity = recommendedBgOpacity;
    _bgBlur = recommendedBgBlur;
    _cardOpacity = recommendedCardOpacity;
    _savePrefs();
    notifyListeners();
  }

  void setBgOpacity(double value) {
    _bgOpacity = value.clamp(0.0, 1.0);
    _savePrefs();
    notifyListeners();
  }

  void setBgBlur(double value) {
    _bgBlur = value.clamp(0.0, 30.0);
    _savePrefs();
    notifyListeners();
  }

  void setCardOpacity(double value) {
    _cardOpacity = value.clamp(0.5, 1.0);
    _savePrefs();
    notifyListeners();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _themeId = prefs.getString(_prefsThemeId) ?? 'blue';
    _systemLightThemeId = prefs.getString(_prefsSystemLightThemeId) ?? 'blue';
    _systemDarkThemeId = prefs.getString(_prefsSystemDarkThemeId) ?? 'dark';
    _followSystemTheme = prefs.getBool(_prefsFollowSystem) ?? false;
    _customBgPath = prefs.getString(_prefsBgPath);
    _bgOpacity = prefs.getDouble(_prefsBgOpacity) ?? recommendedBgOpacity;
    _bgBlur = prefs.getDouble(_prefsBgBlur) ?? recommendedBgBlur;
    _cardOpacity = prefs.getDouble(_prefsCardOpacity) ?? recommendedCardOpacity;

    if (_customBgPath != null && !File(_customBgPath!).existsSync()) {
      _customBgPath = null;
    }

    notifyListeners();
  }

  Future<void> reloadFromStorage() => _loadPrefs();

  void _refreshWidgetAppearance() {
    unawaited(WidgetSyncService.refreshWidget());
  }

  String _normalizeImageExtension(String imagePath) {
    final dotIndex = imagePath.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == imagePath.length - 1) return 'jpg';

    final extension = imagePath
        .substring(dotIndex + 1)
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (extension.isEmpty || extension.length > 8) return 'jpg';
    return extension;
  }

  Future<void> _evictBackgroundImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;
    try {
      await FileImage(File(imagePath)).evict();
    } catch (_) {
      // Best effort only. If eviction fails, the new unique file path still
      // forces Flutter to load the replacement image.
    }
  }

  Future<void> _deleteBackgroundFile(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;
    final file = File(imagePath);
    if (!await file.exists()) return;
    try {
      await file.delete();
    } catch (_) {
      // Ignore cleanup failures to avoid blocking theme updates.
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsThemeId, _themeId);
    await prefs.setString(_prefsSystemLightThemeId, _systemLightThemeId);
    await prefs.setString(_prefsSystemDarkThemeId, _systemDarkThemeId);
    await prefs.setBool(_prefsFollowSystem, _followSystemTheme);
    if (_customBgPath != null) {
      await prefs.setString(_prefsBgPath, _customBgPath!);
    } else {
      await prefs.remove(_prefsBgPath);
    }
    await prefs.setDouble(_prefsBgOpacity, _bgOpacity);
    await prefs.setDouble(_prefsBgBlur, _bgBlur);
    await prefs.setDouble(_prefsCardOpacity, _cardOpacity);
  }
}
