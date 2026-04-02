import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/schedule_override.dart';
import '../services/schedule_provider.dart';
import '../utils/constants.dart';
import '../utils/schedule_slot_dialog_utils.dart';

Future<void> openScheduleOverrideForm(
  BuildContext context, {
  required ScheduleProvider provider,
  required int week,
  required int weekday,
  required ScheduleOverrideType type,
  ScheduleOverride? initialOverride,
  ScheduleSlot? sourceSlot,
  String sourceTeacher = '',
  int? initialStartSection,
  int? initialEndSection,
}) async {
  final date = provider.getDateForSlot(week, weekday);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) {
      return ScheduleOverrideFormSheet(
        hostContext: context,
        provider: provider,
        week: week,
        weekday: weekday,
        date: date,
        type: type,
        initialOverride: initialOverride,
        sourceSlot: sourceSlot,
        sourceTeacher: sourceTeacher,
        initialStartSection: initialStartSection,
        initialEndSection: initialEndSection,
      );
    },
  );
}

class ScheduleOverrideFormSheet extends StatefulWidget {
  const ScheduleOverrideFormSheet({
    super.key,
    required this.hostContext,
    required this.provider,
    required this.week,
    required this.weekday,
    required this.date,
    required this.type,
    this.initialOverride,
    this.sourceSlot,
    this.sourceTeacher = '',
    this.initialStartSection,
    this.initialEndSection,
  });

  final BuildContext hostContext;
  final ScheduleProvider provider;
  final int week;
  final int weekday;
  final DateTime date;
  final ScheduleOverrideType type;
  final ScheduleOverride? initialOverride;
  final ScheduleSlot? sourceSlot;
  final String sourceTeacher;
  final int? initialStartSection;
  final int? initialEndSection;

  @override
  State<ScheduleOverrideFormSheet> createState() =>
      _ScheduleOverrideFormSheetState();
}

class _ScheduleOverrideFormSheetState extends State<ScheduleOverrideFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _teacherController;
  late final TextEditingController _locationController;
  late final TextEditingController _noteController;

  late int _startSection;
  late int _endSection;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text:
          widget.initialOverride?.courseName.isNotEmpty == true
              ? widget.initialOverride!.courseName
              : widget.sourceSlot?.courseName ?? '',
    );
    _teacherController = TextEditingController(
      text:
          widget.initialOverride?.teacher.isNotEmpty == true
              ? widget.initialOverride!.teacher
              : widget.sourceTeacher,
    );
    _locationController = TextEditingController(
      text:
          widget.initialOverride?.location.isNotEmpty == true
              ? widget.initialOverride!.location
              : widget.sourceSlot?.location ?? '',
    );
    _noteController = TextEditingController(
      text: widget.initialOverride?.note ?? '',
    );

    final totalSections = widget.provider.timeConfig.totalSections;
    _startSection = _clampSection(
      widget.initialOverride?.startSection ??
          widget.sourceSlot?.startSection ??
          widget.initialStartSection ??
          1,
      totalSections,
    );
    final initialEndSection =
        widget.initialOverride?.endSection ??
        widget.sourceSlot?.endSection ??
        widget.initialEndSection ??
        _startSection;
    _endSection = _clampSection(
      initialEndSection < _startSection ? _startSection : initialEndSection,
      totalSections,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teacherController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int _clampSection(int value, int totalSections) {
    if (value < 1) return 1;
    if (value > totalSections) return totalSections;
    return value;
  }

  Future<void> _save() async {
    final courseName = _nameController.text.trim();
    if (courseName.isEmpty && widget.type == ScheduleOverrideType.add) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先填写课程名称')));
      return;
    }

    final conflicts = collectScheduleOverrideConflicts(
      provider: widget.provider,
      week: widget.week,
      weekday: widget.weekday,
      startSection: _startSection,
      endSection: _endSection,
      sourceSlot: widget.sourceSlot,
      initialOverride: widget.initialOverride,
    );
    if (conflicts.isNotEmpty) {
      final confirmed = await confirmScheduleOverrideConflict(
        context,
        conflicts: conflicts,
      );
      if (!confirmed || !mounted || !widget.hostContext.mounted) return;
    }

    final override = buildScheduleOccurrenceOverride(
      semesterCode: widget.provider.currentSemesterCode ?? '20252',
      date: widget.date,
      weekday: widget.weekday,
      type: widget.type,
      startSection: _startSection,
      endSection: _endSection,
      courseName: courseName,
      teacher: _teacherController.text.trim(),
      location: _locationController.text.trim(),
      note: _noteController.text.trim(),
      initialOverride: widget.initialOverride,
      sourceSlot: widget.sourceSlot,
      sourceTeacher: widget.sourceTeacher,
    );
    await widget.provider.upsertOverride(override);
    if (!mounted || !widget.hostContext.mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(widget.hostContext).showSnackBar(
      SnackBar(content: Text(scheduleOverrideSavedMessage(widget.type))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSections = widget.provider.timeConfig.totalSections;
    final startItems = List.generate(totalSections, (i) => i + 1);
    final endItems = List.generate(
      totalSections - _startSection + 1,
      (i) => _startSection + i,
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                scheduleOverrideFormTitle(widget.type),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${formatScheduleDialogDate(widget.date)} 周${WeekdayNames.getShort(widget.weekday)}',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '课程名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('start-$_startSection-$_endSection'),
                      initialValue: _startSection,
                      decoration: const InputDecoration(
                        labelText: '开始节次',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          startItems
                              .map(
                                (value) => DropdownMenuItem<int>(
                                  value: value,
                                  child: Text('第$value节'),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _startSection = value;
                          if (_endSection < _startSection) {
                            _endSection = _startSection;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('end-$_startSection-$_endSection'),
                      initialValue: _endSection,
                      decoration: const InputDecoration(
                        labelText: '结束节次',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          endItems
                              .map(
                                (value) => DropdownMenuItem<int>(
                                  value: value,
                                  child: Text('第$value节'),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _endSection = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: '地点',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _teacherController,
                decoration: const InputDecoration(
                  labelText: '教师',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '备注',
                  hintText: '例如：调到实验楼、和某课程换课、临时补课说明',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _save, child: const Text('保存')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
