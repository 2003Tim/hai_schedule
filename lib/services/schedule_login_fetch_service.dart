import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hai_schedule/models/login_fetch_models.dart';
import 'package:hai_schedule/utils/login_fetch_bridge_handler.dart';
import 'package:hai_schedule/utils/login_fetch_payload_parser.dart';
import 'package:hai_schedule/utils/login_fetch_url_policy.dart';
import 'package:hai_schedule/services/app_repositories.dart';
import 'package:hai_schedule/services/auto_sync_service.dart';
import 'package:hai_schedule/services/schedule_login_script_builder.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/services/schedule_sync_result_service.dart';

export '../models/login_fetch_models.dart';

class ScheduleLoginFetchService {
  ScheduleLoginFetchService({
    ScheduleRepository? scheduleRepository,
    ScheduleSyncResultService? syncResultService,
  }) : _scheduleRepository = scheduleRepository ?? ScheduleRepository(),
       _syncResultService = syncResultService ?? ScheduleSyncResultService();

  final ScheduleRepository _scheduleRepository;
  final ScheduleSyncResultService _syncResultService;

  static const targetUrl = LoginFetchUrlPolicy.targetUrl;

  bool isLoginUrl(String url) => LoginFetchUrlPolicy.isLoginUrl(url);

  bool shouldAutoFetch(String url) => LoginFetchUrlPolicy.shouldAutoFetch(url);

  String buildDetectSemesterScript({
    required String bridgeCall,
    required String requestId,
  }) => ScheduleLoginScriptBuilder.buildDetectSemesterScript(
    bridgeCall: bridgeCall,
    requestId: requestId,
  );

  String buildFetchScheduleScript({
    required String bridgeCall,
    required String semester,
    required String requestId,
  }) => ScheduleLoginScriptBuilder.buildFetchScheduleScript(
    bridgeCall: bridgeCall,
    semester: semester,
    requestId: requestId,
  );

  String buildSwitchSemesterScript({
    required String bridgeCall,
    required String semester,
    required String requestId,
  }) => ScheduleLoginScriptBuilder.buildSwitchSemesterScript(
    bridgeCall: bridgeCall,
    semester: semester,
    requestId: requestId,
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
    final courses = LoginFetchPayloadParser.parseCourses(jsonStr);

    await _syncResultService.applySuccessfulSync(
      provider: provider,
      courses: courses,
      semesterCode: semester,
      rawScheduleJson: jsonStr,
      source: 'login_fetch',
    );

    final cookieReady =
        captureCookieSnapshot
            ? await AutoSyncService.captureCookieSnapshot()
            : false;
    await AutoSyncService.ensureBackgroundSchedule();

    return LoginFetchProcessResult(
      courses: courses,
      cookieSnapshotCaptured: cookieReady,
    );
  }
}
