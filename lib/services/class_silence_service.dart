import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/course.dart';
import '../models/schedule_override.dart';
import '../models/school_time.dart';
import '../utils/week_calculator.dart';

class ClassSilenceSettings {
  final bool enabled;

  const ClassSilenceSettings({required this.enabled});
}

class ClassSilenceSnapshot {
  final ClassSilenceSettings settings;
  final bool supported;
  final bool policyAccessGranted;
  final DateTime? lastBuildTime;
  final DateTime? horizonEnd;
  final int scheduledCount;

  const ClassSilenceSnapshot({
    required this.settings,
    required this.supported,
    required this.policyAccessGranted,
    this.lastBuildTime,
    this.horizonEnd,
    this.scheduledCount = 0,
  });
}

class ClassSilenceApplyResult {
  final ClassSilenceSnapshot snapshot;
  final String message;
  final bool policyAccessGranted;

  const ClassSilenceApplyResult({
    required this.snapshot,
    required this.message,
    required this.policyAccessGranted,
  });
}

class _ResolvedSilenceItem {
  final ScheduleSlot slot;

  const _ResolvedSilenceItem({required this.slot});
}

class ClassSilenceService {
  ClassSilenceService._();

  static const MethodChannel _channel = MethodChannel(
    'hai_schedule/class_silence',
  );

  static const String _enabledKey = 'class_silence_enabled';
  static const String _lastBuildTimeKey = 'class_silence_last_build_time';
  static const String _horizonEndKey = 'class_silence_horizon_end';
  static const String _scheduledCountKey = 'class_silence_scheduled_count';

  static const Duration _scheduleHorizon = Duration(days: 7);
  static const Duration _rebuildThreshold = Duration(days: 2);

  static bool _timezoneReady = false;

  static bool get isSupported => Platform.isAndroid;

  static Future<ClassSilenceSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return ClassSilenceSettings(enabled: prefs.getBool(_enabledKey) ?? false);
  }

  static Future<ClassSilenceSnapshot> loadSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = ClassSilenceSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
    );
    final policyAccessGranted = await hasPolicyAccess();
    return ClassSilenceSnapshot(
      settings: settings,
      supported: isSupported,
      policyAccessGranted: policyAccessGranted,
      lastBuildTime: _parseTime(prefs.getString(_lastBuildTimeKey)),
      horizonEnd: _parseTime(prefs.getString(_horizonEndKey)),
      scheduledCount: prefs.getInt(_scheduledCountKey) ?? 0,
    );
  }

  static Future<bool> hasPolicyAccess() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('hasPolicyAccess') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> openPolicyAccessSettings() async {
    if (!isSupported) return false;
    try {
      await _channel.invokeMethod<void>('openPolicyAccessSettings');
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static String permissionHelpText() {
    return '如果“去授权”没有直接打开对应页面，请手动进入：设置 > 应用 > 右上角三点/更多 > 特殊访问权限 > 勿扰权限（或免打扰权限），然后允许 hai_schedule 修改免打扰状态。不同 ROM 名称会略有差异。';
  }

  static Future<ClassSilenceApplyResult> updateEnabled({
    required bool enabled,
    required List<Course> courses,
    List<ScheduleOverride> overrides = const [],
    required WeekCalculator weekCalc,
    required SchoolTimeConfig timeConfig,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (!enabled) {
      await prefs.setBool(_enabledKey, false);
      await cancelSchedule();
      final snapshot = await loadSnapshot();
      return ClassSilenceApplyResult(
        snapshot: snapshot,
        message: '已关闭上课自动静音',
        policyAccessGranted: snapshot.policyAccessGranted,
      );
    }

    final policyAccessGranted = await hasPolicyAccess();
    if (!policyAccessGranted) {
      await prefs.setBool(_enabledKey, false);
      await openPolicyAccessSettings();
      final snapshot = await loadSnapshot();
      return ClassSilenceApplyResult(
        snapshot: snapshot,
        message: '请先授予免打扰权限，再重新开启上课自动静音',
        policyAccessGranted: false,
      );
    }

    await prefs.setBool(_enabledKey, true);

    return rebuildForSchedule(
      courses: courses,
      overrides: overrides,
      weekCalc: weekCalc,
      timeConfig: timeConfig,
      enabledOverride: true,
    );
  }

  static Future<ClassSilenceApplyResult> rebuildForSchedule({
    required List<Course> courses,
    List<ScheduleOverride> overrides = const [],
    required WeekCalculator weekCalc,
    required SchoolTimeConfig timeConfig,
    bool? enabledOverride,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final settings = await loadSettings();
    final enabled = enabledOverride ?? settings.enabled;

    if (!isSupported) {
      final snapshot = await loadSnapshot();
      return ClassSilenceApplyResult(
        snapshot: snapshot,
        message: '当前平台暂不支持上课自动静音',
        policyAccessGranted: false,
      );
    }

    if (!enabled) {
      await cancelSchedule();
      final snapshot = await loadSnapshot();
      return ClassSilenceApplyResult(
        snapshot: snapshot,
        message: '上课自动静音未开启',
        policyAccessGranted: await hasPolicyAccess(),
      );
    }

    final policyAccessGranted = await hasPolicyAccess();
    if (!policyAccessGranted) {
      await cancelSchedule();
      final snapshot = await loadSnapshot();
      return ClassSilenceApplyResult(
        snapshot: snapshot,
        message: '缺少免打扰权限，无法自动静音',
        policyAccessGranted: false,
      );
    }

    final now = _nowInSchoolTimezone();
    final horizonEnd = now.add(_scheduleHorizon);
    final events = _buildEvents(
      courses: courses,
      overrides: overrides,
      weekCalc: weekCalc,
      timeConfig: timeConfig,
      now: now,
      horizonEnd: horizonEnd,
    );

    try {
      await _channel.invokeMethod<void>('configureSchedule', <String, dynamic>{
        'events': events,
      });
    } on MissingPluginException {
      final snapshot = await loadSnapshot();
      return ClassSilenceApplyResult(
        snapshot: snapshot,
        message: '当前设备暂不支持自动静音',
        policyAccessGranted: false,
      );
    } on PlatformException catch (e) {
      final snapshot = await loadSnapshot();
      return ClassSilenceApplyResult(
        snapshot: snapshot,
        message: e.message ?? '自动静音调度失败',
        policyAccessGranted: policyAccessGranted,
      );
    }

    await prefs.setString(_lastBuildTimeKey, DateTime.now().toIso8601String());
    await prefs.setString(_horizonEndKey, horizonEnd.toIso8601String());
    await prefs.setInt(_scheduledCountKey, events.length);

    final snapshot = await loadSnapshot();
    return ClassSilenceApplyResult(
      snapshot: snapshot,
      message:
          events.isEmpty ? '未来 7 天内没有需要静音的课程' : '已安排 ${events.length} 条静音时段',
      policyAccessGranted: true,
    );
  }

  static Future<void> ensureCoverage({
    required List<Course> courses,
    List<ScheduleOverride> overrides = const [],
    required WeekCalculator weekCalc,
    required SchoolTimeConfig timeConfig,
  }) async {
    if (!isSupported) return;
    final snapshot = await loadSnapshot();
    if (!snapshot.settings.enabled || !snapshot.policyAccessGranted) return;

    final now = _nowInSchoolTimezone();
    if (snapshot.horizonEnd != null &&
        snapshot.horizonEnd!.isAfter(now.add(_rebuildThreshold))) {
      return;
    }

    await rebuildForSchedule(
      courses: courses,
      overrides: overrides,
      weekCalc: weekCalc,
      timeConfig: timeConfig,
    );
  }

  static Future<void> cancelSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await _channel.invokeMethod<void>('cancelSchedule');
    } on MissingPluginException {
      // Ignore in unsupported environments.
    } on PlatformException {
      // Ignore here, state should still be cleared.
    }
    await prefs.remove(_lastBuildTimeKey);
    await prefs.remove(_horizonEndKey);
    await prefs.setInt(_scheduledCountKey, 0);
  }

  static Future<String> startManualTest({int durationMinutes = 1}) async {
    if (!isSupported) return '当前平台暂不支持自动静音';
    final granted = await hasPolicyAccess();
    if (!granted) {
      return '缺少免打扰权限，无法开始测试';
    }

    try {
      await _channel.invokeMethod<void>('startManualTest', <String, dynamic>{
        'durationMinutes': durationMinutes,
      });
      return '已开始测试静音，${durationMinutes.clamp(1, 10)} 分钟后自动恢复';
    } on MissingPluginException {
      return '当前设备暂不支持自动静音';
    } on PlatformException catch (e) {
      return e.message ?? '测试静音失败';
    }
  }

  static Future<String> restoreNow() async {
    if (!isSupported) return '当前平台暂不支持自动静音';
    try {
      await _channel.invokeMethod<void>('restoreNow');
      return '已恢复到测试前状态';
    } on MissingPluginException {
      return '当前设备暂不支持自动静音';
    } on PlatformException catch (e) {
      return e.message ?? '恢复失败';
    }
  }

  static List<Map<String, dynamic>> _buildEvents({
    required List<Course> courses,
    required List<ScheduleOverride> overrides,
    required WeekCalculator weekCalc,
    required SchoolTimeConfig timeConfig,
    required tz.TZDateTime now,
    required tz.TZDateTime horizonEnd,
  }) {
    final events = <Map<String, dynamic>>[];
    final startDate = DateTime(now.year, now.month, now.day);
    final totalDays = horizonEnd.difference(now).inDays + 1;

    for (var offset = 0; offset < totalDays; offset++) {
      final day = startDate.add(Duration(days: offset));
      final week = weekCalc.getWeekNumber(day);
      if (week <= 0 || week > weekCalc.totalWeeks) continue;

      final items = _resolveDaySchedule(
        day: day,
        week: week,
        courses: courses,
        overrides: overrides,
      );

      for (final item in items) {
        final slotTime = timeConfig.getSlotTime(
          item.slot.startSection,
          item.slot.endSection,
        );
        if (slotTime == null) continue;

        final startParts = slotTime.$1.split(':');
        final endParts = slotTime.$2.split(':');
        if (startParts.length != 2 || endParts.length != 2) continue;

        final startHour = int.tryParse(startParts[0]);
        final startMinute = int.tryParse(startParts[1]);
        final endHour = int.tryParse(endParts[0]);
        final endMinute = int.tryParse(endParts[1]);
        if (startHour == null ||
            startMinute == null ||
            endHour == null ||
            endMinute == null) {
          continue;
        }

        final classStart = tz.TZDateTime(
          _schoolLocation,
          day.year,
          day.month,
          day.day,
          startHour,
          startMinute,
        );
        final classEnd = tz.TZDateTime(
          _schoolLocation,
          day.year,
          day.month,
          day.day,
          endHour,
          endMinute,
        );

        if (!classEnd.isAfter(now)) continue;
        if (classStart.isAfter(horizonEnd)) continue;

        events.add(<String, dynamic>{
          'id':
              '${_formatDate(day)}-${item.slot.courseId}-${item.slot.startSection}-${item.slot.endSection}',
          'courseName': item.slot.courseName,
          'date': _formatDate(day),
          'startSection': item.slot.startSection,
          'endSection': item.slot.endSection,
          'startAtMillis': classStart.millisecondsSinceEpoch,
          'endAtMillis': classEnd.millisecondsSinceEpoch,
        });
      }
    }

    events.sort(
      (a, b) =>
          (a['startAtMillis'] as int).compareTo(b['startAtMillis'] as int),
    );
    return events;
  }

  static List<_ResolvedSilenceItem> _resolveDaySchedule({
    required DateTime day,
    required int week,
    required List<Course> courses,
    required List<ScheduleOverride> overrides,
  }) {
    final dateKey = _formatDate(day);
    final weekday = day.weekday;
    final dayOverrides =
        overrides
            .where((item) => item.dateKey == dateKey && item.weekday == weekday)
            .toList();

    final items = <_ResolvedSilenceItem>[];

    for (final course in courses) {
      for (final slot in course.slots) {
        if (slot.weekday != weekday || !slot.isActiveInWeek(week)) continue;

        var cancelled = false;
        for (final item in dayOverrides) {
          if (item.type != ScheduleOverrideType.cancel) continue;
          if (item.status == ScheduleOverrideStatus.orphaned) continue;
          final matchesCourse =
              item.targetCourseId != null &&
              item.targetCourseId == slot.courseId;
          final sourceStart = item.sourceStartSection ?? item.startSection;
          final sourceEnd = item.sourceEndSection ?? item.endSection;
          final matchesSections =
              sourceStart == slot.startSection && sourceEnd == slot.endSection;
          if (matchesCourse || matchesSections) {
            cancelled = true;
            break;
          }
        }
        if (cancelled) continue;

        ScheduleOverride? modifyOverride;
        for (final item in dayOverrides) {
          if (item.type != ScheduleOverrideType.modify) continue;
          if (item.status == ScheduleOverrideStatus.orphaned) continue;
          final sourceStart = item.sourceStartSection ?? item.startSection;
          final sourceEnd = item.sourceEndSection ?? item.endSection;
          if ((item.targetCourseId != null &&
                  item.targetCourseId == slot.courseId) ||
              (sourceStart == slot.startSection &&
                  sourceEnd == slot.endSection)) {
            modifyOverride = item;
            break;
          }
        }

        if (modifyOverride != null) {
          items.add(
            _ResolvedSilenceItem(
              slot: ScheduleSlot(
                courseId: slot.courseId,
                courseName:
                    modifyOverride.courseName.isNotEmpty
                        ? modifyOverride.courseName
                        : slot.courseName,
                teacher:
                    modifyOverride.teacher.isNotEmpty
                        ? modifyOverride.teacher
                        : slot.teacher,
                weekday: weekday,
                startSection: modifyOverride.startSection,
                endSection: modifyOverride.endSection,
                location:
                    modifyOverride.location.isNotEmpty
                        ? modifyOverride.location
                        : slot.location,
                weekRanges: slot.weekRanges,
              ),
            ),
          );
          continue;
        }

        items.add(_ResolvedSilenceItem(slot: slot));
      }
    }

    for (final item in dayOverrides.where(
      (value) =>
          value.type == ScheduleOverrideType.add &&
          value.status != ScheduleOverrideStatus.orphaned,
    )) {
      items.add(
        _ResolvedSilenceItem(
          slot: ScheduleSlot(
            courseId: item.id,
            courseName: item.courseName.isNotEmpty ? item.courseName : '临时课程',
            teacher: item.teacher,
            weekday: weekday,
            startSection: item.startSection,
            endSection: item.endSection,
            location: item.location,
            weekRanges: const <WeekRange>[],
          ),
        ),
      );
    }

    items.sort((a, b) => a.slot.startSection.compareTo(b.slot.startSection));
    return items;
  }

  static DateTime? _parseTime(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  static void _ensureTimezoneReady() {
    if (_timezoneReady) return;
    tz.initializeTimeZones();
    final location = tz.getLocation('Asia/Shanghai');
    tz.setLocalLocation(location);
    _timezoneReady = true;
  }

  static tz.TZDateTime _nowInSchoolTimezone() {
    _ensureTimezoneReady();
    return tz.TZDateTime.now(_schoolLocation);
  }

  static String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  static tz.Location get _schoolLocation {
    _ensureTimezoneReady();
    return tz.getLocation('Asia/Shanghai');
  }
}
