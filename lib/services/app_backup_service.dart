import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/models/school_time.dart';
import 'package:hai_schedule/utils/app_storage_schema.dart';
import 'package:hai_schedule/utils/theme_background_store.dart';
import 'package:hai_schedule/services/app_storage.dart';

class AppBackupService {
  AppBackupService._();

  static const int schemaVersion = 2;
  static const Set<int> _supportedSchemaVersions = {1, 2};
  static const String _customBackgroundAssetKey = 'customBackground';

  static const List<String> _backupKeys = AppStorageSchema.backupKeys;

  static const List<String> _restorableKeys = _backupKeys;

  static const List<String> _transientKeys = AppStorageSchema.transientKeys;

  static const List<String> _semesterRelatedKeys =
      AppStorageSchema.semesterRelatedKeys;

  static const List<String> _overrideRelatedKeys =
      AppStorageSchema.overrideRelatedKeys;

  static const List<String> _automationRelatedKeys =
      AppStorageSchema.automationRelatedKeys;

  static const List<String> _appearanceRelatedKeys =
      AppStorageSchema.appearanceRelatedKeys;

  static Future<Map<String, dynamic>> buildBackupPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};

    for (final key in _backupKeys) {
      if (key == AppStorageSchema.customBgPathKey) continue;
      if (!prefs.containsKey(key)) continue;
      data[key] = prefs.get(key);
    }

    final assets = <String, dynamic>{};
    final customBackgroundAsset = await _buildCustomBackgroundAsset(
      prefs.getString(AppStorageSchema.customBgPathKey),
    );
    if (customBackgroundAsset != null) {
      assets[_customBackgroundAssetKey] = customBackgroundAsset;
    }

    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': data,
      if (assets.isNotEmpty) 'assets': assets,
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

    _parseSchemaVersion(decoded['schemaVersion']);

    final data = decoded['data'];
    if (data is! Map) {
      throw const FormatException('备份数据缺失');
    }

    final prefs = await SharedPreferences.getInstance();
    final storage = AppStorage.instance;
    final previousValues = _snapshotPrefs(prefs, _restorableKeys);
    final previousCookieSnapshot = await storage.loadCookieSnapshot();
    final previousBackgroundPath =
        previousValues[AppStorageSchema.customBgPathKey] as String?;
    final restoredValues = _normalizeRestorableData(data)
      ..remove(AppStorageSchema.customBgPathKey);
    final customBackgroundAsset = _decodeCustomBackgroundAsset(
      decoded['assets'],
    );
    String? restoredBackgroundPath;

    try {
      if (customBackgroundAsset != null) {
        restoredBackgroundPath =
            await ThemeBackgroundStore.importCustomBackgroundBytes(
              customBackgroundAsset.bytes,
              sourceName: customBackgroundAsset.fileName,
            );
        restoredValues[AppStorageSchema.customBgPathKey] = restoredBackgroundPath;
      }

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

      if (previousBackgroundPath != null &&
          previousBackgroundPath != restoredBackgroundPath) {
        await ThemeBackgroundStore.cleanupBackground(previousBackgroundPath);
      }
    } catch (error) {
      if (restoredBackgroundPath != null &&
          restoredBackgroundPath != previousBackgroundPath) {
        await ThemeBackgroundStore.cleanupBackground(restoredBackgroundPath);
      }
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
    _parseSchemaVersion(payload['schemaVersion']);

    final data = payload['data'];
    if (data is! Map) {
      throw const FormatException('备份数据缺失');
    }

    final rawData = Map<String, dynamic>.from(data);
    final archiveRaw = rawData[AppStorageSchema.scheduleArchiveKey];
    final overrideRaw = rawData[AppStorageSchema.scheduleOverridesKey];

    final semesterCount = _countSemesters(archiveRaw);
    final overrideCount = _countOverrides(overrideRaw);
    final reminderEnabled =
        (rawData[AppStorageSchema.reminderLeadTimeKey] as int? ?? 0) > 0;
    final silenceEnabled =
        rawData[AppStorageSchema.classSilenceEnabledKey] == true;

    return BackupSummary(
      exportedAt: DateTime.tryParse(payload['exportedAt']?.toString() ?? ''),
      semesterCount: semesterCount,
      overrideCount: overrideCount,
      reminderEnabled: reminderEnabled,
      silenceEnabled: silenceEnabled,
      hasSemesterData: _containsAny(rawData, _semesterRelatedKeys),
      hasOverrideData: _containsAny(rawData, _overrideRelatedKeys),
      hasAutomationSettings: _containsAny(rawData, _automationRelatedKeys),
      hasAppearanceSettings:
          _containsAny(rawData, _appearanceRelatedKeys) ||
          _hasCustomBackgroundAsset(payload['assets']),
    );
  }

  static bool _containsAny(Map<String, dynamic> data, List<String> keys) {
    return keys.any(data.containsKey);
  }

  static bool _hasCustomBackgroundAsset(dynamic rawAssets) {
    return _decodeCustomBackgroundAsset(rawAssets) != null;
  }

  static int _parseSchemaVersion(dynamic value) {
    final version =
        value is int ? value : int.tryParse(value?.toString() ?? '');
    if (version == null || !_supportedSchemaVersions.contains(version)) {
      throw FormatException('不支持的备份版本: $value');
    }
    return version;
  }

  static Future<Map<String, dynamic>?> _buildCustomBackgroundAsset(
    String? backgroundPath,
  ) async {
    if (backgroundPath == null || backgroundPath.trim().isEmpty) {
      return null;
    }
    final file = File(backgroundPath.trim());
    if (!await file.exists()) {
      return null;
    }
    return <String, dynamic>{
      'fileName':
          file.uri.pathSegments.isNotEmpty
              ? file.uri.pathSegments.last
              : 'custom_bg.jpg',
      'bytesBase64': base64Encode(await file.readAsBytes()),
    };
  }

  static _DecodedCustomBackgroundAsset? _decodeCustomBackgroundAsset(
    dynamic rawAssets,
  ) {
    if (rawAssets == null) return null;
    if (rawAssets is! Map) {
      throw const FormatException('备份资源格式无效');
    }
    final rawAsset = rawAssets[_customBackgroundAssetKey];
    if (rawAsset == null) return null;
    if (rawAsset is! Map) {
      throw const FormatException('背景资源格式无效');
    }

    final fileName = rawAsset['fileName']?.toString();
    final bytesBase64 = rawAsset['bytesBase64'];
    if (bytesBase64 is! String || bytesBase64.isEmpty) {
      throw const FormatException('背景资源内容缺失');
    }

    try {
      final bytes = base64Decode(bytesBase64);
      if (bytes.isEmpty) {
        throw const FormatException('背景资源内容为空');
      }
      return _DecodedCustomBackgroundAsset(fileName: fileName, bytes: bytes);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('背景资源内容无效');
    }
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
      if (value == null) {
        restored[key] = null;
        continue;
      }
      if (value is bool || value is int || value is double) {
        restored[key] = value;
        continue;
      }
      if (value is String) {
        restored[key] = _validateStructuredStringValue(key, value);
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

  static String _validateStructuredStringValue(String key, String value) {
    switch (key) {
      case AppStorageSchema.scheduleArchiveKey:
        return _canonicalizeScheduleArchive(value);
      case AppStorageSchema.scheduleOverridesKey:
        return _canonicalizeScheduleOverrides(value);
      case AppStorageSchema.schoolTimeConfigKey:
        return _canonicalizeSchoolTimeConfig(value);
      case AppStorageSchema.schoolTimeGeneratorSettingsKey:
        return _canonicalizeSchoolTimeGeneratorSettings(value);
      default:
        return value;
    }
  }

  static String _canonicalizeScheduleArchive(String raw) {
    if (raw.trim().isEmpty) return json.encode(<String, dynamic>{});
    final decoded = json.decode(raw);
    if (decoded is! Map) {
      throw const FormatException('学期归档数据格式无效');
    }

    final normalized = <String, dynamic>{};
    for (final entry in decoded.entries) {
      final semesterCode = entry.key.toString();
      if (semesterCode.isEmpty) {
        throw const FormatException('学期归档缺少有效学期代码');
      }
      if (entry.value is! Map) {
        throw FormatException('学期 $semesterCode 的归档格式无效');
      }
      final rawEntry = Map<String, dynamic>.from(entry.value as Map);
      final normalizedEntry = <String, dynamic>{};

      final rawScheduleJson = rawEntry['rawScheduleJson'];
      if (rawScheduleJson != null && rawScheduleJson is! String) {
        throw FormatException('学期 $semesterCode 的原始课表格式无效');
      }
      if (rawScheduleJson is String) {
        normalizedEntry['rawScheduleJson'] = rawScheduleJson;
      }

      final coursesRaw = rawEntry['courses'];
      if (coursesRaw != null) {
        if (coursesRaw is! List) {
          throw FormatException('学期 $semesterCode 的课程列表格式无效');
        }
        final normalizedCourses = <Map<String, dynamic>>[];
        for (final item in coursesRaw) {
          if (item is! Map) {
            throw FormatException('学期 $semesterCode 的课程条目格式无效');
          }
          final course = Course.fromJson(Map<String, dynamic>.from(item));
          normalizedCourses.add(course.toJson());
        }
        normalizedEntry['courses'] = normalizedCourses;
      }

      normalized[semesterCode] = normalizedEntry;
    }
    return json.encode(normalized);
  }

  static String _canonicalizeScheduleOverrides(String raw) {
    if (raw.trim().isEmpty) return json.encode(<Map<String, dynamic>>[]);
    final decoded = json.decode(raw);
    if (decoded is! List) {
      throw const FormatException('临时安排数据格式无效');
    }

    final normalized = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is! Map) {
        throw const FormatException('临时安排条目格式无效');
      }
      final override = ScheduleOverride.fromJson(
        Map<String, dynamic>.from(item),
      );
      normalized.add(override.toJson());
    }
    return json.encode(normalized);
  }

  static String _canonicalizeSchoolTimeConfig(String raw) {
    if (raw.trim().isEmpty) {
      throw const FormatException('作息时间配置不能为空');
    }
    final decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('作息时间配置格式无效');
    }
    final config = SchoolTimeConfig.fromJson(decoded);
    if (config.classTimes.isEmpty) {
      throw const FormatException('作息时间配置缺少课程时间');
    }
    return json.encode(config.toJson());
  }

  static String _canonicalizeSchoolTimeGeneratorSettings(String raw) {
    if (raw.trim().isEmpty) {
      return json.encode(SchoolTimeGeneratorSettings.defaults().toJson());
    }
    final decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('作息生成器配置格式无效');
    }
    final settings = SchoolTimeGeneratorSettings.fromJson(decoded);
    return json.encode(settings.toJson());
  }
}

class _DecodedCustomBackgroundAsset {
  final String? fileName;
  final Uint8List bytes;

  const _DecodedCustomBackgroundAsset({
    required this.fileName,
    required this.bytes,
  });
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
