import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/services/app_backup_service.dart';
import 'package:hai_schedule/services/app_storage.dart';

import '../test_helpers/secure_storage_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  Directory? tempDir;

  Future<void> bindPathProviderTempDir() async {
    tempDir ??= await Directory.systemTemp.createTemp('hai_schedule_backup_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return tempDir!.path;
          }
          return null;
        });
  }

  setUpAll(() {
    SecureStorageMock.install();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    tempDir?.deleteSync(recursive: true);
    SecureStorageMock.uninstall();
  });

  group('AppBackupService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppStorage.instance.resetForTesting();
      SecureStorageMock.clear();
    });

    test('exports and restores managed preferences', () async {
      SharedPreferences.setMockInitialValues({
        'active_semester_code': '20251',
        'display_days': 5,
        'show_non_current_week': false,
        'theme_id': 'green',
      });
      AppStorage.instance.resetForTesting();
      await AppStorage.instance.saveCookieSnapshot('secret-cookie');

      final jsonText = await AppBackupService.buildBackupJson();
      final payload = json.decode(jsonText) as Map<String, dynamic>;
      expect(payload['schemaVersion'], AppBackupService.schemaVersion);
      final data = Map<String, dynamic>.from(payload['data'] as Map);
      expect(data.containsKey('last_auto_sync_cookie'), isFalse);

      SharedPreferences.setMockInitialValues({});
      AppStorage.instance.resetForTesting();
      await AppBackupService.restoreFromJson(jsonText);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_semester_code'), '20251');
      expect(prefs.getInt('display_days'), 5);
      expect(prefs.getBool('show_non_current_week'), isFalse);
      expect(prefs.getString('theme_id'), 'green');
      expect(prefs.getString('last_auto_sync_cookie'), isNull);
      expect(await AppStorage.instance.loadCookieSnapshot(), isNull);
    });

    test('exports and restores embedded custom background asset', () async {
      await bindPathProviderTempDir();
      final sourceFile = File('${tempDir!.path}\\source_bg.png');
      await sourceFile.writeAsBytes(const <int>[1, 3, 5, 7], flush: true);

      SharedPreferences.setMockInitialValues({
        'theme_id': 'green',
        'custom_bg_path': sourceFile.path,
      });
      AppStorage.instance.resetForTesting();

      final jsonText = await AppBackupService.buildBackupJson();
      final payload = json.decode(jsonText) as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(payload['data'] as Map);
      expect(data.containsKey('custom_bg_path'), isFalse);

      final assets = Map<String, dynamic>.from(payload['assets'] as Map);
      final customBackground = Map<String, dynamic>.from(
        assets['customBackground'] as Map,
      );
      expect(customBackground['fileName'], 'source_bg.png');
      expect(customBackground['bytesBase64'], isNotEmpty);

      SharedPreferences.setMockInitialValues({'theme_id': 'blue'});
      AppStorage.instance.resetForTesting();

      await AppBackupService.restoreFromJson(jsonText);

      final prefs = await SharedPreferences.getInstance();
      final restoredPath = prefs.getString('custom_bg_path');
      expect(prefs.getString('theme_id'), 'green');
      expect(restoredPath, isNotNull);
      expect(restoredPath, isNot(sourceFile.path));

      final restoredFile = File(restoredPath!);
      expect(await restoredFile.exists(), isTrue);
      expect(await restoredFile.readAsBytes(), const <int>[1, 3, 5, 7]);
    });

    test('keeps current data when restore payload is invalid', () async {
      SharedPreferences.setMockInitialValues({
        'active_semester_code': '20252',
        'theme_id': 'blue',
      });
      AppStorage.instance.resetForTesting();
      await AppStorage.instance.saveCookieSnapshot('cookie=keep-me');

      const invalidBackup = '''
{
  "schemaVersion": 1,
  "exportedAt": "2026-03-31T00:00:00.000Z",
  "data": {
    "theme_id": ["not", 1, "valid"]
  }
}
''';

      await expectLater(
        AppBackupService.restoreFromJson(invalidBackup),
        throwsA(isA<FormatException>()),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_semester_code'), '20252');
      expect(prefs.getString('theme_id'), 'blue');
      expect(await AppStorage.instance.loadCookieSnapshot(), 'cookie=keep-me');
    });

    test('rejects malformed structured backup data before import', () async {
      SharedPreferences.setMockInitialValues({
        'active_semester_code': '20252',
        'theme_id': 'blue',
      });
      AppStorage.instance.resetForTesting();
      await AppStorage.instance.saveCookieSnapshot('cookie=keep-me');

      const invalidBackup = '''
{
  "schemaVersion": 2,
  "exportedAt": "2026-03-31T00:00:00.000Z",
  "data": {
    "schedule_archive_by_semester": "not-json",
    "theme_id": "green"
  }
}
''';

      await expectLater(
        AppBackupService.restoreFromJson(invalidBackup),
        throwsA(isA<FormatException>()),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_semester_code'), '20252');
      expect(prefs.getString('theme_id'), 'blue');
      expect(await AppStorage.instance.loadCookieSnapshot(), 'cookie=keep-me');
    });
  });
}
