import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/services/app_repositories.dart';
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppStorage.instance.resetForTesting();
    SecureStorageMock.clear();
  });

  group('ScheduleRepository', () {
    test('saves and loads imported schedule cache', () async {
      final repository = ScheduleRepository();
      final course = Course(
        id: 'c1',
        code: 'MATH001',
        name: '高等数学',
        className: '数学一班',
        teacher: '张老师',
        college: '理学院',
        credits: 4,
        totalHours: 64,
        semester: '2024-2025-2',
        slots: [
          ScheduleSlot(
            courseId: 'c1',
            courseName: '高等数学',
            weekday: 1,
            startSection: 1,
            endSection: 2,
            location: '教一-101',
            weekRanges: [
              WeekRange(start: 1, end: 16),
            ],
          ),
        ],
      );

      await repository.saveImportedSchedule(
        rawScheduleJson: '{"code":"0"}',
        semesterCode: '20252',
        courses: [course],
      );

      final cache = await repository.loadCache();
      expect(cache.rawScheduleJson, '{"code":"0"}');
      expect(cache.semesterCode, '20252');
      expect(cache.courses, hasLength(1));
      expect(cache.courses.first.name, '高等数学');
      expect(cache.courses.first.slots.first.location, '教一-101');
    });

    test('keeps schedule archives isolated by semester and switches active semester', () async {
      final repository = ScheduleRepository();
      final course20251 = Course(
        id: 'c-20251',
        code: 'ENG001',
        name: '大学英语',
        className: '英语一班',
        teacher: '李老师',
        college: '外国语学院',
        credits: 2,
        totalHours: 32,
        semester: '2024-2025-1',
        slots: [
          ScheduleSlot(
            courseId: 'c-20251',
            courseName: '大学英语',
            weekday: 2,
            startSection: 3,
            endSection: 4,
            location: '教二-203',
            weekRanges: [WeekRange(start: 1, end: 16)],
          ),
        ],
      );
      final course20252 = Course(
        id: 'c-20252',
        code: 'PHY001',
        name: '大学物理',
        className: '物理二班',
        teacher: '王老师',
        college: '理学院',
        credits: 3,
        totalHours: 48,
        semester: '2024-2025-2',
        slots: [
          ScheduleSlot(
            courseId: 'c-20252',
            courseName: '大学物理',
            weekday: 4,
            startSection: 1,
            endSection: 2,
            location: '教三-105',
            weekRanges: [WeekRange(start: 1, end: 16)],
          ),
        ],
      );

      await repository.saveSemesterSchedule(
        semesterCode: '20251',
        rawScheduleJson: '{"semester":"20251"}',
        courses: [course20251],
        makeActive: true,
      );
      await repository.saveSemesterSchedule(
        semesterCode: '20252',
        rawScheduleJson: '{"semester":"20252"}',
        courses: [course20252],
        makeActive: true,
      );

      final availableCodes = await repository.loadAvailableSemesterCodes();
      expect(availableCodes, containsAll(['20251', '20252']));
      expect(await repository.loadActiveSemesterCode(), '20252');

      await repository.saveActiveSemesterCode('20251');
      final activeCache = await repository.loadCache();
      expect(activeCache.semesterCode, '20251');
      expect(activeCache.rawScheduleJson, '{"semester":"20251"}');
      expect(activeCache.courses.single.name, '大学英语');

      final springCache = await repository.loadCache(semesterCode: '20252');
      expect(springCache.semesterCode, '20252');
      expect(springCache.rawScheduleJson, '{"semester":"20252"}');
      expect(springCache.courses.single.name, '大学物理');
    });

    test('switching to an empty semester clears mirrored active cache', () async {
      final repository = ScheduleRepository();
      final course = Course(
        id: 'c-20251',
        code: 'ENG001',
        name: '大学英语',
        className: '英语一班',
        teacher: '李老师',
        college: '外国语学院',
        credits: 2,
        totalHours: 32,
        semester: '2024-2025-1',
        slots: [
          ScheduleSlot(
            courseId: 'c-20251',
            courseName: '大学英语',
            weekday: 2,
            startSection: 3,
            endSection: 4,
            location: '教二-203',
            weekRanges: [WeekRange(start: 1, end: 16)],
          ),
        ],
      );

      await repository.saveSemesterSchedule(
        semesterCode: '20251',
        rawScheduleJson: '{"semester":"20251"}',
        courses: [course],
        makeActive: true,
      );
      await repository.createEmptySemester(
        semesterCode: '20252',
        makeActive: true,
      );

      final activeCache = await repository.loadCache();
      expect(activeCache.semesterCode, '20252');
      expect(activeCache.courses, isEmpty);
      expect(activeCache.rawScheduleJson, isNull);
    });

    test('deleting active semester preserves overrides from other semesters', () async {
      final scheduleRepository = ScheduleRepository();
      final overrideRepository = ScheduleOverrideRepository();

      final fallCourse = Course(
        id: 'c-20251',
        code: 'ENG001',
        name: '大学英语',
        className: '英语一班',
        teacher: '李老师',
        college: '外国语学院',
        credits: 2,
        totalHours: 32,
        semester: '2024-2025-1',
        slots: [
          ScheduleSlot(
            courseId: 'c-20251',
            courseName: '大学英语',
            weekday: 2,
            startSection: 3,
            endSection: 4,
            location: '教二-203',
            weekRanges: [WeekRange(start: 1, end: 16)],
          ),
        ],
      );
      final springCourse = Course(
        id: 'c-20252',
        code: 'PHY001',
        name: '大学物理',
        className: '物理二班',
        teacher: '王老师',
        college: '理学院',
        credits: 3,
        totalHours: 48,
        semester: '2024-2025-2',
        slots: [
          ScheduleSlot(
            courseId: 'c-20252',
            courseName: '大学物理',
            weekday: 4,
            startSection: 1,
            endSection: 2,
            location: '教三-105',
            weekRanges: [WeekRange(start: 1, end: 16)],
          ),
        ],
      );

      await scheduleRepository.saveSemesterSchedule(
        semesterCode: '20251',
        rawScheduleJson: '{"semester":"20251"}',
        courses: [fallCourse],
        makeActive: true,
      );
      await scheduleRepository.saveSemesterSchedule(
        semesterCode: '20252',
        rawScheduleJson: '{"semester":"20252"}',
        courses: [springCourse],
        makeActive: true,
      );
      await overrideRepository.save(
        semesterCode: '20251',
        overrides: const [
          ScheduleOverride(
            id: 'fall-override',
            semesterCode: '20251',
            dateKey: '2025-10-08',
            weekday: 3,
            startSection: 1,
            endSection: 2,
            type: ScheduleOverrideType.cancel,
            targetCourseId: 'c-20251',
            sourceStartSection: 1,
            sourceEndSection: 2,
          ),
        ],
      );
      await overrideRepository.save(
        semesterCode: '20252',
        overrides: const [
          ScheduleOverride(
            id: 'spring-override',
            semesterCode: '20252',
            dateKey: '2026-03-30',
            weekday: 1,
            startSection: 5,
            endSection: 6,
            type: ScheduleOverrideType.add,
            courseName: '临时加课',
            location: '教四-201',
          ),
        ],
      );

      await scheduleRepository.deleteSemester('20252');

      final availableCodes = await scheduleRepository.loadAvailableSemesterCodes();
      final activeCache = await scheduleRepository.loadCache();
      final fallOverrides = await overrideRepository.load('20251');
      final springOverrides = await overrideRepository.load('20252');

      expect(availableCodes, ['20251']);
      expect(await scheduleRepository.loadActiveSemesterCode(), '20251');
      expect(activeCache.semesterCode, '20251');
      expect(activeCache.courses.single.name, '大学英语');
      expect(fallOverrides, hasLength(1));
      expect(fallOverrides.single.id, 'fall-override');
      expect(springOverrides, isEmpty);
    });
  });

  group('SchedulePreferencesRepository', () {
    test('persists schedule view preferences', () async {
      final repository = SchedulePreferencesRepository();

      await repository.save(displayDays: 5, showNonCurrentWeek: false);
      final preferences = await repository.load();

      expect(preferences.displayDays, 5);
      expect(preferences.showNonCurrentWeek, isFalse);
    });
  });

  group('SyncRepository', () {
    test('persists sync settings and cookie snapshot', () async {
      final repository = SyncRepository();
      final now = DateTime(2026, 3, 29, 10, 30);
      final next = now.add(const Duration(hours: 6));

      await repository.saveFrequency(
        'custom',
        customIntervalMinutes: 18 * 60,
      );
      await repository.saveCookieSnapshot('cookie=abc');
      await repository.saveStatus(
        state: 'success',
        message: '同步完成',
        source: 'test',
        diffSummary: '新增 1 门',
        lastFetchTime: now,
        lastAttemptTime: now,
        nextSyncTime: next,
      );

      final record = await repository.loadRecord();
      expect(record.frequency, 'custom');
      expect(record.customIntervalMinutes, 18 * 60);
      expect(record.cookieSnapshot, 'cookie=abc');
      expect(record.state, 'success');
      expect(record.message, '同步完成');
      expect(record.lastSource, 'test');
      expect(record.lastDiffSummary, '新增 1 门');
      expect(record.lastFetchTime, now);
      expect(record.lastAttemptTime, now);
      expect(record.nextSyncTime, next);
    });
  });

  group('ReminderRepository', () {
    test('persists reminder settings and state', () async {
      final repository = ReminderRepository();
      final buildTime = DateTime(2026, 3, 29, 8, 0);
      final horizonEnd = buildTime.add(const Duration(days: 2));

      await repository.saveLeadMinutes(20);
      await repository.saveState(
        scheduledCount: 6,
        lastBuildTime: buildTime,
        horizonEnd: horizonEnd,
        exactAlarmEnabled: true,
      );

      final record = await repository.loadRecord();
      expect(record.leadMinutes, 20);
      expect(record.scheduledCount, 6);
      expect(record.lastBuildTime, buildTime);
      expect(record.horizonEnd, horizonEnd);
      expect(record.exactAlarmEnabled, isTrue);
    });
  });

  group('ScheduleOverrideRepository', () {
    test('persists overrides per semester', () async {
      final repository = ScheduleOverrideRepository();
      const override20251 = ScheduleOverride(
        id: 'o1',
        semesterCode: '20251',
        dateKey: '2025-12-01',
        weekday: 1,
        startSection: 1,
        endSection: 2,
        type: ScheduleOverrideType.cancel,
        targetCourseId: 'c1',
      );
      const override20252 = ScheduleOverride(
        id: 'o2',
        semesterCode: '20252',
        dateKey: '2026-03-30',
        weekday: 1,
        startSection: 5,
        endSection: 6,
        type: ScheduleOverrideType.add,
        courseName: '临时加课',
        location: '教四-201',
      );

      await repository.save(
        semesterCode: '20251',
        overrides: [override20251],
      );
      await repository.save(
        semesterCode: '20252',
        overrides: [override20252],
      );

      final fallOverrides = await repository.load('20251');
      final springOverrides = await repository.load('20252');

      expect(fallOverrides, hasLength(1));
      expect(fallOverrides.single.type, ScheduleOverrideType.cancel);
      expect(springOverrides, hasLength(1));
      expect(springOverrides.single.courseName, '临时加课');
      expect(springOverrides.single.location, '教四-201');
    });
  });
}


