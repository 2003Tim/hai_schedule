import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:hai_schedule/models/auto_sync_models.dart';
import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/utils/auto_sync_course_diff.dart';
import 'package:hai_schedule/utils/auto_sync_schedule_policy.dart';
import 'package:hai_schedule/utils/auto_sync_text.dart';
import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/services/app_repositories.dart';
import 'package:hai_schedule/services/auth_credentials_service.dart';
import 'package:hai_schedule/services/course_repository.dart';
import 'package:hai_schedule/services/dio_client.dart';
import 'package:hai_schedule/services/invalid_credentials_exception.dart';
import 'package:hai_schedule/services/login_expired_exception.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/services/schedule_sync_result_service.dart';

export '../models/auto_sync_models.dart';

class AutoSyncService {
  static const MethodChannel _channel = MethodChannel('hai_schedule/auto_sync');
  static const String _baseUrl = 'https://ehall.hainanu.edu.cn';
  static const String _indexUrl =
      'https://ehall.hainanu.edu.cn/gsapp/sys/wdkbapp/*default/index.do';
  static const String _apiUrl =
      'https://ehall.hainanu.edu.cn/gsapp/sys/wdkbapp/modules/xskcb/xsjxrwcx.do';

  static const Duration retryBackoff = AutoSyncSchedulePolicy.retryBackoff;
  static const int defaultCustomIntervalMinutes =
      AutoSyncSchedulePolicy.defaultCustomIntervalMinutes;
  static const int minCustomIntervalMinutes =
      AutoSyncSchedulePolicy.minCustomIntervalMinutes;
  static const int maxCustomIntervalMinutes =
      AutoSyncSchedulePolicy.maxCustomIntervalMinutes;

  static final ScheduleRepository _scheduleRepository = ScheduleRepository();
  static final SyncRepository _syncRepository = SyncRepository();
  static final ScheduleSyncResultService _syncResultService =
      ScheduleSyncResultService();
  static bool _isRunning = false;
  @visibleForTesting
  static bool? debugForceAndroid;

  static bool get _supportsTimedAutoSync => _isAndroid || Platform.isWindows;
  static bool get supportsForegroundDesktopAutoSync => Platform.isWindows;
  static bool get _isAndroid => debugForceAndroid ?? Platform.isAndroid;

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

    final normalizedCustomIntervalMinutes =
        frequency == AutoSyncFrequency.custom
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
      message:
          frequency == AutoSyncFrequency.manual
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

  static Future<void> ensureBackgroundSchedule({
    bool? credentialReadyOverride,
  }) async {
    if (!_supportsTimedAutoSync) return;
    final settings = await loadSettings();
    final ready = credentialReadyOverride ?? await hasCredentialReady();
    await _configureBackgroundSync(
      enabled: ready && settings.backgroundEnabled,
      frequency: settings.frequency,
      customIntervalMinutes: settings.customIntervalMinutes,
      afterSuccessfulSync: false,
      preserveExistingCustomSchedule: true,
    );
  }

  static Future<void> handleCredentialCleared() async {
    await AppStorage.instance.setSyncInvalidationFlag(true);
    await _cancelBackgroundSync(strict: true);
    await AuthCredentialsService.instance.clear(strict: true);
    await AppStorage.instance.clearCookieSnapshot(strict: true);
    await DioClient.clearAllSessions();
    await _clearLiveWebViewCookies(strict: true);
    await _syncRepository.saveStatus(
      state: AutoSyncState.idle.value,
      source: 'credential_clear',
      message: '已清除保存的账号信息，后台自动同步已停用',
      clearError: true,
      clearDiffSummary: true,
      clearNextSyncTime: true,
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

  static Future<AutoSyncSnapshot> loadSnapshot({String? semesterCode}) async {
    final record = await _syncRepository.loadRecord(semesterCode: semesterCode);
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
      semesterCode: record.semesterCode,
      semesterSyncRecord: record.semesterSyncRecord,
      credentialReady: ready,
    );
  }

  static Future<bool> hasCredentialReady() async {
    if (await AppStorage.instance.loadSyncInvalidationFlag()) {
      return false;
    }
    final record = await _syncRepository.loadRecord();
    final hasSemester = record.semesterCode?.isNotEmpty ?? false;
    if (!hasSemester) return false;
    if (record.cookieSnapshot?.isNotEmpty ?? false) return true;
    return await AuthCredentialsService.instance.load() != null;
  }

  static Future<bool> captureCookieSnapshot({int retries = 3}) async {
    if (!_isAndroid) return false;

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
    if (!_isAndroid) {
      return AutoSyncResult.skipped('当前平台不需要自动同步', await loadSnapshot());
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
      final semester = await _scheduleRepository.loadActiveSemesterCode();
      if (semester == null || semester.isEmpty) {
        await _markLoginRequired('缺少学期信息，请先手动登录抓取一次', source: source);
        return AutoSyncResult.loginRequired(
          '缺少学期信息，请先手动登录抓取一次',
          await loadSnapshot(),
        );
      }

      await _syncRepository.saveStatus(
        lastAttemptTime: now,
        state: AutoSyncState.syncing.value,
        source: source,
        message: source == 'manual' ? '正在同步课表...' : '正在自动检查课表更新...',
        semesterCode: semester,
      );

      final cookie = await _readCookie();
      final courseRepository = CourseRepository();
      final fetchResult = await courseRepository
          .syncCourse(
            semester: semester,
            cookie: cookie,
            onSemesterCatalogUpdated: provider.refreshKnownSemesterCatalog,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('课表同步超时，请稍后重试'),
          );

      final latestCookie = courseRepository.currentCookie;
      if (latestCookie != null && latestCookie.isNotEmpty) {
        await _storeCookieSnapshot(latestCookie);
      }
      await _persistSuccess(
        rawData: fetchResult.rawData,
        semester: semester,
        courses: fetchResult.courses,
        provider: provider,
        source: source,
      );

      final snapshot = await loadSnapshot(semesterCode: semester);
      return AutoSyncResult.success(
        fetchResult.courses.length,
        _buildSuccessMessage(
          fetchResult.courses.length,
          snapshot.lastDiffSummary,
        ),
        snapshot,
      );
    } on InvalidCredentialsException catch (e) {
      await handleCredentialCleared();
      await _markLoginRequired(
        e.message,
        source: source,
        error: 'invalid_credentials',
      );
      return AutoSyncResult.loginRequired(e.message, await loadSnapshot());
    } on LoginExpiredException catch (e) {
      await _clearInvalidCookieSnapshot();
      await _markLoginRequired(
        e.message,
        source: source,
        error: 'login_expired',
      );
      return AutoSyncResult.loginRequired(e.message, await loadSnapshot());
    } catch (e, st) {
      debugPrint('自动同步失败: $e');
      debugPrint('$st');
      final requiresLogin = _looksLikeLoginFailure(e.toString());
      if (requiresLogin) {
        await _clearInvalidCookieSnapshot();
        await _markLoginRequired(
          LoginExpiredException.defaultMessage,
          source: source,
          error: e.toString(),
        );
        return AutoSyncResult.loginRequired(
          LoginExpiredException.defaultMessage,
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
    return AutoSyncText.formatDateTime(time);
  }

  static String describeFrequency(AutoSyncFrequency frequency) {
    return AutoSyncText.describeFrequency(frequency);
  }

  static String describeSettings(AutoSyncSettings settings) {
    return AutoSyncText.describeSettings(settings);
  }

  static String formatIntervalMinutes(int minutes) {
    return AutoSyncText.formatIntervalMinutes(minutes);
  }

  static int normalizeCustomIntervalMinutes(int? minutes) {
    return AutoSyncSchedulePolicy.normalizeCustomIntervalMinutes(minutes);
  }

  static Future<void> _persistSuccess({
    required Map<String, dynamic> rawData,
    required String semester,
    required List<Course> courses,
    required ScheduleProvider provider,
    required String source,
  }) async {
    await _syncResultService.applySuccessfulSync(
      provider: provider,
      courses: courses,
      semesterCode: semester,
      rawScheduleJson: jsonEncode(rawData),
      source: source,
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

  static String buildCourseDiffSummary(
    List<Course> previous,
    List<Course> current,
  ) {
    return AutoSyncCourseDiff.buildSummary(previous, current);
  }

  static String _buildSuccessMessage(int courseCount, String? diffSummary) {
    return AutoSyncText.buildSuccessMessage(courseCount, diffSummary);
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
    return AutoSyncSchedulePolicy.computeNextSyncTime(
      settings: settings,
      now: now,
      afterSuccessfulSync: afterSuccessfulSync,
      preserveExistingCustomSchedule: preserveExistingCustomSchedule,
      previousNextSyncTime: previousNextSyncTime,
      lastFetchTime: lastFetchTime,
      lastAttemptTime: lastAttemptTime,
    );
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

      final normalizedCustomIntervalMinutes =
          frequency == AutoSyncFrequency.custom
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
      final next = await _channel
          .invokeMethod<String>('configureBackgroundSync', {
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

  static Future<void> _cancelBackgroundSync({bool strict = false}) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('cancelBackgroundSync');
    } on PlatformException catch (e) {
      if (strict) rethrow;
      debugPrint('取消后台同步失败: ${e.message}');
    }
  }

  static Future<void> _flushCookies() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('flushCookies');
    } on PlatformException catch (e) {
      debugPrint('刷新 Cookie 失败: ${e.message}');
    }
  }

  static Future<void> _clearLiveWebViewCookies({bool strict = false}) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('clearCookies');
    } on PlatformException catch (e) {
      if (strict) rethrow;
      debugPrint('清理 WebView Cookie 失败: ${e.message}');
    }
  }

  static Future<String?> _invokeGetCookie(String url) async {
    try {
      return await _channel.invokeMethod<String>('getCookie', {'url': url});
    } on PlatformException catch (e) {
      debugPrint('读取 Cookie 失败: ${e.message}');
      return null;
    }
  }

  static Future<void> _storeCookieSnapshot(String cookie) async {
    await _syncRepository.saveCookieSnapshot(cookie);
  }

  static Future<void> _clearInvalidCookieSnapshot() async {
    await AppStorage.instance.clearCookieSnapshot();
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
    return merged.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
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
    return AutoSyncText.looksLikeLoginFailure(message);
  }
}
