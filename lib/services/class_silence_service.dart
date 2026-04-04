import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'package:hai_schedule/models/class_silence_models.dart';
import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/models/school_time.dart';
import 'package:hai_schedule/utils/schedule_projection_payload.dart';
import 'package:hai_schedule/utils/week_calculator.dart';
import 'package:hai_schedule/services/app_repositories.dart';

export '../models/class_silence_models.dart';

class ClassSilenceService {
  ClassSilenceService._();

  static const MethodChannel _channel = MethodChannel(
    'hai_schedule/class_silence',
  );
  static const Duration _rebuildThreshold = Duration(days: 2);

  static final ClassSilenceRepository _repository = ClassSilenceRepository();

  static bool get isSupported => Platform.isAndroid;

  static Future<ClassSilenceSettings> loadSettings() async {
    final record = await _repository.loadState();
    return ClassSilenceSettings(enabled: record.enabled);
  }

  static Future<ClassSilenceSnapshot> loadSnapshot() async {
    final record = await _repository.loadState();
    final policyAccessGranted = await hasPolicyAccess();
    return ClassSilenceSnapshot(
      settings: ClassSilenceSettings(enabled: record.enabled),
      supported: isSupported,
      policyAccessGranted: policyAccessGranted,
      lastBuildTime: record.lastBuildTime,
      horizonEnd: record.horizonEnd,
      scheduledCount: record.scheduledCount,
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
    return '如果“去授权”没有直接打开对应页面，请手动进入：设置 > 应用 > 特殊权限访问 > 勿扰权限，然后允许 hai_schedule 修改勿扰状态。不同 ROM 的入口名称可能略有差异。';
  }

  static Future<ClassSilenceApplyResult> updateEnabled({
    required bool enabled,
    required List<Course> courses,
    List<ScheduleOverride> overrides = const [],
    required WeekCalculator weekCalc,
    required SchoolTimeConfig timeConfig,
  }) async {
    if (!enabled) {
      await _repository.saveEnabled(false);
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
      await _repository.saveEnabled(false);
      await openPolicyAccessSettings();
      final snapshot = await loadSnapshot();
      return ClassSilenceApplyResult(
        snapshot: snapshot,
        message: '请先授予勿扰权限，再重新开启上课自动静音',
        policyAccessGranted: false,
      );
    }

    await _repository.saveEnabled(true);
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
        message: '缺少勿扰权限，无法自动静音',
        policyAccessGranted: false,
      );
    }

    await _repository.saveEnabled(true);
    final payload = ScheduleProjectionPayload.build(
      courses: courses,
      overrides: overrides,
      weekCalc: weekCalc,
      timeConfig: timeConfig,
    );

    try {
      await _channel.invokeMethod<void>(
        'rebuildFromProjection',
        <String, dynamic>{'payload': jsonEncode(payload)},
      );
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

    final snapshot = await loadSnapshot();
    return ClassSilenceApplyResult(
      snapshot: snapshot,
      message:
          snapshot.scheduledCount == 0
              ? '未来 7 天内没有需要静音的课程'
              : '已安排 ${snapshot.scheduledCount} 条静音时段',
      policyAccessGranted: snapshot.policyAccessGranted,
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

    final horizonEnd = snapshot.horizonEnd;
    if (horizonEnd != null &&
        horizonEnd.isAfter(DateTime.now().add(_rebuildThreshold))) {
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
    try {
      await _channel.invokeMethod<void>('cancelSchedule');
    } on MissingPluginException {
      // Ignore in unsupported environments.
    } on PlatformException {
      // Ignore here, state should still be cleared.
    }
    await _repository.saveState(
      scheduledCount: 0,
      clearLastBuildTime: true,
      clearHorizonEnd: true,
    );
  }

  static Future<String> startManualTest({int durationMinutes = 1}) async {
    if (!isSupported) return '当前平台暂不支持自动静音';
    final granted = await hasPolicyAccess();
    if (!granted) {
      return '缺少勿扰权限，无法开始测试';
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
}
