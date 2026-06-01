import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hai_schedule/models/login_fetch_models.dart';
import 'package:hai_schedule/models/schedule_source.dart';
import 'package:hai_schedule/models/semester_option.dart';
import 'package:hai_schedule/models/undergraduate_schedule_parser.dart';
import 'package:hai_schedule/utils/login_fetch_bridge_handler.dart';
import 'package:hai_schedule/utils/login_fetch_payload_parser.dart';
import 'package:hai_schedule/utils/login_fetch_url_policy.dart';
import 'package:hai_schedule/utils/undergraduate_schedule_login_scripts.dart';
import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/services/auto_sync_service.dart';
import 'package:hai_schedule/services/schedule_login_script_builder.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/services/schedule_sync_result_service.dart';

export '../models/login_fetch_models.dart';

class ScheduleLoginFetchService {
  ScheduleLoginFetchService({
    this.source = ScheduleSource.graduate,
    ScheduleSyncResultService? syncResultService,
  }) : _syncResultService = syncResultService ?? ScheduleSyncResultService();

  final ScheduleSource source;
  final ScheduleSyncResultService _syncResultService;

  static const targetUrl = LoginFetchUrlPolicy.targetUrl;

  String get resolvedInitialUrl =>
      source.isUndergraduate ? resolvedLoginEntryUrl : resolvedTargetUrl;

  String get resolvedTargetUrl =>
      source.isUndergraduate
          ? UndergraduateScheduleLoginScripts.targetUrl
          : targetUrl;

  String get resolvedLoginEntryUrl =>
      source.isUndergraduate
          ? UndergraduateScheduleLoginScripts.loginEntryUrl
          : targetUrl;

  String? normalizeNavigationUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    // Defence-in-depth (#S2): every accepted URL must be on a known
    // university host. Previously the graduate path returned null
    // unconditionally, which let the WebView accept and run scripts on
    // arbitrary URLs.
    if (scheme != 'http' && scheme != 'https') return null;
    if (host != 'jxgl.hainanu.edu.cn' && host != 'ehall.hainanu.edu.cn' &&
        host != 'authserver.hainanu.edu.cn') {
      return null;
    }
    if (scheme == 'http') {
      return uri.replace(scheme: 'https').toString();
    }
    return uri.toString();
  }

  bool isLoginUrl(String url) {
    if (source.isGraduate) return LoginFetchUrlPolicy.isLoginUrl(url);
    final urlLower = url.toLowerCase();
    return urlLower.contains('login') ||
        urlLower.contains('authserver') ||
        urlLower.contains('/cas/');
  }

  bool shouldAutoFetch(String url) {
    if (source.isGraduate) return LoginFetchUrlPolicy.shouldAutoFetch(url);
    final urlLower = url.toLowerCase();
    final isTarget =
        urlLower.contains('/jsxsd/xskb/xskb_list.do') ||
        urlLower.contains('/jsxsd/framework/xsmain');
    return isTarget && !isLoginUrl(url);
  }

  bool shouldProbePageState(String url) {
    if (source.isGraduate) return false;
    final urlLower = url.toLowerCase();
    return urlLower.contains('jxgl.hainanu.edu.cn') ||
        urlLower.contains('/jsxsd/');
  }

  String buildPageStateProbeScript({required String bridgeCall}) =>
      source.isUndergraduate
          ? UndergraduateScheduleLoginScripts.buildPageStateProbeScript(
            bridgeCall: bridgeCall,
          )
          : ScheduleLoginScriptBuilder.buildPostVerificationProbeScript(
            bridgeCall: bridgeCall,
          );

  String buildDetectSemesterScript({
    required String bridgeCall,
    required String requestId,
  }) =>
      source.isUndergraduate
          ? UndergraduateScheduleLoginScripts.buildDetectSemesterScript(
            bridgeCall: bridgeCall,
            requestId: requestId,
          )
          : ScheduleLoginScriptBuilder.buildDetectSemesterScript(
            bridgeCall: bridgeCall,
            requestId: requestId,
          );

  String buildFetchScheduleScript({
    required String bridgeCall,
    required String semester,
    required String requestId,
  }) =>
      source.isUndergraduate
          ? UndergraduateScheduleLoginScripts.buildFetchScheduleScript(
            bridgeCall: bridgeCall,
            semester: semester,
            requestId: requestId,
          )
          : ScheduleLoginScriptBuilder.buildFetchScheduleScript(
            bridgeCall: bridgeCall,
            semester: semester,
            requestId: requestId,
          );

  String buildSwitchSemesterScript({
    required String bridgeCall,
    required String semester,
    required String requestId,
  }) =>
      source.isUndergraduate
          ? UndergraduateScheduleLoginScripts.buildSwitchSemesterScript(
            bridgeCall: bridgeCall,
            semester: semester,
            requestId: requestId,
          )
          : ScheduleLoginScriptBuilder.buildSwitchSemesterScript(
            bridgeCall: bridgeCall,
            semester: semester,
            requestId: requestId,
          );

  String buildFillCredentialScript({
    required String username,
    required String password,
    String? bridgeCall,
    bool autoSubmit = true,
    bool enableTrustOption = true,
  }) => ScheduleLoginScriptBuilder.buildFillCredentialScript(
    username: username,
    password: password,
    bridgeCall: bridgeCall,
    autoSubmit: source.isUndergraduate ? false : autoSubmit,
    enableTrustOption: enableTrustOption,
  );

  String buildManualLoginObserverScript({required String bridgeCall}) =>
      ScheduleLoginScriptBuilder.buildManualLoginObserverScript(
        bridgeCall: bridgeCall,
      );

  String buildPostVerificationProbeScript({required String bridgeCall}) =>
      ScheduleLoginScriptBuilder.buildPostVerificationProbeScript(
        bridgeCall: bridgeCall,
      );

  void handleBridgeMessage({
    required String message,
    required LoginFetchChunkState chunkState,
    required ValueChanged<String> onStatus,
    required ValueChanged<String> onSemesterDetected,
    required ValueChanged<List<SemesterOption>> onSemesterOptions,
    required ValueChanged<String> onSemesterSwitched,
    required ValueChanged<String> onPayloadReady,
    required ValueChanged<String> onError,
    ValueChanged<String>? onLoginError,
    ValueChanged<String>? onAutofillStatus,
    ValueChanged<LoginAutofillResult>? onAutofillResult,
  }) => LoginFetchBridgeHandler.handle(
    message: message,
    chunkState: chunkState,
    onStatus: onStatus,
    onSemesterDetected: onSemesterDetected,
    onSemesterOptions: onSemesterOptions,
    onSemesterSwitched: onSemesterSwitched,
    onPayloadReady: onPayloadReady,
    onError: onError,
    onLoginError: onLoginError,
    onAutofillStatus: onAutofillStatus,
    onAutofillResult: onAutofillResult,
  );

  Future<LoginFetchProcessResult> processScheduleJson({
    required BuildContext context,
    required String jsonStr,
    String? semester,
    List<SemesterOption> semesterOptions = const <SemesterOption>[],
    bool persistLoginSession = false,
  }) async {
    final provider = context.read<ScheduleProvider>();
    await AppStorage.instance.saveActiveScheduleSource(source);

    UndergraduateScheduleParseResult? undergraduateResult;
    final courses =
        source.isUndergraduate
            ? () {
              undergraduateResult = UndergraduateScheduleParser.parseHtml(
                jsonStr,
              );
              final parsedCourses = undergraduateResult!.courses;
              if (parsedCourses.isEmpty) {
                throw const LoginFetchException('未解析到课程数据');
              }
              return parsedCourses;
            }()
            : LoginFetchPayloadParser.parseCourses(jsonStr, source: source);

    final resolvedSemester =
        semester?.trim().isNotEmpty == true
            ? semester!.trim()
            : undergraduateResult?.semesterCode;
    final resolvedSemesterOptions = _mergeSemesterOptions(
      semesterOptions,
      undergraduateResult?.semesterOptions ?? const <SemesterOption>[],
    );

    if (resolvedSemesterOptions.isNotEmpty) {
      await provider.mergeKnownSemesterOptions(resolvedSemesterOptions);
    } else {
      // semesterOptions 为空时（教务系统未返回学期列表、或走自动同步路径），
      // 至少从磁盘刷新一次内存 catalog，保证 provider 数据与磁盘一致。
      await provider.refreshKnownSemesterCatalog();
    }
    if (undergraduateResult != null) {
      await provider.updateTimeConfig(undergraduateResult!.schoolTimeConfig);
    }

    await _syncResultService.applySuccessfulSync(
      provider: provider,
      courses: courses,
      semesterCode: resolvedSemester,
      rawScheduleJson: jsonStr,
      source: 'login_fetch',
    );

    final cookieReady =
        persistLoginSession
            ? await AutoSyncService.captureCookieSnapshot()
            : false;
    await AutoSyncService.ensureBackgroundSchedule();

    return LoginFetchProcessResult(
      courses: courses,
      cookieSnapshotCaptured: cookieReady,
    );
  }

  List<SemesterOption> _mergeSemesterOptions(
    List<SemesterOption> primary,
    List<SemesterOption> secondary,
  ) {
    if (primary.isEmpty) return secondary;
    if (secondary.isEmpty) return primary;

    final merged = <String, SemesterOption>{};
    for (final option in [...primary, ...secondary]) {
      if (!option.isValid) continue;
      merged[option.normalizedCode] = SemesterOption(
        code: option.normalizedCode,
        name: option.normalizedName,
      );
    }
    return merged.values.toList(growable: false);
  }
}
