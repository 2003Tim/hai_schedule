class WindowShellPreferences {
  final double opacity;
  final bool alwaysOnTop;

  const WindowShellPreferences({
    this.opacity = 0.95,
    this.alwaysOnTop = true,
  });

  WindowShellPreferences copyWith({
    double? opacity,
    bool? alwaysOnTop,
  }) {
    return WindowShellPreferences(
      opacity: opacity ?? this.opacity,
      alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
    );
  }
}
