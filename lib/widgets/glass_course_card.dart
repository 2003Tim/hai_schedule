import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:hai_schedule/utils/theme_appearance.dart';

class GlassCourseCard extends StatelessWidget {
  const GlassCourseCard({
    super.key,
    required this.courseName,
    required this.timeText,
    required this.locationText,
    this.teacherText = '',
    this.noteText = '',
    required this.color,
    this.isDetailed = false,
    this.isHighlighted = false,
    this.onTap,
  });

  final String courseName;
  final String timeText;
  final String locationText;
  final String teacherText;
  final String noteText;
  final Color color;
  final bool isDetailed;
  final bool isHighlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(22);
    final baseAlpha = isDark ? 0.18 : 0.28;
    final strongAlpha = isDark ? 0.24 : 0.38;
    final fillAlpha = isHighlighted ? strongAlpha : baseAlpha;
    final glassColor = color.withValues(alpha: fillAlpha);
    final highlightColor = Colors.white.withValues(alpha: isDark ? 0.14 : 0.24);
    final borderColor = Colors.white.withValues(alpha: 0.5);
    final shadowColor = color.withValues(alpha: isDark ? 0.16 : 0.22);
    final titleColor = Color.alphaBlend(
      color.withValues(alpha: isDark ? 0.18 : 0.12),
      theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.92 : 0.88),
    );
    final bodyColor = titleColor.withValues(alpha: 0.78);
    final captionColor = titleColor.withValues(alpha: 0.64);

    final child = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(color: borderColor, width: 0.5),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color.alphaBlend(highlightColor, glassColor),
                glassColor,
                color.withValues(alpha: fillAlpha * (isDark ? 0.88 : 0.96)),
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: shadowColor,
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -22,
                right: -16,
                child: IgnorePointer(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: isDark ? 0.07 : 0.14),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(isDetailed ? 12 : 10),
                child: isDetailed
                    ? _DetailedContent(
                        courseName: courseName,
                        timeText: timeText,
                        locationText: locationText,
                        teacherText: teacherText,
                        noteText: noteText,
                        titleColor: titleColor,
                        bodyColor: bodyColor,
                        captionColor: captionColor,
                        accentColor: color,
                        isHighlighted: isHighlighted,
                      )
                    : _CompactContent(
                        courseName: courseName,
                        timeText: timeText,
                        locationText: locationText,
                        titleColor: titleColor,
                        bodyColor: bodyColor,
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: child,
      ),
    );
  }
}

class _DetailedContent extends StatelessWidget {
  const _DetailedContent({
    required this.courseName,
    required this.timeText,
    required this.locationText,
    required this.teacherText,
    required this.noteText,
    required this.titleColor,
    required this.bodyColor,
    required this.captionColor,
    required this.accentColor,
    required this.isHighlighted,
  });

  final String courseName;
  final String timeText;
  final String locationText;
  final String teacherText;
  final String noteText;
  final Color titleColor;
  final Color bodyColor;
  final Color captionColor;
  final Color accentColor;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                courseName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            if (isHighlighted) ...[
              const SizedBox(width: 8),
              _GlassTag(
                label: '下一节',
                backgroundColor: accentColor,
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        _MetaRow(
          icon: Icons.schedule_rounded,
          text: timeText,
          color: bodyColor,
        ),
        const SizedBox(height: 8),
        _MetaRow(
          icon: Icons.place_rounded,
          text: locationText,
          color: bodyColor,
        ),
        if (teacherText.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          _MetaRow(
            icon: Icons.person_rounded,
            text: teacherText,
            color: bodyColor,
          ),
        ],
        if (noteText.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            noteText,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: captionColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _CompactContent extends StatelessWidget {
  const _CompactContent({
    required this.courseName,
    required this.timeText,
    required this.locationText,
    required this.titleColor,
    required this.bodyColor,
  });

  final String courseName;
  final String timeText;
  final String locationText;
  final Color titleColor;
  final Color bodyColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          courseName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: titleColor,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          timeText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: bodyColor,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          locationText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: bodyColor.withValues(alpha: 0.74),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassTag extends StatelessWidget {
  const _GlassTag({
    required this.label,
    required this.backgroundColor,
  });

  final String label;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.38), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          label,
          style: TextStyle(
            color: ThemeAppearance.readableForeground(backgroundColor),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}
