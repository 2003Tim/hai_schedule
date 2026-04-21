import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/display_schedule_slot.dart';
import 'package:hai_schedule/models/semester_option.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/models/schedule_parser.dart';
import 'package:hai_schedule/models/school_time.dart';
import 'package:hai_schedule/utils/schedule_display_slot_resolver.dart';
import 'package:hai_schedule/utils/schedule_override_validator.dart';
import 'package:hai_schedule/utils/week_calculator.dart';
import 'package:hai_schedule/services/app_repositories.dart';
import 'package:hai_schedule/services/schedule_derived_output_coordinator.dart';
import 'package:hai_schedule/services/schedule_state_loader.dart';

export '../models/display_schedule_slot.dart';

enum ScheduleTodayNavigationResult { success, outOfRange }

class ScheduleProvider extends ChangeNotifier {
  final ScheduleRepository _scheduleRepository = ScheduleRepository();
  final SchedulePreferencesRepository _preferencesRepository =
      SchedulePreferencesRepository();
  final ScheduleOverrideRepository _overrideRepository =
      ScheduleOverrideRepository();
  final SchoolTimeRepository _schoolTimeRepository = SchoolTimeRepository();
  final ScheduleStateLoader _stateLoader = ScheduleStateLoader();
  final ScheduleDerivedOutputCoordinator _derivedOutputCoordinator =
      const ScheduleDerivedOutputCoordinator();

  List<Course> _courses = [];
  List<ScheduleOverride> _overrides = [];
  final Map<String, List<DisplayScheduleSlot>> _displaySlotCache = {};
  int _currentWeek = 1;
  int _selectedWeek = 0;
  late WeekCalculator _weekCalc;
  late SchoolTimeConfig _timeConfig;
  String? _currentSemesterCode;
  List<String> _availableSemesterCodes = const [];
  List<SemesterOption> _availableSemesterOptions = const [];
  List<SemesterOption> _knownSemesterCatalog = const [];
  bool _hasSyncedAtLeastOneSemester = false;
  late final Future<void> ready = _bootstrap();

  int _displayDays = 7;
  bool _showNonCurrentWeek = true;
  bool _isSettingCourses = false;

  List<Course> get courses => _courses;
  List<ScheduleOverride> get overrides => _overrides;
  int get currentWeek => _currentWeek;
  int get selectedWeek => _selectedWeek;
  WeekCalculator get weekCalc => _weekCalc;
  SchoolTimeConfig get timeConfig => _timeConfig;
  int get todayWeekday => _weekCalc.getTodayWeekday();
  String? get currentSemesterCode => _currentSemesterCode;
  List<String> get availableSemesterCodes => _availableSemesterCodes;
  List<SemesterOption> get availableSemesterOptions =>
      _availableSemesterOptions;
  List<SemesterOption> get knownSemesterCatalog => _knownSemesterCatalog;
  bool get hasSyncedAtLeastOneSemester => _hasSyncedAtLeastOneSemester;
  int get displayDays => _displayDays;
  bool get showNonCurrentWeek => _showNonCurrentWeek;

  ScheduleProvider() {
    _timeConfig = SchoolTimeConfig.hainanuDefault();
    _applySemesterContext(null);
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

  ScheduleTodayNavigationResult goToToday([DateTime? date]) {
    final targetDate = DateUtils.dateOnly(date ?? DateTime.now());
    if (!isDateWithinActiveSemester(targetDate)) {
      return ScheduleTodayNavigationResult.outOfRange;
    }

    _currentWeek = _weekCalc.getWeekNumber(targetDate);
    _selectedWeek = _currentWeek.clamp(1, _weekCalc.totalWeeks);
    notifyListeners();
    return ScheduleTodayNavigationResult.success;
  }

  ScheduleTodayNavigationResult goToCurrentWeek([DateTime? date]) {
    return goToToday(date);
  }

  void setDisplayDays(int days) {
    _displayDays = days;
    unawaited(_savePreferences());
    notifyListeners();
  }

  void toggleShowNonCurrentWeek() {
    _showNonCurrentWeek = !_showNonCurrentWeek;
    unawaited(_savePreferences());
    notifyListeners();
  }

  Future<void> switchSemester(String semesterCode) async {
    if (semesterCode.isEmpty || semesterCode == _currentSemesterCode) return;

    await _scheduleRepository.saveActiveSemesterCode(semesterCode);
    await _restorePersistedState();
  }

  Future<void> createSemester(String semesterCode) async {
    final normalized = semesterCode.trim();
    if (normalized.isEmpty) return;
    await _scheduleRepository.createEmptySemester(
      semesterCode: normalized,
      makeActive: true,
    );
    await _restorePersistedState();
  }

  Future<void> deleteSemester(String semesterCode) async {
    if (semesterCode.isEmpty) return;
    await _scheduleRepository.deleteSemester(semesterCode);
    await _restorePersistedState();
  }

  Future<void> reloadFromStorage() async {
    await _restorePersistedState();
  }

  Future<void> mergeKnownSemesterOptions(List<SemesterOption> options) async {
    final currentOptions = await _scheduleRepository.loadKnownSemesterOptions();
    final merged = <String, SemesterOption>{};

    for (final option in currentOptions) {
      if (!option.isValid) continue;
      merged[option.normalizedCode] = SemesterOption(
        code: option.normalizedCode,
        name: option.normalizedName,
      );
    }

    for (final option in options) {
      if (!option.isValid) continue;
      final existing = merged[option.normalizedCode];
      final normalized = SemesterOption(
        code: option.normalizedCode,
        name: option.normalizedName,
      );
      merged[option.normalizedCode] =
          normalized.normalizedName.isNotEmpty
              ? normalized
              : (existing ?? normalized);
    }

    final nextOptions =
        merged.values.toList()..sort(
          (left, right) => right.normalizedCode.compareTo(left.normalizedCode),
        );
    if (_knownSemesterCatalog.length == nextOptions.length &&
        _knownSemesterCatalog.every(nextOptions.contains)) {
      return;
    }

    await _scheduleRepository.saveKnownSemesterOptions(nextOptions);
    _knownSemesterCatalog = nextOptions;
    _availableSemesterOptions = await _stateLoader.loadAvailableSemesterOptions(
      additional: _currentSemesterCode,
    );
    notifyListeners();
  }

  Future<void> markHasSyncedAtLeastOneSemester() async {
    if (_hasSyncedAtLeastOneSemester) {
      return;
    }
    await _scheduleRepository.saveHasSyncedAtLeastOneSemester(true);
    _hasSyncedAtLeastOneSemester = true;
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
    return ScheduleDisplaySlotResolver.resolve(
      week: week,
      weekday: weekday,
      section: section,
      courses: _courses,
      overrides: _overrides,
      weekCalc: _weekCalc,
      showNonCurrentWeek: _showNonCurrentWeek,
    );
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
    return ScheduleDisplaySlotResolver.teacherForSlot(
      courses: _courses,
      slot: slot,
    );
  }

  DateTime getDateForSlot(int week, int weekday) =>
      _weekCalc.getDate(week, weekday);

  bool isDateWithinActiveSemester(DateTime date) {
    final targetDate = DateUtils.dateOnly(date);
    final semesterStart = DateUtils.dateOnly(_weekCalc.semesterStart);
    final semesterEnd = semesterStart.add(
      Duration(days: (_weekCalc.totalWeeks * 7) - 1),
    );
    return !targetDate.isBefore(semesterStart) &&
        !targetDate.isAfter(semesterEnd);
  }

  ScheduleOverride? getOverrideForDateSlot(
    DateTime date,
    int weekday,
    int section,
  ) {
    return ScheduleDisplaySlotResolver.overrideForDateSlot(
      date: date,
      weekday: weekday,
      section: section,
      overrides: _overrides,
    );
  }

  Future<void> upsertOverride(ScheduleOverride override) async {
    final semesterCode = await _stateLoader.resolveTargetSemesterCode(
      _currentSemesterCode,
    );
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
    final semesterCode = await _stateLoader.resolveTargetSemesterCode(
      _currentSemesterCode,
    );
    _overrides = _overrides.where((item) => item.id != overrideId).toList();
    await _overrideRepository.save(
      semesterCode: semesterCode,
      overrides: _overrides,
    );
    await _syncDerivedOutputs(forceReminderRebuild: true);
    notifyListeners();
  }

  Future<void> importFromJson(String jsonString, {String? semesterCode}) async {
    final Object? decoded;
    try {
      decoded = json.decode(jsonString);
    } catch (_) {
      throw const FormatException('JSON 格式无效，请检查内容');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('JSON 顶层结构必须是对象（{}），而非数组或其他类型');
    }
    final courses = ScheduleParser.parseApiResponse(decoded);
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
    if (_isSettingCourses) return;
    _isSettingCourses = true;
    try {
      final resolvedSemester = await _stateLoader.resolveTargetSemesterCode(
        semesterCode,
      );
      final semesterStart = _stateLoader.inferSemesterStartFromRawScheduleJson(
        rawScheduleJson,
        semesterCode: resolvedSemester,
      );
      _courses = courses;
      _currentSemesterCode = resolvedSemester;
      _availableSemesterCodes = await _stateLoader.loadAvailableSemesterCodes(
        additional: resolvedSemester,
      );
      _availableSemesterOptions = await _stateLoader
          .loadAvailableSemesterOptions(additional: resolvedSemester);
      _applySemesterContext(
        resolvedSemester,
        semesterStartOverride: semesterStart,
      );
      await _scheduleRepository.saveSemesterSchedule(
        semesterCode: resolvedSemester,
        rawScheduleJson: rawScheduleJson,
        courses: courses,
        makeActive: true,
      );
      await _revalidateOverridesForSemester(resolvedSemester);
      await _syncDerivedOutputs(forceReminderRebuild: true);
      notifyListeners();
    } finally {
      _isSettingCourses = false;
    }
  }

  Future<void> _bootstrap() async {
    await _restorePersistedState();
  }

  Future<void> _restorePersistedState() async {
    final state = await _stateLoader.load();
    _applyLoadedState(state);
    await _revalidateOverridesForSemester(state.currentSemesterCode);
    await _syncDerivedOutputs(forceReminderRebuild: true);
    notifyListeners();
  }

  Future<void> _savePreferences() async {
    await _preferencesRepository.save(
      displayDays: _displayDays,
      showNonCurrentWeek: _showNonCurrentWeek,
    );
  }

  Future<void> _syncDerivedOutputs({bool forceReminderRebuild = false}) async {
    await _derivedOutputCoordinator.sync(
      courses: _courses,
      overrides: _overrides,
      weekCalc: _weekCalc,
      timeConfig: _timeConfig,
      forceReminderRebuild: forceReminderRebuild,
    );
  }

  void _applySemesterContext(
    String? semesterCode, {
    DateTime? semesterStartOverride,
  }) {
    _weekCalc =
        semesterStartOverride == null
            ? WeekCalculator.hainanuSemester(semesterCode)
            : WeekCalculator(semesterStart: semesterStartOverride);
    _currentWeek = _weekCalc.getWeekNumber();
    final desiredWeek = _selectedWeek == 0 ? _currentWeek : _selectedWeek;
    _selectedWeek = desiredWeek.clamp(1, _weekCalc.totalWeeks);
  }

  Future<void> _revalidateOverridesForSemester(String? semesterCode) async {
    if (semesterCode == null || semesterCode.isEmpty) return;

    final result = ScheduleOverrideValidator.revalidate(
      overrides: _overrides,
      courses: _courses,
      semesterCode: semesterCode,
      weekCalc: _weekCalc,
    );
    _overrides = result.overrides;

    if (result.changed) {
      await _overrideRepository.save(
        semesterCode: semesterCode,
        overrides: _overrides,
      );
    }
  }

  void _applyLoadedState(LoadedScheduleState state) {
    _courses = state.courses;
    _overrides = state.overrides;
    _timeConfig = state.timeConfig;
    _currentSemesterCode = state.currentSemesterCode;
    _availableSemesterCodes = state.availableSemesterCodes;
    _availableSemesterOptions = state.availableSemesterOptions;
    _knownSemesterCatalog = state.knownSemesterCatalog;
    _hasSyncedAtLeastOneSemester = state.hasSyncedAtLeastOneSemester;
    _displayDays = state.displayDays;
    _showNonCurrentWeek = state.showNonCurrentWeek;
    _applySemesterContext(
      state.currentSemesterCode,
      semesterStartOverride: state.semesterStart,
    );
  }
}
