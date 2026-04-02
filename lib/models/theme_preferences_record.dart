class ThemePreferencesRecord {
  static const String defaultThemeId = 'blue';
  static const String defaultSystemLightThemeId = 'blue';
  static const String defaultSystemDarkThemeId = 'dark';
  static const double recommendedBgOpacity = 0.26;
  static const double recommendedBgBlur = 18.0;
  static const double recommendedCardOpacity = 0.92;

  final String themeId;
  final String systemLightThemeId;
  final String systemDarkThemeId;
  final bool followSystemTheme;
  final String? customBgPath;
  final double bgOpacity;
  final double bgBlur;
  final double cardOpacity;

  const ThemePreferencesRecord({
    this.themeId = defaultThemeId,
    this.systemLightThemeId = defaultSystemLightThemeId,
    this.systemDarkThemeId = defaultSystemDarkThemeId,
    this.followSystemTheme = false,
    this.customBgPath,
    this.bgOpacity = recommendedBgOpacity,
    this.bgBlur = recommendedBgBlur,
    this.cardOpacity = recommendedCardOpacity,
  });

  bool get hasCustomBg => customBgPath != null && customBgPath!.isNotEmpty;

  ThemePreferencesRecord copyWith({
    String? themeId,
    String? systemLightThemeId,
    String? systemDarkThemeId,
    bool? followSystemTheme,
    String? customBgPath,
    bool clearCustomBg = false,
    double? bgOpacity,
    double? bgBlur,
    double? cardOpacity,
  }) {
    return ThemePreferencesRecord(
      themeId: themeId ?? this.themeId,
      systemLightThemeId: systemLightThemeId ?? this.systemLightThemeId,
      systemDarkThemeId: systemDarkThemeId ?? this.systemDarkThemeId,
      followSystemTheme: followSystemTheme ?? this.followSystemTheme,
      customBgPath: clearCustomBg ? null : (customBgPath ?? this.customBgPath),
      bgOpacity: bgOpacity ?? this.bgOpacity,
      bgBlur: bgBlur ?? this.bgBlur,
      cardOpacity: cardOpacity ?? this.cardOpacity,
    );
  }
}
