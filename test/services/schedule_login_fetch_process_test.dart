import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/semester_option.dart';
import 'package:hai_schedule/models/schedule_source.dart';
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

  testWidgets(
    'processScheduleJson applies undergraduate school time and catalog',
    (tester) async {
      final provider = ScheduleProvider();
      await provider.ready;
      final service = ScheduleLoginFetchService(
        source: ScheduleSource.undergraduate,
      );

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
                      jsonStr: _undergraduateHtml,
                      semester: '20242',
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

      expect(provider.currentSemesterCode, '20242');
      expect(provider.timeConfig.name, '海南大学本科');
      expect(provider.timeConfig.classTimes, hasLength(15));
      expect(provider.timeConfig.getClassTime(12)?.startTime, '11:35');
      expect(provider.courses.single.name, '形势与政策8');
      expect(provider.knownSemesterCatalog.map((item) => item.code), ['20242']);
      expect(
        await AppStorage.instance.loadActiveScheduleSource(),
        ScheduleSource.undergraduate,
      );
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

const _undergraduateHtml = '''
<!doctype html>
<html>
<body>
<select id="xnxq01id">
  <option selected value="2024-2025-2">2024-2025-2</option>
</select>
<table id="timetable">
  <tr><th>&nbsp;</th><th>星期一</th><th>星期二</th></tr>
  <tr><th>1、2节<br>(01,02小节)<br>07:40-09:20</th><td></td><td></td></tr>
  <tr><th>3、4节<br>(03,04小节)<br>09:45-11:25</th><td></td><td></td></tr>
  <tr><th>5、6节<br>(05,06小节)<br>14:30-16:10</th><td></td><td></td></tr>
  <tr><th>7、8节<br>(07,08小节)<br>16:35-18:15</th><td></td><td></td></tr>
  <tr><th>9、10、11节<br>(09,10,11小节)<br>19:20-21:55</th><td></td><td>
    <div class="kbcontent">
      <font>形势与政策8</font><font title="教师">郎筱宇()</font>
      <font title="周次(节次)">10-11(周)[09-10节]</font>
      <font title="教室">(海甸)3-308</font>
      <font title="通知单编号">通知单编号：202420252012135</font>
    </div>
  </td></tr>
  <tr><th>中午节次(一)<br>(12,13小节)<br>11:35-13:05</th><td></td><td></td></tr>
  <tr><th>中午节次(二)<br>(14,15小节)<br>13:05-14:20</th><td></td><td></td></tr>
</table>
</body>
</html>
''';
