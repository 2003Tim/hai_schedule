import 'dart:io';

import 'package:flutter/material.dart';

import 'package:hai_schedule/services/theme_provider.dart';

class ThemeSectionTitle extends StatelessWidget {
  const ThemeSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }
}

class ThemeModeCard extends StatelessWidget {
  const ThemeModeCard({super.key, required this.theme});

  final ThemeProvider theme;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: theme.followSystemTheme,
            title: const Text('跟随系统深浅色模式'),
            subtitle: Text(
              theme.followSystemTheme
                  ? '系统浅色和深色将分别使用不同预设主题'
                  : '当前使用手动选择的单个预设主题',
            ),
            onChanged: theme.setFollowSystemTheme,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ThemeModeBadge(
                  label:
                      theme.followSystemTheme
                          ? '浅色：${theme.systemLightPreset.name}'
                          : '当前：${theme.currentPreset.name}',
                  icon: Icons.light_mode_rounded,
                ),
                _ThemeModeBadge(
                  label:
                      theme.followSystemTheme
                          ? '深色：${theme.systemDarkPreset.name}'
                          : '亮度：${theme.currentPreset.brightness == Brightness.dark ? '深色' : '浅色'}',
                  icon: Icons.dark_mode_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ThemePresetGrid extends StatelessWidget {
  const ThemePresetGrid({
    super.key,
    required this.presets,
    required this.selectedId,
    required this.onSelected,
  });

  final List<AppThemePreset> presets;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: presets.length,
      itemBuilder: (context, index) {
        final preset = presets[index];
        final isSelected = selectedId == preset.id;

        return GestureDetector(
          onTap: () => onSelected(preset.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: preset.backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? preset.primaryColor : Colors.transparent,
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow:
                  isSelected
                      ? [
                        BoxShadow(
                          color: preset.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(preset.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 6),
                Text(
                  preset.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: preset.textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    4,
                    (i) => Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: preset.courseColors[i],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ThemeBackgroundSection extends StatelessWidget {
  const ThemeBackgroundSection({
    super.key,
    required this.theme,
    required this.activePreset,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  final ThemeProvider theme;
  final AppThemePreset activePreset;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;

  @override
  Widget build(BuildContext context) {
    if (theme.hasCustomBg) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Image.file(
              key: ValueKey(theme.customBgPath),
              File(theme.customBgPath!),
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Container(
              height: 160,
              width: double.infinity,
              color: activePreset.backgroundColor.withValues(
                alpha: theme.bgOpacity,
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Row(
                children: [
                  _ThemeOverlayIconButton(
                    icon: Icons.refresh_rounded,
                    onTap: onPickImage,
                  ),
                  const SizedBox(width: 8),
                  _ThemeOverlayIconButton(
                    icon: Icons.delete_outline_rounded,
                    onTap: onRemoveImage,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onPickImage,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.3),
            width: 1.5,
          ),
          color: Colors.grey.withValues(alpha: 0.05),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 32,
              color: Colors.grey,
            ),
            SizedBox(height: 8),
            Text(
              '上传自定义背景图片',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class ThemeTuningSlider extends StatelessWidget {
  const ThemeTuningSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayText,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String displayText;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            Text(
              displayText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: const SliderThemeData(
            trackHeight: 4,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}

class ThemeRecommendationCard extends StatelessWidget {
  const ThemeRecommendationCard({super.key, required this.theme});

  final ThemeProvider theme;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_fix_high_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              const Text(
                '视觉推荐参数',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            theme.hasCustomBg
                ? '复杂背景图建议使用：透明度 26% · 模糊 18 · 卡片透明度 92%'
                : '纯色背景下也可以一键恢复推荐参数，保证主界面与小组件观感一致。',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: theme.applyRecommendedGlassTuning,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('恢复推荐视觉参数'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeBadge extends StatelessWidget {
  const _ThemeModeBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOverlayIconButton extends StatelessWidget {
  const _ThemeOverlayIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
