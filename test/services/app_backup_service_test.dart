import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/services/app_backup_service.dart';
import 'package:hai_schedule/services/app_storage.dart';

import '../test_helpers/secure_storage_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SecureStorageMock.install();
  });

  tearDownAll(() {
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
  });
}
