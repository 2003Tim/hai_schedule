import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/login_fetch_models.dart';
import '../utils/login_fetch_bridge_handler.dart';
import '../utils/login_fetch_payload_parser.dart';
import '../utils/login_fetch_url_policy.dart';
import 'app_repositories.dart';
import 'auto_sync_service.dart';
import 'schedule_login_script_builder.dart';
import 'schedule_provider.dart';

export '../models/login_fetch_models.dart';

class ScheduleLoginFetchService {
  ScheduleLoginFetchService({
    ScheduleRepository? scheduleRepository,
    SyncRepository? syncRepository,
  }) : _scheduleRepository = scheduleRepository ?? ScheduleRepository(),
       _syncRepository = syncRepository ?? SyncRepository();

  final ScheduleRepository _scheduleRepository;
  final SyncRepository _syncRepository;

  static const targetUrl = LoginFetchUrlPolicy.targetUrl;

  bool isLoginUrl(String url) => LoginFetchUrlPolicy.isLoginUrl(url);

  bool shouldAutoFetch(String url) => LoginFetchUrlPolicy.shouldAutoFetch(url);

  String buildDetectSemesterScript(String bridgeCall) =>
      ScheduleLoginScriptBuilder.buildDetectSemesterScript(bridgeCall);

  String buildFetchScheduleScript({
    required String bridgeCall,
    required String semester,
  }) => ScheduleLoginScriptBuilder.buildFetchScheduleScript(
    bridgeCall: bridgeCall,
    semester: semester,
  );

  String buildSwitchSemesterScript({
    required String bridgeCall,
    required String semester,
  }) => ScheduleLoginScriptBuilder.buildSwitchSemesterScript(
    bridgeCall: bridgeCall,
    semester: semester,
  );

  String buildFillCredentialScript({
    required String username,
    required String password,
    String? bridgeCall,
    bool autoSubmit = true,
  }) => ScheduleLoginScriptBuilder.buildFillCredentialScript(
    username: username,
    password: password,
    bridgeCall: bridgeCall,
    autoSubmit: autoSubmit,
  );

  Future<void> saveSemesterCode(String semester) {
    return _scheduleRepository.saveSemesterCode(semester);
  }

  void handleBridgeMessage({
    required String message,
    required LoginFetchChunkState chunkState,
    required ValueChanged<String> onStatus,
    required ValueChanged<String> onSemesterDetected,
    required ValueChanged<String> onSemesterSwitched,
    required ValueChanged<String> onPayloadReady,
    required ValueChanged<String> onError,
    ValueChanged<String>? onAutofillStatus,
    ValueChanged<LoginAutofillResult>? onAutofillResult,
  }) => LoginFetchBridgeHandler.handle(
    message: message,
    chunkState: chunkState,
    onStatus: onStatus,
    onSemesterDetected: onSemesterDetected,
    onSemesterSwitched: onSemesterSwitched,
    onPayloadReady: onPayloadReady,
    onError: onError,
    onAutofillStatus: onAutofillStatus,
    onAutofillResult: onAutofillResult,
  );

  Future<LoginFetchProcessResult> processScheduleJson({
    required BuildContext context,
    required String jsonStr,
    String? semester,
    bool captureCookieSnapshot = false,
  }) async {
    final provider = context.read<ScheduleProvider>();
    final previousCourses = List<Course>.from(provider.courses);
    final courses = LoginFetchPayloadParser.parseCourses(jsonStr);

    await _syncRepository.saveLastFetchTime(DateTime.now());
    await provider.setCourses(
      courses,
      semesterCode: semester,
      rawScheduleJson: jsonStr,
    );

    final cookieReady =
        captureCookieSnapshot
            ? await AutoSyncService.captureCookieSnapshot()
            : false;
    final diffSummary = AutoSyncService.buildCourseDiffSummary(
      previousCourses,
      courses,
    );
    await AutoSyncService.recordExternalSyncSuccess(
      courseCount: courses.length,
      source: 'login_fetch',
      diffSummary: diffSummary,
    );

    return LoginFetchProcessResult(
      courses: courses,
      cookieSnapshotCaptured: cookieReady,
    );
  }
}
