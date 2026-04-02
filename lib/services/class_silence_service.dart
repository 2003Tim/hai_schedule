import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/class_silence_models.dart';
import '../models/course.dart';
import '../models/schedule_override.dart';
import '../models/school_time.dart';
import '../utils/class_silence_planner.dart';
import '../utils/week_calculator.dart';

export '../models/class_silence_models.dart';

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
    return '如果“去授权”没有直接打开对应页面，请手动进入：设置 > 应用 > 右上角更多 > 特殊访问权限 > 勿扰权限（或免打扰权限），然后允许 hai_schedule 修改免打扰状态。不同 ROM 的名称会略有差异。';
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
    final events = ClassSilencePlanner.buildEvents(
      courses: courses,
      overrides: overrides,
      weekCalc: weekCalc,
      timeConfig: timeConfig,
      now: now,
      horizonEnd: horizonEnd,
      location: _schoolLocation,
    );

    try {
      await _channel.invokeMethod<void>('configureSchedule', <String, dynamic>{
        'events': events.map((event) => event.toJson()).toList(),
      });
    } on MissingPluginException {
      final snapshot = await loadSnapshot();
      return ClassSilenceApplyResult(
        snapshot: snapshot,
        message: '当前设备暂不支持自动静音',
        policyAccessGranted: false,
      );
    } on PlatformException catch (error) {
      final snapshot = await loadSnapshot();
      return ClassSilenceApplyResult(
        snapshot: snapshot,
        message: error.message ?? '自动静音调度失败',
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
    } on PlatformException catch (error) {
      return error.message ?? '测试静音失败';
    }
  }

  static Future<String> restoreNow() async {
    if (!isSupported) return '当前平台暂不支持自动静音';
    try {
      await _channel.invokeMethod<void>('restoreNow');
      return '已恢复到测试前状态';
    } on MissingPluginException {
      return '当前设备暂不支持自动静音';
    } on PlatformException catch (error) {
      return error.message ?? '恢复失败';
    }
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

  static tz.Location get _schoolLocation {
    _ensureTimezoneReady();
    return tz.getLocation('Asia/Shanghai');
  }
}
