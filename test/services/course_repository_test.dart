import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/semester_option.dart';
import 'package:hai_schedule/services/api_service.dart';
import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/services/course_repository.dart';
import 'package:hai_schedule/services/catalog_parsing_exception.dart';
import 'package:hai_schedule/services/portal_redirect_exception.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppStorage.instance.resetForTesting();
  });

  test(
    'syncCourse performs preflight semester catalog fetch when cache is empty',
    () async {
      final apiService = _FakeApiService(
        portalPage: const PortalPageResult(
          body: '''
          <html>
            <body>
              <select>
                <option value="20252">2025-2026学年 第二学期</option>
              </select>
            </body>
          </html>
        ''',
          contentType: 'text/html; charset=utf-8',
        ),
        schedulePayload: _sampleSchedulePayload(),
      );
      final repository = CourseRepository(
        apiService: apiService,
        storage: AppStorage.instance,
      );

      final result = await repository.syncCourse(semester: '20252');
      final options = await AppStorage.instance.loadKnownSemesterOptions();

      expect(apiService.fetchPortalHomePageCount, 1);
      expect(apiService.fetchGraduateScheduleCount, 1);
      expect(options.map((item) => item.code), ['20252']);
      expect(result.courses, hasLength(1));
    },
  );

  test(
    'syncCourse skips semester catalog preflight when cache already exists',
    () async {
      await AppStorage.instance.saveKnownSemesterOptions(const [
        SemesterOption(code: '20252', name: '2025-2026学年 第二学期'),
      ]);
      final apiService = _FakeApiService(
        portalPage: const PortalPageResult(
          body: '<html></html>',
          contentType: 'text/html',
        ),
        schedulePayload: _sampleSchedulePayload(),
      );
      final repository = CourseRepository(
        apiService: apiService,
        storage: AppStorage.instance,
      );

      await repository.syncCourse(semester: '20252');

      expect(apiService.fetchPortalHomePageCount, 0);
      expect(apiService.fetchGraduateScheduleCount, 1);
    },
  );

  test(
    'fetchSemesterCatalog throws PortalRedirectException for non html content',
    () async {
      final apiService = _FakeApiService(
        portalPage: const PortalPageResult(
          body: 'PNG',
          contentType: 'image/png',
        ),
        schedulePayload: _sampleSchedulePayload(),
      );
      final repository = CourseRepository(
        apiService: apiService,
        storage: AppStorage.instance,
      );

      await expectLater(
        repository.fetchSemesterCatalog(),
        throwsA(isA<PortalRedirectException>()),
      );
    },
  );

  test('fetchSemesterCatalog saves catalog and notifies the caller', () async {
    final apiService = _FakeApiService(
      portalPage: const PortalPageResult(
        body: '''
        <html>
          <body>
            <select>
              <option value="20252">2025-2026学年 第二学期</option>
            </select>
          </body>
        </html>
      ''',
        contentType: 'text/html; charset=utf-8',
      ),
      schedulePayload: _sampleSchedulePayload(),
    );
    final repository = CourseRepository(
      apiService: apiService,
      storage: AppStorage.instance,
    );
    List<SemesterOption> notified = const <SemesterOption>[];

    final options = await repository.fetchSemesterCatalog(
      onCatalogUpdated: (nextOptions) async {
        notified = nextOptions;
      },
    );

    expect(options, isNotEmpty);
    expect(notified.map((item) => item.code), ['20252']);
    expect(
      (await AppStorage.instance.loadSemesterCatalog()).map(
        (item) => item.code,
      ),
      ['20252'],
    );
  });

  test(
    'fetchSemesterCatalog throws CatalogParsingException for empty catalog',
    () async {
      final apiService = _FakeApiService(
        portalPage: const PortalPageResult(
          body: '<html><body><div>欢迎使用教务系统</div></body></html>',
          contentType: 'text/html; charset=utf-8',
        ),
        schedulePayload: _sampleSchedulePayload(),
      );
      final repository = CourseRepository(
        apiService: apiService,
        storage: AppStorage.instance,
      );

      await expectLater(
        repository.fetchSemesterCatalog(),
        throwsA(isA<CatalogParsingException>()),
      );
    },
  );
}

class _FakeApiService extends ApiService {
  _FakeApiService({required this.portalPage, required this.schedulePayload});

  final PortalPageResult portalPage;
  final Map<String, dynamic> schedulePayload;
  int fetchPortalHomePageCount = 0;
  int fetchGraduateScheduleCount = 0;
  String? _cookie;

  @override
  String? get currentCookie => _cookie;

  @override
  void updateCookie(String cookie) {
    _cookie = cookie;
  }

  @override
  Future<PortalPageResult> fetchPortalHomePage() async {
    fetchPortalHomePageCount += 1;
    return portalPage;
  }

  @override
  Future<Map<String, dynamic>> fetchGraduateScheduleRaw({
    required String semester,
  }) async {
    fetchGraduateScheduleCount += 1;
    return schedulePayload;
  }
}

Map<String, dynamic> _sampleSchedulePayload() {
  return <String, dynamic>{
    'code': '0',
    'datas': <String, dynamic>{
      'cxkb': <String, dynamic>{
        'rows': <Map<String, dynamic>>[
          <String, dynamic>{
            'WID': 'course-1',
            'KCMC': '软件工程',
            'KCDM': 'SE001',
            'BJMC': '计科一班',
            'RKJS': '陈老师',
            'KKDW_DISPLAY': '计算机学院',
            'XF': 3.0,
            'ZXS': 48.0,
            'XNXQDM_DISPLAY': '2025-2026学年 第二学期',
            'XQDM_DISPLAY': '海甸校区',
            'SKFSDM_DISPLAY': '讲授',
            'PKSJDD': '1-16周 星期一[1-2节](海甸)2-101',
          },
        ],
      },
    },
  };
}
