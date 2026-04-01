import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/course.dart';
import '../models/schedule_parser.dart';
import 'api_service.dart';
import 'app_repositories.dart';
import 'auth_credentials_service.dart';
import 'schedule_provider.dart';

enum AutoSyncFrequency {
  manual('manual', '仅手动'),
  daily('daily', '每天'),
  weekly('weekly', '每周'),
  monthly('monthly', '每月'),
  custom('custom', '自定义');

  final String value;
  final String label;
  const AutoSyncFrequency(this.value, this.label);

  static AutoSyncFrequency fromValue(String? value) {
    return AutoSyncFrequency.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AutoSyncFrequency.daily,
    );
  }
}

enum AutoSyncState {
  idle('idle'),
  syncing('syncing'),
  success('success'),
  failed('failed'),
  loginRequired('login_required');

  final String value;
  const AutoSyncState(this.value);

  static AutoSyncState fromValue(String? value) {
    return AutoSyncState.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AutoSyncState.idle,
    );
  }
}

class AutoSyncSettings {
  final AutoSyncFrequency frequency;
  final int customIntervalMinutes;

  const AutoSyncSettings({
    required this.frequency,
    required this.customIntervalMinutes,
  });

  bool get backgroundEnabled => frequency != AutoSyncFrequency.manual;

  Duration get interval {
    switch (frequency) {
      case AutoSyncFrequency.manual:
        return const Duration(days: 36500);
      case AutoSyncFrequency.daily:
        return const Duration(days: 1);
      case AutoSyncFrequency.weekly:
        return const Duration(days: 7);
      case AutoSyncFrequency.monthly:
        return const Duration(days: 30);
      case AutoSyncFrequency.custom:
        return Duration(minutes: customIntervalMinutes);
    }
  }
}

class AutoSyncSnapshot {
  final AutoSyncSettings settings;
  final AutoSyncState state;
  final String message;
  final DateTime? lastFetchTime;
  final DateTime? lastAttemptTime;
  final DateTime? nextSyncTime;
  final String? lastError;
  final String? lastSource;
  final String? lastDiffSummary;
  final bool credentialReady;

  const AutoSyncSnapshot({
    required this.settings,
    required this.state,
    required this.message,
    this.lastFetchTime,
    this.lastAttemptTime,
    this.nextSyncTime,
    this.lastError,
    this.lastSource,
    this.lastDiffSummary,
    this.credentialReady = false,
  });

  bool get requiresLogin => state == AutoSyncState.loginRequired;
}

class AutoSyncResult {
  final bool attempted;
  final bool didSync;
  final bool requiresLogin;
  final int? courseCount;
  final String message;
  final AutoSyncSnapshot snapshot;

  const AutoSyncResult({
    required this.attempted,
    required this.didSync,
    required this.requiresLogin,
    required this.message,
    required this.snapshot,
    this.courseCount,
  });

  factory AutoSyncResult.skipped(String message, AutoSyncSnapshot snapshot) {
    return AutoSyncResult(
      attempted: false,
      didSync: false,
      requiresLogin: false,
      message: message,
      snapshot: snapshot,
    );
  }

  factory AutoSyncResult.loginRequired(String message, AutoSyncSnapshot snapshot) {
    return AutoSyncResult(
      attempted: true,
      didSync: false,
      requiresLogin: true,
      message: message,
      snapshot: snapshot,
    );
  }

  factory AutoSyncResult.failed(String message, AutoSyncSnapshot snapshot) {
    return AutoSyncResult(
      attempted: true,
      didSync: false,
      requiresLogin: false,
      message: message,
      snapshot: snapshot,
    );
  }

  factory AutoSyncResult.success(int count, String message, AutoSyncSnapshot snapshot) {
    return AutoSyncResult(
      attempted: true,
      didSync: true,
      requiresLogin: false,
      message: message,
      snapshot: snapshot,
      courseCount: count,
    );
  }
}

class AutoSyncService {
  static const MethodChannel _channel = MethodChannel('hai_schedule/auto_sync');
  static const String _baseUrl = 'https://ehall.hainanu.edu.cn';
  static const String _indexUrl =
      'https://ehall.hainanu.edu.cn/gsapp/sys/wdkbapp/*default/index.do';
  static const String _apiUrl =
      'https://ehall.hainanu.edu.cn/gsapp/sys/wdkbapp/modules/xskcb/xsjxrwcx.do';

  static const Duration retryBackoff = Duration(minutes: 30);
  static const int defaultCustomIntervalMinutes = 12 * 60;
  static const int minCustomIntervalMinutes = 60;
  static const int maxCustomIntervalMinutes = 30 * 24 * 60;

  static final ScheduleRepository _scheduleRepository = ScheduleRepository();
  static final SyncRepository _syncRepository = SyncRepository();
  static bool _isRunning = false;

  static bool get _supportsTimedAutoSync => Platform.isAndroid || Platform.isWindows;
  static bool get supportsForegroundDesktopAutoSync => Platform.isWindows;

  static Future<AutoSyncSettings> loadSettings() async {
    final record = await _syncRepository.loadRecord();
    return AutoSyncSettings(
      frequency: AutoSyncFrequency.fromValue(record.frequency),
      customIntervalMinutes: normalizeCustomIntervalMinutes(
        record.customIntervalMinutes,
      ),
    );
  }

  static Future<void> saveSettings(
    AutoSyncFrequency frequency, {
    int? customIntervalMinutes,
  }) async {
    if (frequency != AutoSyncFrequency.manual && !await hasCredentialReady()) {
      throw StateError('请先“登录并刷新课表”一次，再开启自动同步');
    }

    final normalizedCustomIntervalMinutes = frequency == AutoSyncFrequency.custom
        ? normalizeCustomIntervalMinutes(customIntervalMinutes)
        : null;
    final nextSettings = AutoSyncSettings(
      frequency: frequency,
      customIntervalMinutes:
          normalizedCustomIntervalMinutes ?? defaultCustomIntervalMinutes,
    );
    await _syncRepository.saveFrequency(
      frequency.value,
      customIntervalMinutes: normalizedCustomIntervalMinutes,
    );
    await _syncRepository.saveStatus(
      state: AutoSyncState.idle.value,
      message: frequency == AutoSyncFrequency.manual
          ? '已切换为仅手动同步'
          : '已切换为${describeSettings(nextSettings)}',
      clearError: true,
    );

    await _configureBackgroundSync(
      enabled: frequency != AutoSyncFrequency.manual,
      frequency: frequency,
      customIntervalMinutes: normalizedCustomIntervalMinutes,
      afterSuccessfulSync: false,
      preserveExistingCustomSchedule: false,
    );
  }

  static Future<void> ensureBackgroundSchedule() async {
    if (!_supportsTimedAutoSync) return;
    final settings = await loadSettings();
    final ready = await hasCredentialReady();
    await _configureBackgroundSync(
      enabled: ready && settings.backgroundEnabled,
      frequency: settings.frequency,
      customIntervalMinutes: settings.customIntervalMinutes,
      afterSuccessfulSync: false,
      preserveExistingCustomSchedule: true,
    );
  }

  static Future<void> recordExternalSyncSuccess({
    required int courseCount,
    required String source,
    String? diffSummary,
  }) async {
    final now = DateTime.now();
    final successMessage = _buildSuccessMessage(courseCount, diffSummary);
    await _syncRepository.saveStatus(
      lastFetchTime: now,
      lastAttemptTime: now,
      state: AutoSyncState.success.value,
      source: source,
      message: successMessage,
      diffSummary: diffSummary,
      clearError: true,
    );
    final settings = await loadSettings();
    final ready = await hasCredentialReady();
    await _configureBackgroundSync(
      enabled: ready && settings.backgroundEnabled,
      frequency: settings.frequency,
      customIntervalMinutes: settings.customIntervalMinutes,
      afterSuccessfulSync: ready && settings.backgroundEnabled,
      preserveExistingCustomSchedule: true,
    );
  }

  static Future<AutoSyncSnapshot> loadSnapshot() async {
    final record = await _syncRepository.loadRecord();
    final settings = await loadSettings();
    final ready = await hasCredentialReady();
    return AutoSyncSnapshot(
      settings: settings,
      state: AutoSyncState.fromValue(record.state),
      message: record.message ?? '等待下一次同步',
      lastFetchTime: record.lastFetchTime,
      lastAttemptTime: record.lastAttemptTime,
      nextSyncTime: record.nextSyncTime,
      lastError: record.lastError,
      lastSource: record.lastSource,
      lastDiffSummary: record.lastDiffSummary,
      credentialReady: ready,
    );
  }

  static Future<bool> hasCredentialReady() async {
    final record = await _syncRepository.loadRecord();
    final hasSemester = record.semesterCode?.isNotEmpty ?? false;
    if (!hasSemester) return false;
    if (record.cookieSnapshot?.isNotEmpty ?? false) return true;
    return await AuthCredentialsService.instance.load() != null;
  }

  static Future<bool> captureCookieSnapshot({int retries = 3}) async {
    if (!Platform.isAndroid) return false;

    for (var attempt = 0; attempt < retries; attempt++) {
      await _flushCookies();
      final cookie = await _readLiveCookieBundle();
      if (cookie != null && cookie.isNotEmpty) {
        await _storeCookieSnapshot(cookie);
        return true;
      }
      if (attempt < retries - 1) {
        await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
    return false;
  }

  static Future<bool> shouldSync({
    AutoSyncSettings? settings,
    bool force = false,
  }) async {
    if (!_supportsTimedAutoSync) return false;
    if (force) return true;

    final resolvedSettings = settings ?? await loadSettings();
    if (resolvedSettings.frequency == AutoSyncFrequency.manual) {
      return false;
    }

    if (!await hasCredentialReady()) {
      return false;
    }

    final record = await _syncRepository.loadRecord();
    final now = DateTime.now();
    final interval = resolvedSettings.interval;

    final nextSyncTime = record.nextSyncTime;
    if (nextSyncTime != null && now.isBefore(nextSyncTime)) {
      return false;
    }

    final lastFetch = record.lastFetchTime;
    if (lastFetch != null && now.difference(lastFetch) < interval) {
      return false;
    }

    final lastAttempt = record.lastAttemptTime;
    if (lastAttempt != null && now.difference(lastAttempt) < retryBackoff) {
      return false;
    }

    return true;
  }

  static Future<void> recordDesktopForegroundSyncStart({
    String source = 'desktop_foreground',
    String? message,
  }) async {
    if (!Platform.isWindows) return;
    await _syncRepository.saveStatus(
      lastAttemptTime: DateTime.now(),
      state: AutoSyncState.syncing.value,
      source: source,
      message: message ?? '正在启动桌面前台自动同步...',
      clearError: true,
    );
  }

  static Future<void> recordDesktopForegroundSyncIncomplete({
    String source = 'desktop_foreground',
    String message = '桌面前台自动同步未完成',
  }) async {
    if (!Platform.isWindows) return;
    await _markFailed(message, source: source);
  }

  static Future<AutoSyncResult> tryAutoSync(
    ScheduleProvider provider, {
    bool force = false,
    String source = 'foreground',
  }) async {
    if (!Platform.isAndroid) {
      return AutoSyncResult.skipped(
        '当前平台不需要自动同步',
        await loadSnapshot(),
      );
    }

    if (_isRunning) {
      return AutoSyncResult.skipped('已有同步任务正在进行', await loadSnapshot());
    }
    _isRunning = true;

    try {
      final settings = await loadSettings();
      final ready = await hasCredentialReady();
      if (!force && !await shouldSync(settings: settings)) {
        return AutoSyncResult.skipped('未到自动同步时间', await loadSnapshot());
      }
      if (force && !ready) {
        await _markLoginRequired('请先”登录并刷新课表”一次，再开启自动同步', source: source);
        return AutoSyncResult.loginRequired(
          '请先”登录并刷新课表”一次，再开启自动同步',
          await loadSnapshot(),
        );
      }

      final now = DateTime.now();
      await _syncRepository.saveStatus(
        lastAttemptTime: now,
        state: AutoSyncState.syncing.value,
        source: source,
        message: source == 'manual' ? '正在同步课表...' : '正在自动检查课表更新...',
      );

      final semester = await _scheduleRepository.loadActiveSemesterCode();
      if (semester == null || semester.isEmpty) {
        await _markLoginRequired('缺少学期信息，请先手动登录抓取一次', source: source);
        return AutoSyncResult.loginRequired(
          '缺少学期信息，请先手动登录抓取一次',
          await loadSnapshot(),
        );
      }

      final cookie = await _readCookie();
      if (cookie == null || cookie.isEmpty) {
        await _markLoginRequired('未读取到登录态，请重新登录教务系统', source: source);
        return AutoSyncResult.loginRequired(
          '未读取到登录态，请重新登录教务系统',
          await loadSnapshot(),
        );
      }

      final api = ApiService(cookie: cookie);
      final rawData = await api.fetchGraduateScheduleRaw(semester: semester);
      final courses = ScheduleParser.parseApiResponse(rawData);
      if (courses.isEmpty) {
        await _markFailed('接口返回成功，但未解析到课程数据', source: source);
        return AutoSyncResult.failed(
          '接口返回成功，但未解析到课程数据',
          await loadSnapshot(),
        );
      }

      await _storeCookieSnapshot(cookie);
      await _persistSuccess(
        rawData: rawData,
        semester: semester,
        courses: courses,
        provider: provider,
        source: source,
      );

      final snapshot = await loadSnapshot();
      return AutoSyncResult.success(
        courses.length,
        _buildSuccessMessage(courses.length, snapshot.lastDiffSummary),
        snapshot,
      );
    } catch (e, st) {
      debugPrint('自动同步失败: $e');
      debugPrint('$st');
      final requiresLogin = _looksLikeLoginFailure(e.toString());
      if (requiresLogin) {
        await _markLoginRequired(
          '登录态已失效，请重新登录后再同步',
          source: source,
          error: e.toString(),
        );
        return AutoSyncResult.loginRequired(
          '登录态已失效，请重新登录后再同步',
          await loadSnapshot(),
        );
      }
      await _markFailed('自动同步失败: $e', source: source, error: e.toString());
      return AutoSyncResult.failed('自动同步失败: $e', await loadSnapshot());
    } finally {
      _isRunning = false;
    }
  }

  static String formatDateTime(DateTime? time) {
    if (time == null) return '--';
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }

  static String describeFrequency(AutoSyncFrequency frequency) {
    switch (frequency) {
      case AutoSyncFrequency.manual:
        return '仅手动同步';
      case AutoSyncFrequency.daily:
        return '每天自动同步';
      case AutoSyncFrequency.weekly:
        return '每周自动同步';
      case AutoSyncFrequency.monthly:
        return '每月自动同步';
      case AutoSyncFrequency.custom:
        return '自定义自动同步';
    }
  }

  static String describeSettings(AutoSyncSettings settings) {
    if (settings.frequency != AutoSyncFrequency.custom) {
      return describeFrequency(settings.frequency);
    }
    return '每${formatIntervalMinutes(settings.customIntervalMinutes)}自动同步';
  }

  static String formatIntervalMinutes(int minutes) {
    final normalized = normalizeCustomIntervalMinutes(minutes);
    if (normalized % (24 * 60) == 0) {
      return '${normalized ~/ (24 * 60)}天';
    }
    if (normalized % 60 == 0) {
      return '${normalized ~/ 60}小时';
    }
    return '$normalized分钟';
  }

  static int normalizeCustomIntervalMinutes(int? minutes) {
    final value = minutes ?? defaultCustomIntervalMinutes;
    if (value < minCustomIntervalMinutes) {
      return minCustomIntervalMinutes;
    }
    if (value > maxCustomIntervalMinutes) {
      return maxCustomIntervalMinutes;
    }
    return value;
  }

  static Future<void> _persistSuccess({
    required Map<String, dynamic> rawData,
    required String semester,
    required List<Course> courses,
    required ScheduleProvider provider,
    required String source,
  }) async {
    final now = DateTime.now();
    final diffSummary = buildCourseDiffSummary(provider.courses, courses);
    final successMessage = _buildSuccessMessage(courses.length, diffSummary);
    await _syncRepository.saveStatus(
      lastFetchTime: now,
      lastAttemptTime: now,
      state: AutoSyncState.success.value,
      source: source,
      message: successMessage,
      diffSummary: diffSummary,
      clearError: true,
    );
    await provider.setCourses(
      courses,
      semesterCode: semester,
      rawScheduleJson: jsonEncode(rawData),
    );

    final settings = await loadSettings();
    final ready = await hasCredentialReady();
    await _configureBackgroundSync(
      enabled: ready && settings.backgroundEnabled,
      frequency: settings.frequency,
      customIntervalMinutes: settings.customIntervalMinutes,
      afterSuccessfulSync: ready && settings.backgroundEnabled,
      preserveExistingCustomSchedule: true,
    );
  }

  static String buildCourseDiffSummary(List<Course> previous, List<Course> current) {
    final previousMap = {
      for (final course in previous) _courseIdentity(course): _courseSignature(course),
    };
    final currentMap = {
      for (final course in current) _courseIdentity(course): _courseSignature(course),
    };

    final added = currentMap.keys.where((key) => !previousMap.containsKey(key)).length;
    final removed = previousMap.keys.where((key) => !currentMap.containsKey(key)).length;
    final changed = currentMap.keys
        .where((key) => previousMap.containsKey(key) && previousMap[key] != currentMap[key])
        .length;

    if (added == 0 && removed == 0 && changed == 0) {
      return '课表无变化';
    }

    final parts = <String>[];
    if (added > 0) parts.add('新增 $added 门');
    if (removed > 0) parts.add('移除 $removed 门');
    if (changed > 0) parts.add('调整 $changed 门');
    return parts.join('，');
  }

  static String _courseIdentity(Course course) {
    return '${course.code}|${course.name}|${course.teacher}|${course.className}';
  }

  static String _courseSignature(Course course) {
    final slots = course.slots
        .map(
          (slot) => [
            slot.weekday,
            slot.startSection,
            slot.endSection,
            slot.location,
            slot.weekRanges.map((range) => '${range.start}-${range.end}-${range.type.name}').join('/'),
          ].join('|'),
        )
        .toList()
      ..sort();

    return '${course.college}|${course.credits}|${course.totalHours}|${course.semester}|${course.campus}|${course.teachingType}|${slots.join(';')}';
  }

  static String _buildSuccessMessage(int courseCount, String? diffSummary) {
    final base = '已同步 $courseCount 门课程';
    if (diffSummary == null || diffSummary.isEmpty) {
      return base;
    }
    return '$base，$diffSummary';
  }

  static Future<void> _markFailed(
    String message, {
    required String source,
    String? error,
  }) async {
    await _syncRepository.saveStatus(
      state: AutoSyncState.failed.value,
      source: source,
      message: message,
      error: error,
    );
    final settings = await loadSettings();
    final ready = await hasCredentialReady();
    await _configureBackgroundSync(
      enabled: ready && settings.backgroundEnabled,
      frequency: settings.frequency,
      customIntervalMinutes: settings.customIntervalMinutes,
      afterSuccessfulSync: false,
      preserveExistingCustomSchedule: true,
    );
  }

  static Future<void> _markLoginRequired(
    String message, {
    required String source,
    String? error,
  }) async {
    await _syncRepository.saveStatus(
      state: AutoSyncState.loginRequired.value,
      source: source,
      message: message,
      error: error,
    );
    final settings = await loadSettings();
    final ready = await hasCredentialReady();
    await _configureBackgroundSync(
      enabled: ready && settings.backgroundEnabled,
      frequency: settings.frequency,
      customIntervalMinutes: settings.customIntervalMinutes,
      afterSuccessfulSync: false,
      preserveExistingCustomSchedule: true,
    );
  }

  static DateTime? _computeNextSyncTime({
    required AutoSyncSettings settings,
    required DateTime now,
    required bool afterSuccessfulSync,
    required bool preserveExistingCustomSchedule,
    DateTime? previousNextSyncTime,
    DateTime? lastFetchTime,
    DateTime? lastAttemptTime,
  }) {
    if (!settings.backgroundEnabled) {
      return null;
    }

    if (settings.frequency == AutoSyncFrequency.custom) {
      final interval = settings.interval;
      if (!afterSuccessfulSync && preserveExistingCustomSchedule) {
        if (previousNextSyncTime != null && previousNextSyncTime.isAfter(now)) {
          return previousNextSyncTime;
        }

        DateTime? anchor;
        if (lastFetchTime != null) {
          anchor = lastFetchTime;
        }
        if (lastAttemptTime != null &&
            (anchor == null || lastAttemptTime.isAfter(anchor))) {
          anchor = lastAttemptTime;
        }
        if (anchor != null) {
          final anchoredNextTime = anchor.add(interval);
          if (anchoredNextTime.isAfter(now)) {
            return anchoredNextTime;
          }
        }
      }
      return now.add(interval);
    }

    switch (settings.frequency) {
      case AutoSyncFrequency.manual:
        return null;
      case AutoSyncFrequency.daily:
        final todayAtTarget = DateTime(now.year, now.month, now.day, 6, 30);
        if (afterSuccessfulSync || !todayAtTarget.isAfter(now)) {
          return todayAtTarget.add(const Duration(days: 1));
        }
        return todayAtTarget;
      case AutoSyncFrequency.weekly:
        var target = DateTime(now.year, now.month, now.day, 6, 30);
        while (target.weekday != DateTime.monday) {
          target = target.add(const Duration(days: 1));
        }
        if (afterSuccessfulSync || !target.isAfter(now)) {
          target = target.add(const Duration(days: 7));
        }
        return target;
      case AutoSyncFrequency.monthly:
        var target = DateTime(now.year, now.month, 1, 6, 30);
        if (afterSuccessfulSync || !target.isAfter(now)) {
          target = DateTime(now.year, now.month + 1, 1, 6, 30);
        }
        return target;
      case AutoSyncFrequency.custom:
        return null;
    }
  }

  static Future<void> _configureBackgroundSync({
    required bool enabled,
    required AutoSyncFrequency frequency,
    int? customIntervalMinutes,
    required bool afterSuccessfulSync,
    required bool preserveExistingCustomSchedule,
  }) async {
    if (Platform.isWindows) {
      if (!enabled || frequency == AutoSyncFrequency.manual) {
        await _syncRepository.saveStatus(clearNextSyncTime: true);
        return;
      }

      final normalizedCustomIntervalMinutes = frequency == AutoSyncFrequency.custom
          ? normalizeCustomIntervalMinutes(customIntervalMinutes)
          : defaultCustomIntervalMinutes;
      final settings = AutoSyncSettings(
        frequency: frequency,
        customIntervalMinutes: normalizedCustomIntervalMinutes,
      );
      final snapshot = await loadSnapshot();
      final nextTime = _computeNextSyncTime(
        settings: settings,
        now: DateTime.now(),
        afterSuccessfulSync: afterSuccessfulSync,
        preserveExistingCustomSchedule: preserveExistingCustomSchedule,
        previousNextSyncTime: snapshot.nextSyncTime,
        lastFetchTime: snapshot.lastFetchTime,
        lastAttemptTime: snapshot.lastAttemptTime,
      );
      if (nextTime == null) {
        await _syncRepository.saveStatus(clearNextSyncTime: true);
      } else {
        await _syncRepository.saveStatus(nextSyncTime: nextTime);
      }
      return;
    }

    if (!Platform.isAndroid) return;
    try {
      final next = await _channel.invokeMethod<String>('configureBackgroundSync', {
        'enabled': enabled,
        'frequency': frequency.value,
        'customIntervalMinutes': customIntervalMinutes,
        'afterSuccessfulSync': afterSuccessfulSync,
        'preserveExistingCustomSchedule': preserveExistingCustomSchedule,
      });
      if (next == null || next.isEmpty) {
        await _syncRepository.saveStatus(clearNextSyncTime: true);
      } else {
        final nextTime = DateTime.tryParse(next);
        if (nextTime == null) {
          await _syncRepository.saveStatus(clearNextSyncTime: true);
        } else {
          await _syncRepository.saveStatus(nextSyncTime: nextTime);
        }
      }
    } on PlatformException catch (e) {
      debugPrint('配置后台同步失败: ${e.message}');
    }
  }

  static Future<void> _flushCookies() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('flushCookies');
    } on PlatformException catch (e) {
      debugPrint('刷新 Cookie 失败: ${e.message}');
    }
  }

  static Future<String?> _invokeGetCookie(String url) async {
    try {
      return await _channel.invokeMethod<String>('getCookie', {
        'url': url,
      });
    } on PlatformException catch (e) {
      debugPrint('读取 Cookie 失败: ${e.message}');
      return null;
    }
  }

  static Future<void> _storeCookieSnapshot(String cookie) async {
    await _syncRepository.saveCookieSnapshot(cookie);
  }

  static Future<String?> _readLiveCookieBundle() async {
    final cookies = <String>[];
    for (final url in [_apiUrl, _indexUrl, _baseUrl]) {
      final value = await _invokeGetCookie(url);
      if (value != null && value.isNotEmpty) {
        cookies.add(value);
      }
    }

    final merged = _mergeCookieStrings(cookies);
    return merged.isEmpty ? null : merged;
  }

  static String _mergeCookieStrings(Iterable<String> cookies) {
    final merged = <String, String>{};

    for (final raw in cookies) {
      for (final part in raw.split(';')) {
        final segment = part.trim();
        if (segment.isEmpty) continue;
        final index = segment.indexOf('=');
        if (index <= 0) continue;
        final key = segment.substring(0, index).trim();
        final value = segment.substring(index + 1).trim();
        if (key.isEmpty || value.isEmpty) continue;
        merged[key] = value;
      }
    }

    if (merged.isEmpty) return '';
    return merged.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
  }

  static Future<String?> _readCookie() async {
    final live = await _readLiveCookieBundle();
    if (live != null && live.isNotEmpty) {
      await _storeCookieSnapshot(live);
      return live;
    }

    final stored = await _syncRepository.loadCookieSnapshot();
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    return null;
  }

  static bool _looksLikeLoginFailure(String message) {
    final lower = message.toLowerCase();
    return lower.contains('重新登录') ||
        lower.contains('登录态') ||
        lower.contains('cookie') ||
        lower.contains('code=') ||
        lower.contains('401') ||
        lower.contains('403');
  }
}
