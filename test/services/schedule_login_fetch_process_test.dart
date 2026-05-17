import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/semester_option.dart';
import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/services/schedule_login_fetch_service.dart';
import 'package:hai_schedule/services/schedule_provider.dart';

import '../test_helpers/secure_storage_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const homeWidgetChannel = MethodChannel('es.antonborri.home_widget');
  const autoSyncChannel = MethodChannel('hai_schedule/auto_sync');
  const nativeCredentialsChannel = MethodChannel(
    'hai_schedule/native_credentials',
  );

  setUpAll(() {
    SecureStorageMock.install();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
          if (call.method == 'pendingNotificationRequests') {
            return <Object?>[];
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(autoSyncChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          nativeCredentialsChannel,
          (call) async => null,
        );
  });

  tearDownAll(() {
    SecureStorageMock.uninstall();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(autoSyncChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeCredentialsChannel, null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppStorage.instance.resetForTesting();
    SecureStorageMock.clear();
  });

  testWidgets(
    'processScheduleJson merges fetched semester catalog before completion',
    (tester) async {
      final provider = ScheduleProvider();
      await provider.ready;
      final service = ScheduleLoginFetchService();

      await tester.pumpWidget(
        ChangeNotifierProvider<ScheduleProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () async {
                    await service.processScheduleJson(
                      context: context,
                      jsonStr: jsonEncode(_samplePayload()),
                      semester: '20252',
                      semesterOptions: const <SemesterOption>[
                        SemesterOption(code: '20252', name: '2025-2026学年 第二学期'),
                        SemesterOption(code: '20251', name: '2025-2026学年 第一学期'),
                      ],
                    );
                  },
                  child: const Text('sync'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('sync'));
      await tester.pumpAndSettle();

      expect(provider.knownSemesterCatalog, const <SemesterOption>[
        SemesterOption(code: '20252', name: '2025-2026学年 第二学期'),
        SemesterOption(code: '20251', name: '2025-2026学年 第一学期'),
      ]);
      expect(provider.availableSemesterOptions.map((item) => item.code), [
        '20252',
        '20251',
      ]);
    },
  );
}

Map<String, dynamic> _samplePayload() {
  return {
    'code': '0',
    'datas': {
      'cxkb': {
        'rows': [
          {
            'WID': 'course-1',
            'KCMC': '人工智能',
            'KCDM': 'SX81232007',
            'BJMC': '人工智能25计科6选3',
            'RKJS': '张老师',
            'KKDW_DISPLAY': '计算机科学与技术学院',
            'XF': 2.0,
            'ZXS': 32.0,
            'XNXQDM_DISPLAY': '2025-2026学年 第二学期',
            'XQDM_DISPLAY': '海甸校区',
            'SKFSDM_DISPLAY': '讲授',
            'SCSKRQ': '2026-03-02',
            'PKSJDD': '1-16周 星期一[1-2节](海甸)2-106',
          },
        ],
      },
    },
  };
}
