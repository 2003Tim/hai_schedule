import 'package:flutter/material.dart';

import 'package:hai_schedule/utils/schedule_ui_tokens.dart';

class SharedGlassContainer extends StatelessWidget {
  const SharedGlassContainer({
    super.key,
    required this.child,
    this.surfaceKey,
    this.blurKey,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  final Widget child;
  final Key? surfaceKey;
  final Key? blurKey;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = ScheduleUiTokens.adaptiveGlassRadius;
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        key: blurKey,
        filter: ScheduleUiTokens.adaptiveGlassBlur,
        child: Container(
          key: surfaceKey,
          width: double.infinity,
          padding: padding,
          decoration: ScheduleUiTokens.adaptiveGlassDecoration(
            Theme.of(context),
            borderRadius: radius,
          ),
          child: child,
        ),
      ),
    );
  }
}

class SharedGlassSheet extends StatelessWidget {
  const SharedGlassSheet({super.key, required this.child, this.surfaceKey});

  final Widget child;
  final Key? surfaceKey;

  @override
  Widget build(BuildContext context) {
    return SharedGlassContainer(surfaceKey: surfaceKey, child: child);
  }
}

class SharedGlassPill extends StatelessWidget {
  const SharedGlassPill({
    super.key,
    required this.child,
    required this.selected,
    this.current = false,
    this.width,
    this.height,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final bool selected;
  final bool current;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      height: height,
      padding: padding,
      decoration:
          selected || current
              ? ScheduleUiTokens.adaptiveGlassStateDecoration(
                Theme.of(context),
                selected: selected,
                current: !selected && current,
                borderRadius: ScheduleUiTokens.pillRadius,
              )
              : null,
      child: child,
    );
  }
}

class SharedGlassDot extends StatelessWidget {
  const SharedGlassDot({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: visible ? 4 : 0,
      height: 4,
      decoration: BoxDecoration(
        color:
            visible
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.72)
                : null,
        borderRadius: ScheduleUiTokens.pillRadius,
      ),
    );
  }
}

class SharedGlassCapsuleIndicator extends StatelessWidget {
  const SharedGlassCapsuleIndicator({
    super.key,
    required this.color,
    this.width = 3,
    this.height = 18,
  });

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.82),
        borderRadius: ScheduleUiTokens.pillRadius,
      ),
    );
  }
}

class SharedGlassCircleIcon extends StatelessWidget {
  const SharedGlassCircleIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.size,
    required this.iconSize,
    this.surfaceAlpha = 0.10,
    this.borderAlpha = 0.16,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final double surfaceAlpha;
  final double borderAlpha;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surface.withValues(alpha: surfaceAlpha),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: borderAlpha),
          width: ScheduleUiTokens.adaptiveGlassBorderWidthFor(theme),
        ),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

class SharedGlassGrabber extends StatelessWidget {
  const SharedGlassGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: ScheduleUiTokens.adaptiveGlassMetadataTextFor(
          Theme.of(context),
        ).withValues(alpha: 0.24),
        borderRadius: ScheduleUiTokens.pillRadius,
      ),
    );
  }
}

class SharedGlassInfoPill extends StatelessWidget {
  const SharedGlassInfoPill({
    super.key,
    required this.icon,
    required this.label,
    required this.tintColor,
  });

  final IconData icon;
  final String label;
  final Color tintColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tintColor.withValues(alpha: 0.10),
        borderRadius: ScheduleUiTokens.pillRadius,
        border: Border.all(color: tintColor.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tintColor.withValues(alpha: 0.90)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tintColor.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}

class SharedGlassWeekCell extends StatelessWidget {
  const SharedGlassWeekCell({
    super.key,
    required this.week,
    required this.isActive,
    required this.isCurrent,
    required this.baseColor,
  });

  final int week;
  final bool isActive;
  final bool isCurrent;
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryText = ScheduleUiTokens.primaryTextFor(theme);
    final secondaryText = ScheduleUiTokens.secondaryTextFor(theme);
    final borderColor =
        isActive
            ? baseColor.withValues(alpha: 0.40)
            : (isCurrent
                ? baseColor.withValues(alpha: 0.22)
                : ScheduleUiTokens.glassBorderFor(
                  theme,
                ).withValues(alpha: 0.55));
    final fillColor =
        isActive
            ? baseColor.withValues(alpha: 0.14)
            : theme.colorScheme.surface.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.32 : 0.56,
            );

    return Container(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isCurrent ? 1.2 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$week',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1,
              color:
                  isActive
                      ? baseColor.withValues(alpha: 0.96)
                      : primaryText.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '周',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1,
              color:
                  isActive
                      ? baseColor.withValues(alpha: 0.78)
                      : secondaryText.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}
