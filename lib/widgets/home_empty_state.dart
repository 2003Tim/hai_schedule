import 'package:flutter/material.dart';

import 'package:hai_schedule/models/schedule_source.dart';

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({
    super.key,
    required this.onLoginFetch,
    required this.selectedSource,
    required this.onSourceChanged,
  });

  final VoidCallback onLoginFetch;
  final ScheduleSource selectedSource;
  final ValueChanged<ScheduleSource> onSourceChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final loginButtonStyle = FilledButton.styleFrom(
      elevation: 0,
      shadowColor: Colors.transparent,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      overlayColor: colorScheme.onPrimary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 56,
                  color: colorScheme.primary.withValues(alpha: 0.28),
                ),
                const SizedBox(height: 14),
                const Text(
                  '还没有导入课表',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '登录教务系统后会自动识别并抓取课表。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 18),
                SegmentedButton<ScheduleSource>(
                  segments: ScheduleSource.values
                      .map(
                        (source) => ButtonSegment<ScheduleSource>(
                          value: source,
                          label: Text(source.label),
                          icon: Icon(
                            source.isGraduate
                                ? Icons.school_rounded
                                : Icons.badge_outlined,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  selected: {selectedSource},
                  onSelectionChanged: (values) {
                    final next = values.firstOrNull;
                    if (next != null) onSourceChanged(next);
                  },
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: loginButtonStyle,
                  onPressed: onLoginFetch,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('登录并刷新课表'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
