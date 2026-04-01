import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/schedule_override.dart';
import '../models/school_time.dart';
import '../models/schedule_parser.dart';
import '../utils/week_calculator.dart';
import 'app_repositories.dart';
import 'class_silence_service.dart';
import 'class_reminder_service.dart';
import 'widget_sync_service.dart';

class ScheduleProvider extends ChangeNotifier {
  final ScheduleRepository _scheduleRepository = ScheduleRepository();
  final SchedulePreferencesRepository _preferencesRepository =
      SchedulePreferencesRepository();
  final ScheduleOverrideRepository _overrideRepository =
      ScheduleOverrideRepository();
  final SchoolTimeRepository _schoolTimeRepository = SchoolTimeRepository();

  List<Course> _courses = [];
  List<ScheduleOverride> _overrides = [];
  final Map<String, List<DisplayScheduleSlot>> _displaySlotCache = {};
  int _currentWeek = 1;
  int _selectedWeek = 0;
  late WeekCalculator _weekCalc;
  late SchoolTimeConfig _timeConfig;
  String? _currentSemesterCode;
  List<String> _availableSemesterCodes = const [];

  List<Course> get courses => _courses;
  List<ScheduleOverride> get overrides => _overrides;
  int get currentWeek => _currentWeek;
  int get selectedWeek => _selectedWeek;
  WeekCalculator get weekCalc => _weekCalc;
  SchoolTimeConfig get timeConfig => _timeConfig;
  int get todayWeekday => _weekCalc.getTodayWeekday();
  String? get currentSemesterCode => _currentSemesterCode;
  List<String> get availableSemesterCodes => _availableSemesterCodes;

  int _displayDays = 7;
  int get displayDays => _displayDays;

  bool _showNonCurrentWeek = true;
  bool get showNonCurrentWeek => _showNonCurrentWeek;

  ScheduleProvider() {
    _timeConfig = SchoolTimeConfig.hainanuDefault();
    _applySemesterContext(null);
    _loadCourses();
    _loadPreferences();
    _loadTimeConfig();
  }

  @override
  void notifyListeners() {
    _displaySlotCache.clear();
    super.notifyListeners();
  }

  void selectWeek(int week) {
    if (week >= 1 && week <= _weekCalc.totalWeeks) {
      _selectedWeek = week;
      notifyListeners();
    }
  }

  void goToCurrentWeek() {
    _currentWeek = _weekCalc.getWeekNumber();
    _selectedWeek = _currentWeek.clamp(1, _weekCalc.totalWeeks);
    notifyListeners();
  }

  void setDisplayDays(int days) {
    _displayDays = days;
    _savePreferences();
    notifyListeners();
  }

  void toggleShowNonCurrentWeek() {
    _showNonCurrentWeek = !_showNonCurrentWeek;
    _savePreferences();
    notifyListeners();
  }

  Future<void> switchSemester(String semesterCode) async {
    if (semesterCode.isEmpty || semesterCode == _currentSemesterCode) return;

    await _scheduleRepository.saveActiveSemesterCode(semesterCode);
    await _loadCourses(notify: true);
  }

  Future<void> createSemester(String semesterCode) async {
    final normalized = semesterCode.trim();
    if (normalized.isEmpty) return;
    await _scheduleRepository.createEmptySemester(
      semesterCode: normalized,
      makeActive: true,
    );
    await _loadCourses(notify: true);
  }

  Future<void> deleteSemester(String semesterCode) async {
    if (semesterCode.isEmpty) return;
    await _scheduleRepository.deleteSemester(semesterCode);
    await _loadCourses(notify: true);
  }

  Future<void> reloadFromStorage() async {
    await _loadCourses(notify: false);
    await _loadPreferences();
    await _loadTimeConfig(notify: false);
    notifyListeners();
  }

  Future<void> updateTimeConfig(SchoolTimeConfig config) async {
    _timeConfig = config;
    await _schoolTimeRepository.save(config);
    await _syncDerivedOutputs(forceReminderRebuild: true);
    notifyListeners();
  }

  Future<void> resetTimeConfigToDefault() async {
    _timeConfig = SchoolTimeConfig.hainanuDefault();
    await _schoolTimeRepository.reset();
    await _syncDerivedOutputs(forceReminderRebuild: true);
    notifyListeners();
  }

  DisplayScheduleSlot? getDisplaySlotAt(int week, int weekday, int section) {
    final date = _weekCalc.getDate(week, weekday);
    final dateKey = _dateKeyFor(date);
    final dayOverrides =
        _overrides
            .where((item) => item.dateKey == dateKey && item.weekday == weekday)
            .toList();

    final displayOverride = _findDisplayOverride(dayOverrides, section);
    if (displayOverride != null) {
      final sourceMatch =
          displayOverride.type == ScheduleOverrideType.modify
              ? _resolveOverrideSourceSlot(
                week: week,
                weekday: weekday,
                override: displayOverride,
              )
              : null;
      return DisplayScheduleSlot(
        slot: _slotFromOverride(displayOverride, fallback: sourceMatch?.slot),
        teacher:
            displayOverride.teacher.isNotEmpty
                ? displayOverride.teacher
                : sourceMatch?.teacher ?? '',
        isActive: true,
        isOverride: true,
        overrideType: displayOverride.type,
        sourceOverride: displayOverride,
      );
    }

    for (final course in _courses) {
      for (final slot in course.slots) {
        if (slot.weekday != weekday ||
            slot.startSection > section ||
            slot.endSection < section) {
          continue;
        }

        if (slot.isActiveInWeek(week)) {
          final cancelOverride = _findTargetedOverride(
            dayOverrides,
            slot,
            ScheduleOverrideType.cancel,
          );
          if (cancelOverride != null) {
            return DisplayScheduleSlot(
              slot: slot,
              teacher: course.teacher,
              isActive: false,
              isOverride: true,
              overrideType: cancelOverride.type,
              sourceOverride: cancelOverride,
            );
          }

          final modifyOverride = _findTargetedOverride(
            dayOverrides,
            slot,
            ScheduleOverrideType.modify,
          );
          if (modifyOverride != null) {
            // Modified slots are rendered from their target sections above.
            continue;
          }

          return DisplayScheduleSlot(
            slot: slot,
            teacher: course.teacher,
            isActive: true,
          );
        }
      }
    }

    if (!_showNonCurrentWeek) return null;

    for (final course in _courses) {
      for (final slot in course.slots) {
        if (slot.weekday == weekday &&
            slot.startSection <= section &&
            slot.endSection >= section &&
            !slot.isActiveInWeek(week) &&
            slot.getAllActiveWeeks().isNotEmpty) {
          return DisplayScheduleSlot(
            slot: slot,
            teacher: course.teacher,
            isActive: false,
          );
        }
      }
    }

    return null;
  }

  ScheduleSlot? getNonActiveSlotAt(int week, int weekday, int section) {
    final displaySlot = getDisplaySlotAt(week, weekday, section);
    if (displaySlot == null || displaySlot.isActive) return null;
    return displaySlot.slot;
  }

  List<DisplayScheduleSlot> getDisplaySlotsForDay(int week, int weekday) {
    final key = '$week-$weekday';
    return _displaySlotCache.putIfAbsent(key, () {
      final slots = <DisplayScheduleSlot>[];
      for (var section = 1; section <= _timeConfig.totalSections; section++) {
        final displaySlot = getDisplaySlotAt(week, weekday, section);
        if (displaySlot == null) continue;
        if (displaySlot.slot.startSection != section) continue;
        slots.add(displaySlot);
      }
      return slots;
    });
  }

  String getTeacherForSlot(ScheduleSlot slot) {
    for (final course in _courses) {
      if (course.id == slot.courseId) {
        return course.teacher;
      }
    }
    return '';
  }

  DateTime getDateForSlot(int week, int weekday) =>
      _weekCalc.getDate(week, weekday);

  ScheduleOverride? getOverrideForDateSlot(
    DateTime date,
    int weekday,
    int section,
  ) {
    final dateKey = _dateKeyFor(date);
    for (final item in _overrides) {
      if (item.dateKey == dateKey &&
          item.weekday == weekday &&
          item.coversSection(section)) {
        return item;
      }
    }
    return null;
  }

  Future<void> upsertOverride(ScheduleOverride override) async {
    final semesterCode = await _resolveTargetSemesterCode(_currentSemesterCode);
    final updated =
        _overrides.where((item) => item.id != override.id).toList()..add(
          ScheduleOverride(
            id: override.id,
            semesterCode: semesterCode,
            dateKey: override.dateKey,
            weekday: override.weekday,
            startSection: override.startSection,
            endSection: override.endSection,
            type: override.type,
            targetCourseId: override.targetCourseId,
            courseName: override.courseName,
            teacher: override.teacher,
            location: override.location,
            note: override.note,
            status: override.status,
            sourceCourseName: override.sourceCourseName,
            sourceTeacher: override.sourceTeacher,
            sourceLocation: override.sourceLocation,
            sourceStartSection: override.sourceStartSection,
            sourceEndSection: override.sourceEndSection,
          ),
        );
    _overrides =
        updated..sort((a, b) {
          final dateCompare = a.dateKey.compareTo(b.dateKey);
          if (dateCompare != 0) return dateCompare;
          return a.startSection.compareTo(b.startSection);
        });
    await _overrideRepository.save(
      semesterCode: semesterCode,
      overrides: _overrides,
    );
    await _revalidateOverridesForSemester(semesterCode);
    await _syncDerivedOutputs(forceReminderRebuild: true);
    notifyListeners();
  }

  Future<void> removeOverride(String overrideId) async {
    final semesterCode = await _resolveTargetSemesterCode(_currentSemesterCode);
    _overrides = _overrides.where((item) => item.id != overrideId).toList();
    await _overrideRepository.save(
      semesterCode: semesterCode,
      overrides: _overrides,
    );
    await _syncDerivedOutputs(forceReminderRebuild: true);
    notifyListeners();
  }

  Future<void> importFromJson(String jsonString, {String? semesterCode}) async {
    final data = json.decode(jsonString) as Map<String, dynamic>;
    final courses = ScheduleParser.parseApiResponse(data);
    if (courses.isEmpty) {
      throw const FormatException('未解析到课程数据');
    }
    await setCourses(
      courses,
      semesterCode: semesterCode,
      rawScheduleJson: jsonString,
    );
  }

  Future<void> setCourses(
    List<Course> courses, {
    String? semesterCode,
    String? rawScheduleJson,
  }) async {
    final resolvedSemester = await _resolveTargetSemesterCode(semesterCode);
    _courses = courses;
    _currentSemesterCode = resolvedSemester;
    await _refreshAvailableSemesters(additional: resolvedSemester);
    _applySemesterContext(resolvedSemester);
    await _scheduleRepository.saveSemesterSchedule(
      semesterCode: resolvedSemester,
      rawScheduleJson: rawScheduleJson,
      courses: courses,
      makeActive: true,
    );
    await _revalidateOverridesForSemester(resolvedSemester);
    await _syncDerivedOutputs(forceReminderRebuild: true);
    notifyListeners();
  }

  Future<void> _loadCourses({bool notify = true}) async {
    final activeSemester = await _scheduleRepository.loadActiveSemesterCode();
    final cache = await _scheduleRepository.loadCache(
      semesterCode: activeSemester,
    );

    _currentSemesterCode = cache.semesterCode;
    await _refreshAvailableSemesters(additional: cache.semesterCode);
    _applySemesterContext(cache.semesterCode);
    _overrides = await _overrideRepository.load(cache.semesterCode);
    await _revalidateOverridesForSemester(cache.semesterCode);

    if (cache.rawScheduleJson != null && cache.rawScheduleJson!.isNotEmpty) {
      try {
        final data =
            json.decode(cache.rawScheduleJson!) as Map<String, dynamic>;
        final parsedCourses = ScheduleParser.parseApiResponse(data);
        if (parsedCourses.isNotEmpty) {
          _courses = parsedCourses;
          await _scheduleRepository.saveSemesterSchedule(
            semesterCode:
                cache.semesterCode ?? await _resolveTargetSemesterCode(null),
            rawScheduleJson: cache.rawScheduleJson,
            courses: parsedCourses,
            makeActive: true,
          );
          await _syncDerivedOutputs(forceReminderRebuild: true);
          if (notify) notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint('从原始课表缓存恢复失败: $e');
      }
    }

    if (cache.courses.isNotEmpty) {
      _courses = cache.courses;
      await _syncDerivedOutputs(forceReminderRebuild: true);
      if (notify) notifyListeners();
      return;
    }

    final storedCourses = await _scheduleRepository.loadCourses();
    if (storedCourses.isNotEmpty) {
      _courses = storedCourses;
      await _syncDerivedOutputs(forceReminderRebuild: true);
      if (notify) notifyListeners();
      return;
    }

    _courses = [];
    await _syncDerivedOutputs(forceReminderRebuild: true);
    if (notify) notifyListeners();
  }

  Future<void> _savePreferences() async {
    await _preferencesRepository.save(
      displayDays: _displayDays,
      showNonCurrentWeek: _showNonCurrentWeek,
    );
  }

  Future<void> _syncDerivedOutputs({bool forceReminderRebuild = false}) async {
    await WidgetSyncService.syncSchedule(
      courses: _courses,
      overrides: _overrides,
      weekCalc: _weekCalc,
      timeConfig: _timeConfig,
    );

    if (forceReminderRebuild) {
      await ClassReminderService.rebuildForSchedule(
        courses: _courses,
        overrides: _overrides,
        weekCalc: _weekCalc,
        timeConfig: _timeConfig,
      );
      await ClassSilenceService.rebuildForSchedule(
        courses: _courses,
        overrides: _overrides,
        weekCalc: _weekCalc,
        timeConfig: _timeConfig,
      );
    } else {
      await ClassReminderService.ensureCoverage(
        courses: _courses,
        overrides: _overrides,
        weekCalc: _weekCalc,
        timeConfig: _timeConfig,
      );
      await ClassSilenceService.ensureCoverage(
        courses: _courses,
        overrides: _overrides,
        weekCalc: _weekCalc,
        timeConfig: _timeConfig,
      );
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await _preferencesRepository.load();
    _displayDays = prefs.displayDays;
    _showNonCurrentWeek = prefs.showNonCurrentWeek;
    notifyListeners();
  }

  Future<void> _loadTimeConfig({bool notify = true}) async {
    _timeConfig = await _schoolTimeRepository.load();
    await _syncDerivedOutputs(forceReminderRebuild: true);
    if (notify) {
      notifyListeners();
    }
  }

  void _applySemesterContext(String? semesterCode) {
    _weekCalc = WeekCalculator.hainanuSemester(semesterCode);
    _currentWeek = _weekCalc.getWeekNumber();
    final desiredWeek = _selectedWeek == 0 ? _currentWeek : _selectedWeek;
    _selectedWeek = desiredWeek.clamp(1, _weekCalc.totalWeeks);
  }

  Future<String> _resolveTargetSemesterCode(String? semesterCode) async {
    if (semesterCode != null && semesterCode.isNotEmpty) {
      return semesterCode;
    }
    final activeSemester = await _scheduleRepository.loadActiveSemesterCode();
    if (activeSemester != null && activeSemester.isNotEmpty) {
      return activeSemester;
    }
    return _inferSemesterCode(DateTime.now());
  }

  String _inferSemesterCode(DateTime now) {
    final month = now.month;
    final year = now.year;
    if (month >= 8) {
      return '${year}1';
    }
    if (month <= 1) {
      return '${year - 1}1';
    }
    return '${year - 1}2';
  }

  Future<void> _refreshAvailableSemesters({String? additional}) async {
    final available = await _scheduleRepository.loadAvailableSemesterCodes();
    final merged = <String>{...available};
    if (additional != null && additional.isNotEmpty) {
      merged.add(additional);
    }
    _availableSemesterCodes = merged.toList()..sort((a, b) => b.compareTo(a));
  }

  ScheduleOverride? _findDisplayOverride(
    List<ScheduleOverride> overrides,
    int section,
  ) {
    for (final item in overrides) {
      if (item.status == ScheduleOverrideStatus.orphaned) continue;
      if ((item.type == ScheduleOverrideType.add ||
              item.type == ScheduleOverrideType.modify) &&
          item.startSection <= section &&
          item.endSection >= section) {
        return item;
      }
    }
    return null;
  }

  ScheduleOverride? _findTargetedOverride(
    List<ScheduleOverride> overrides,
    ScheduleSlot slot,
    ScheduleOverrideType type,
  ) {
    for (final item in overrides) {
      if (item.type != type) continue;
      if (item.status == ScheduleOverrideStatus.orphaned) continue;
      if (_matchesOverrideSource(item, slot)) {
        return item;
      }
    }
    return null;
  }

  _ResolvedOverrideSource? _resolveOverrideSourceSlot({
    required int week,
    required int weekday,
    required ScheduleOverride override,
  }) {
    for (final course in _courses) {
      for (final slot in course.slots) {
        if (slot.weekday != weekday || !slot.isActiveInWeek(week)) continue;
        if (!_matchesOverrideSource(override, slot)) continue;
        return _ResolvedOverrideSource(slot: slot, teacher: course.teacher);
      }
    }
    return null;
  }

  bool _matchesOverrideSource(ScheduleOverride item, ScheduleSlot slot) {
    if (item.targetCourseId != null && item.targetCourseId == slot.courseId) {
      return true;
    }
    final sourceStart = item.sourceStartSection ?? item.startSection;
    final sourceEnd = item.sourceEndSection ?? item.endSection;
    return slot.startSection == sourceStart && slot.endSection == sourceEnd;
  }

  ScheduleSlot _slotFromOverride(
    ScheduleOverride override, {
    ScheduleSlot? fallback,
  }) {
    final source = fallback;
    return ScheduleSlot(
      courseId: source?.courseId ?? override.id,
      courseName:
          override.courseName.isNotEmpty
              ? override.courseName
              : source?.courseName ?? '临时课程',
      teacher:
          override.teacher.isNotEmpty
              ? override.teacher
              : source?.teacher ?? '',
      weekday: override.weekday,
      startSection: override.startSection,
      endSection: override.endSection,
      location:
          override.location.isNotEmpty
              ? override.location
              : source?.location ?? '',
      weekRanges: source?.weekRanges ?? const <WeekRange>[],
    );
  }

  String _dateKeyFor(DateTime date) {
    final localDate = DateTime(date.year, date.month, date.day);
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    return '${localDate.year}-$month-$day';
  }

  Future<void> _revalidateOverridesForSemester(String? semesterCode) async {
    if (semesterCode == null || semesterCode.isEmpty) return;

    final updated =
        _overrides
            .map((item) => _validateOverride(item, semesterCode: semesterCode))
            .toList();
    final changed = !_sameOverrideStates(_overrides, updated);
    _overrides = updated;

    if (changed) {
      await _overrideRepository.save(
        semesterCode: semesterCode,
        overrides: _overrides,
      );
    }
  }

  ScheduleOverride _validateOverride(
    ScheduleOverride item, {
    required String semesterCode,
  }) {
    if (item.type == ScheduleOverrideType.add) {
      return _copyOverrideWithStatus(
        item,
        semesterCode: semesterCode,
        status: ScheduleOverrideStatus.normal,
      );
    }

    final week = _weekForDateKey(item.dateKey);
    if (week == null) {
      return _copyOverrideWithStatus(
        item,
        semesterCode: semesterCode,
        status: ScheduleOverrideStatus.orphaned,
      );
    }

    final matched = _courses.any((course) {
      for (final slot in course.slots) {
        if (slot.weekday != item.weekday) continue;
        if (!slot.isActiveInWeek(week)) continue;

        if (_matchesOverrideSource(item, slot)) {
          final effectiveTeacher =
              slot.teacher.isNotEmpty ? slot.teacher : course.teacher;
          final sourceNameMatches =
              item.sourceCourseName.isEmpty ||
              slot.courseName == item.sourceCourseName;
          final sourceTeacherMatches =
              item.sourceTeacher.isEmpty ||
              effectiveTeacher == item.sourceTeacher;
          final sourceLocationMatches =
              item.sourceLocation.isEmpty ||
              slot.location == item.sourceLocation;
          final sourceSectionMatches =
              (item.sourceStartSection == null ||
                  slot.startSection == item.sourceStartSection) &&
              (item.sourceEndSection == null ||
                  slot.endSection == item.sourceEndSection);

          return sourceNameMatches &&
              sourceTeacherMatches &&
              sourceLocationMatches &&
              sourceSectionMatches;
        }
      }
      return false;
    });

    return _copyOverrideWithStatus(
      item,
      semesterCode: semesterCode,
      status:
          matched
              ? ScheduleOverrideStatus.normal
              : ScheduleOverrideStatus.orphaned,
    );
  }

  ScheduleOverride _copyOverrideWithStatus(
    ScheduleOverride item, {
    required String semesterCode,
    required ScheduleOverrideStatus status,
  }) {
    return ScheduleOverride(
      id: item.id,
      semesterCode: semesterCode,
      dateKey: item.dateKey,
      weekday: item.weekday,
      startSection: item.startSection,
      endSection: item.endSection,
      type: item.type,
      targetCourseId: item.targetCourseId,
      courseName: item.courseName,
      teacher: item.teacher,
      location: item.location,
      note: item.note,
      status: status,
      sourceCourseName: item.sourceCourseName,
      sourceTeacher: item.sourceTeacher,
      sourceLocation: item.sourceLocation,
      sourceStartSection: item.sourceStartSection,
      sourceEndSection: item.sourceEndSection,
    );
  }

  int? _weekForDateKey(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;

    final date = DateTime(year, month, day);
    final week = _weekCalc.getWeekNumber(date);
    if (week < 1 || week > _weekCalc.totalWeeks) return null;
    return week;
  }

  bool _sameOverrideStates(
    List<ScheduleOverride> left,
    List<ScheduleOverride> right,
  ) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i].id != right[i].id || left[i].status != right[i].status) {
        return false;
      }
    }
    return true;
  }
}

class DisplayScheduleSlot {
  final ScheduleSlot slot;
  final String teacher;
  final bool isActive;
  final bool isOverride;
  final ScheduleOverrideType? overrideType;
  final ScheduleOverride? sourceOverride;

  const DisplayScheduleSlot({
    required this.slot,
    required this.teacher,
    required this.isActive,
    this.isOverride = false,
    this.overrideType,
    this.sourceOverride,
  });

  bool get isReferenceOnly => !isActive && overrideType == null;

  bool get canMarkCancel =>
      isActive &&
      overrideType != ScheduleOverrideType.add &&
      overrideType != ScheduleOverrideType.cancel;

  bool get canAdjustOccurrence =>
      !isReferenceOnly && overrideType != ScheduleOverrideType.cancel;
}

class _ResolvedOverrideSource {
  final ScheduleSlot slot;
  final String teacher;

  const _ResolvedOverrideSource({required this.slot, required this.teacher});
}
