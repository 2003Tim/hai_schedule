import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_storage.dart';

class AppBackupService {
  AppBackupService._();

  static const int schemaVersion = 1;

  static const List<String> _backupKeys = [
    'display_days',
    'show_non_current_week',
    'auto_sync_frequency',
    'auto_sync_custom_interval_minutes',
    'last_semester_code',
    'current_semester',
    'active_semester_code',
    'schedule_archive_by_semester',
    'schedule_overrides',
    'school_time_config',
    'school_time_generator_settings',
    'class_reminder_lead_minutes',
    'class_silence_enabled',
    'theme_id',
    'custom_bg_path',
    'bg_opacity',
    'bg_blur',
    'card_opacity',
    'follow_system_theme',
    'system_light_theme_id',
    'system_dark_theme_id',
    'mini_opacity',
    'mini_always_on_top',
  ];

  static const List<String> _restorableKeys = _backupKeys;

  static const List<String> _transientKeys = [
    'courses',
    'last_fetch_time',
    'last_auto_sync_attempt_time',
    'last_auto_sync_error',
    'last_auto_sync_message',
    'last_auto_sync_state',
    'last_auto_sync_source',
    'last_auto_sync_diff_summary',
    'next_background_sync_time',
    'last_schedule_json',
    'last_auto_sync_cookie',
    'last_student_id',
    'class_reminder_last_build_time',
    'class_reminder_horizon_end',
    'class_reminder_scheduled_count',
    'class_reminder_exact_alarm_enabled',
    'class_silence_last_build_time',
    'class_silence_horizon_end',
    'class_silence_scheduled_count',
  ];

  static const List<String> _semesterRelatedKeys = [
    'schedule_archive_by_semester',
    'active_semester_code',
  ];

  static const List<String> _overrideRelatedKeys = ['schedule_overrides'];

  static const List<String> _automationRelatedKeys = [
    'class_reminder_lead_minutes',
    'class_silence_enabled',
  ];

  static const List<String> _appearanceRelatedKeys = [
    'theme_id',
    'custom_bg_path',
    'bg_opacity',
    'bg_blur',
    'card_opacity',
    'follow_system_theme',
    'system_light_theme_id',
    'system_dark_theme_id',
    'mini_opacity',
    'mini_always_on_top',
  ];

  static Future<Map<String, dynamic>> buildBackupPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};

    for (final key in _backupKeys) {
      if (!prefs.containsKey(key)) continue;
      data[key] = prefs.get(key);
    }

    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': data,
    };
  }

  static Future<String> buildBackupJson() async {
    final payload = await buildBackupPayload();
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static Future<BackupSummary> buildCurrentSummary() async {
    final payload = await buildBackupPayload();
    return parseSummaryFromPayload(payload);
  }

  static Future<String> defaultBackupDirectoryPath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(
      '${docsDir.path}${Platform.pathSeparator}backups',
    );
    if (!backupDir.existsSync()) {
      await backupDir.create(recursive: true);
    }
    return backupDir.path;
  }

  static Future<File> exportBackupFile({String? directoryPath}) async {
    final backupDirPath =
        directoryPath == null || directoryPath.trim().isEmpty
            ? await defaultBackupDirectoryPath()
            : directoryPath.trim();
    final backupDir = Directory(backupDirPath);
    if (!backupDir.existsSync()) {
      await backupDir.create(recursive: true);
    }

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('-', '')
        .replaceAll('.', '');
    final file = File(
      '${backupDir.path}${Platform.pathSeparator}hai_schedule_backup_$timestamp.json',
    );
    await file.writeAsString(
      await buildBackupJson(),
      encoding: utf8,
      flush: true,
    );
    return file;
  }

  static Future<void> restoreFromJson(String jsonText) async {
    final decoded = json.decode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('备份格式无效');
    }

    final version = decoded['schemaVersion'];
    if (version != schemaVersion) {
      throw FormatException('不支持的备份版本: $version');
    }

    final data = decoded['data'];
    if (data is! Map) {
      throw const FormatException('备份数据缺失');
    }

    final prefs = await SharedPreferences.getInstance();
    final storage = AppStorage.instance;
    final previousValues = _snapshotPrefs(prefs, _restorableKeys);
    final previousCookieSnapshot = await storage.loadCookieSnapshot();
    final restoredValues = _normalizeRestorableData(data);

    try {
      for (final key in _restorableKeys) {
        await prefs.remove(key);
      }
      for (final entry in restoredValues.entries) {
        await _writePrefValue(prefs, entry.key, entry.value);
      }
      for (final key in _transientKeys) {
        await prefs.remove(key);
      }
      await storage.clearCookieSnapshot();
    } catch (error) {
      try {
        for (final key in _restorableKeys) {
          await prefs.remove(key);
        }
        for (final entry in previousValues.entries) {
          await _writePrefValue(prefs, entry.key, entry.value);
        }
        if (previousCookieSnapshot != null &&
            previousCookieSnapshot.isNotEmpty) {
          await storage.saveCookieSnapshot(previousCookieSnapshot);
        } else {
          await storage.clearCookieSnapshot();
        }
      } catch (rollbackError) {
        throw StateError('恢复失败且回滚失败: $error / $rollbackError');
      }
      rethrow;
    }
  }

  static BackupSummary parseSummaryFromJson(String jsonText) {
    final decoded = json.decode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('备份格式无效');
    }
    return parseSummaryFromPayload(decoded);
  }

  static BackupSummary parseSummaryFromPayload(Map<String, dynamic> payload) {
    final version = payload['schemaVersion'];
    if (version != schemaVersion) {
      throw FormatException('不支持的备份版本: $version');
    }

    final data = payload['data'];
    if (data is! Map) {
      throw const FormatException('备份数据缺失');
    }

    final rawData = Map<String, dynamic>.from(data);
    final archiveRaw = rawData['schedule_archive_by_semester'];
    final overrideRaw = rawData['schedule_overrides'];

    final semesterCount = _countSemesters(archiveRaw);
    final overrideCount = _countOverrides(overrideRaw);
    final reminderEnabled =
        (rawData['class_reminder_lead_minutes'] as int? ?? 0) > 0;
    final silenceEnabled = rawData['class_silence_enabled'] == true;

    return BackupSummary(
      exportedAt: DateTime.tryParse(payload['exportedAt']?.toString() ?? ''),
      semesterCount: semesterCount,
      overrideCount: overrideCount,
      reminderEnabled: reminderEnabled,
      silenceEnabled: silenceEnabled,
      hasSemesterData: _containsAny(rawData, _semesterRelatedKeys),
      hasOverrideData: _containsAny(rawData, _overrideRelatedKeys),
      hasAutomationSettings: _containsAny(rawData, _automationRelatedKeys),
      hasAppearanceSettings: _containsAny(rawData, _appearanceRelatedKeys),
    );
  }

  static bool _containsAny(Map<String, dynamic> data, List<String> keys) {
    return keys.any(data.containsKey);
  }

  static int _countSemesters(dynamic rawValue) {
    if (rawValue is String && rawValue.isNotEmpty) {
      try {
        final decoded = json.decode(rawValue);
        if (decoded is Map) return decoded.length;
      } catch (_) {
        return 0;
      }
    }
    if (rawValue is Map) return rawValue.length;
    return 0;
  }

  static int _countOverrides(dynamic rawValue) {
    if (rawValue is String && rawValue.isNotEmpty) {
      try {
        final decoded = json.decode(rawValue);
        if (decoded is List) return decoded.length;
      } catch (_) {
        return 0;
      }
    }
    if (rawValue is List) return rawValue.length;
    return 0;
  }

  static Future<void> _writePrefValue(
    SharedPreferences prefs,
    String key,
    dynamic value,
  ) async {
    if (value == null) return;
    if (value is bool) {
      await prefs.setBool(key, value);
      return;
    }
    if (value is int) {
      await prefs.setInt(key, value);
      return;
    }
    if (value is double) {
      await prefs.setDouble(key, value);
      return;
    }
    if (value is String) {
      await prefs.setString(key, value);
      return;
    }
    if (value is List) {
      await prefs.setStringList(
        key,
        value.map((item) => item.toString()).toList(),
      );
      return;
    }
    throw FormatException('不支持的键值类型: $key');
  }

  static Map<String, dynamic> _snapshotPrefs(
    SharedPreferences prefs,
    Iterable<String> keys,
  ) {
    final snapshot = <String, dynamic>{};
    for (final key in keys) {
      if (!prefs.containsKey(key)) continue;
      snapshot[key] = prefs.get(key);
    }
    return snapshot;
  }

  static Map<String, dynamic> _normalizeRestorableData(Map raw) {
    final restored = <String, dynamic>{};
    for (final entry in raw.entries) {
      final key = entry.key?.toString();
      if (key == null || !_restorableKeys.contains(key)) continue;

      final value = entry.value;
      if (value == null ||
          value is bool ||
          value is int ||
          value is double ||
          value is String) {
        restored[key] = value;
        continue;
      }

      if (value is List) {
        if (value.any((item) => item is! String)) {
          throw FormatException('键 $key 的列表数据无效');
        }
        restored[key] = value.cast<String>();
        continue;
      }

      throw FormatException('不支持的键值类型: $key');
    }
    return restored;
  }
}

class BackupSummary {
  final DateTime? exportedAt;
  final int semesterCount;
  final int overrideCount;
  final bool reminderEnabled;
  final bool silenceEnabled;
  final bool hasSemesterData;
  final bool hasOverrideData;
  final bool hasAutomationSettings;
  final bool hasAppearanceSettings;

  const BackupSummary({
    this.exportedAt,
    required this.semesterCount,
    required this.overrideCount,
    required this.reminderEnabled,
    required this.silenceEnabled,
    required this.hasSemesterData,
    required this.hasOverrideData,
    required this.hasAutomationSettings,
    required this.hasAppearanceSettings,
  });
}
