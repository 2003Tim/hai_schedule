import 'package:flutter/material.dart';

import 'package:hai_schedule/services/schedule_provider.dart';
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
      return ScheduleSlotMenuSheet(
        hostContext: context,
        provider: provider,
        week: week,
        weekday: weekday,
        date: date,
        displaySlot: displaySlot,
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
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) {
      return ScheduleSlotDetailsSheet(
        hostContext: context,
        provider: provider,
        week: week,
        weekday: weekday,
        date: date,
        displaySlot: displaySlot,
      );
    },
  );
}
