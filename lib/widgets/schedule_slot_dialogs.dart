import 'package:flutter/material.dart';

import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/widgets/adaptive_layout.dart';
import 'package:hai_schedule/widgets/schedule_slot_dialog_sections.dart';

export 'schedule_override_form_sheet.dart' show openScheduleOverrideForm;

Future<void> openScheduleSlotMenu(
  BuildContext context, {
  required ScheduleProvider provider,
  required int week,
  required int weekday,
  required DisplayScheduleSlot displaySlot,
}) async {
  final date = provider.getDateForSlot(week, weekday);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) {
      return AdaptiveSheet(
        maxWidth: 680,
        child: ScheduleSlotMenuSheet(
          hostContext: context,
          provider: provider,
          week: week,
          weekday: weekday,
          date: date,
          displaySlot: displaySlot,
        ),
      );
    },
  );
}

Future<void> openScheduleSlotDetails(
  BuildContext context, {
  required ScheduleProvider provider,
  required int week,
  required int weekday,
  required DisplayScheduleSlot displaySlot,
}) async {
  final date = provider.getDateForSlot(week, weekday);
  final isTablet = AdaptiveLayout.isTablet(context);

  if (isTablet) {
    await showDialog<void>(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: SingleChildScrollView(
              child: ScheduleSlotDetailsSheet(
                hostContext: context,
                provider: provider,
                week: week,
                weekday: weekday,
                date: date,
                displaySlot: displaySlot,
              ),
            ),
          ),
        );
      },
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return AdaptiveSheet(
          maxWidth: 760,
          child: ScheduleSlotDetailsSheet(
            hostContext: context,
            provider: provider,
            week: week,
            weekday: weekday,
            date: date,
            displaySlot: displaySlot,
          ),
        );
      },
    );
  }
}
