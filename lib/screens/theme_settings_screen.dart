import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:hai_schedule/services/theme_provider.dart';
import 'package:hai_schedule/widgets/theme_settings_sections.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  Future<void> _pickImage(BuildContext context, ThemeProvider theme) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    try {
      await theme.setCustomBackground(pickedFile.path);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('背景图片已更新')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新背景失败: ${error.toString()}')));
    }
  }

  Future<void> _removeImage(BuildContext context, ThemeProvider theme) async {
    await theme.removeCustomBackground();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已移除自定义背景')));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, _) {
        final brightness = Theme.of(context).brightness;
        final activePreset = theme.presetForBrightness(brightness);

        return Scaffold(
          appBar: AppBar(title: const Text('主题设置'), centerTitle: true),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const ThemeSectionTitle('主题模式'),
              const SizedBox(height: 12),
              ThemeModeCard(theme: theme),
              const SizedBox(height: 24),
              if (theme.followSystemTheme) ...[
                const ThemeSectionTitle('系统浅色主题'),
                const SizedBox(height: 12),
                ThemePresetGrid(
                  presets: AppThemes.lightPresets,
                  selectedId: theme.systemLightThemeId,
                  onSelected: theme.setSystemLightTheme,
                ),
                const SizedBox(height: 24),
                const ThemeSectionTitle('系统深色主题'),
                const SizedBox(height: 12),
                ThemePresetGrid(
                  presets: AppThemes.darkPresets,
                  selectedId: theme.systemDarkThemeId,
                  onSelected: theme.setSystemDarkTheme,
                ),
              ] else ...[
                const ThemeSectionTitle('手动选择主题'),
                const SizedBox(height: 12),
                ThemePresetGrid(
                  presets: AppThemes.presets,
                  selectedId: theme.themeId,
                  onSelected: theme.setTheme,
                ),
              ],
              const SizedBox(height: 28),
              const ThemeSectionTitle('自定义背景'),
              const SizedBox(height: 12),
              ThemeBackgroundSection(
                theme: theme,
                activePreset: activePreset,
                onPickImage: () => _pickImage(context, theme),
                onRemoveImage: () => _removeImage(context, theme),
              ),
              if (theme.hasCustomBg) ...[
                const SizedBox(height: 20),
                ThemeTuningSlider(
                  label: '背景透明度',
                  value: theme.bgOpacity,
                  min: 0.0,
                  max: 1.0,
                  displayText: '${(theme.bgOpacity * 100).round()}%',
                  onChanged: theme.setBgOpacity,
                ),
                const SizedBox(height: 16),
                ThemeTuningSlider(
                  label: '背景模糊度',
                  value: theme.bgBlur,
                  min: 0.0,
                  max: 30.0,
                  displayText: theme.bgBlur.round().toString(),
                  onChanged: theme.setBgBlur,
                ),
              ],
              const SizedBox(height: 20),
              ThemeTuningSlider(
                label: '课程卡片透明度',
                value: theme.cardOpacity,
                min: 0.5,
                max: 1.0,
                displayText: '${(theme.cardOpacity * 100).round()}%',
                onChanged: theme.setCardOpacity,
              ),
              const SizedBox(height: 16),
              ThemeRecommendationCard(theme: theme),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}
