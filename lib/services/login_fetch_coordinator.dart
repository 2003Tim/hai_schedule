import 'dart:async';

import 'package:flutter/material.dart';

import '../models/login_fetch_coordinator_models.dart';
import '../utils/login_fetch_coordinator_text.dart';
import '../utils/semester_code_formatter.dart' as semester_formatter;
import 'schedule_login_fetch_service.dart';

export '../models/login_fetch_coordinator_models.dart';

class LoginFetchCoordinator {
  LoginFetchCoordinator({ScheduleLoginFetchService? loginFetchService})
    : _loginFetchService = loginFetchService ?? ScheduleLoginFetchService();

  static const fetchTimeout = Duration(seconds: 25);

  final ScheduleLoginFetchService _loginFetchService;

  String? messageForAutofillStatus(String status) {
    return LoginFetchCoordinatorText.messageForAutofillStatus(status);
  }

  LoginAutofillStateResolution resolveAutofillResult(
    LoginAutofillResult result, {
    required int attemptCount,
  }) {
    return LoginFetchCoordinatorText.resolveAutofillResult(
      result,
      attemptCount: attemptCount,
    );
  }

  bool looksLikeSemesterCode(String value) {
    return semester_formatter.looksLikeSemesterCode(value);
  }

  String formatSemesterCode(String code) {
    return semester_formatter.formatSemesterCode(code);
  }

  Future<void> startAutoFetch({
    required String? selectedSemesterCode,
    required LoginFetchChunkState chunkState,
    required Duration warmupDelay,
    required String bridgeCall,
    required Future<void> Function(String script) executeScript,
    required bool Function() isStillFetching,
    required ValueChanged<LoginFetchUiStateUpdate> applyState,
  }) async {
    applyState(
      LoginFetchUiStateUpdate(
        isFetching: true,
        pendingAutofill: false,
        statusText: LoginFetchCoordinatorText.initialFetchStatus(
          selectedSemesterCode,
        ),
      ),
    );

    chunkState.reset();
    await Future.delayed(warmupDelay);
    if (!isStillFetching()) return;

    try {
      if (selectedSemesterCode != null) {
        applyState(
          LoginFetchUiStateUpdate(
            statusText: LoginFetchCoordinatorText.switchingSemesterStatus(
              selectedSemesterCode,
            ),
          ),
        );
        await executeScript(
          _loginFetchService.buildSwitchSemesterScript(
            bridgeCall: bridgeCall,
            semester: selectedSemesterCode,
          ),
        );
        return;
      }

      await executeScript(
        _loginFetchService.buildDetectSemesterScript(bridgeCall),
      );

      unawaited(
        Future<void>.delayed(fetchTimeout, () {
          if (!isStillFetching()) return;
          applyState(
            const LoginFetchUiStateUpdate(
              isFetching: false,
              statusText: LoginFetchCoordinatorText.timeoutStatus,
            ),
          );
        }),
      );
    } catch (e) {
      applyState(
        LoginFetchUiStateUpdate(
          isFetching: false,
          statusText: LoginFetchCoordinatorText.executeFailure(e),
        ),
      );
    }
  }

  Future<void> fetchWithSemester({
    required String semester,
    required String bridgeCall,
    required Future<void> Function(String script) executeScript,
    required ValueChanged<String> onSemesterResolved,
    required ValueChanged<LoginFetchUiStateUpdate> applyState,
    Future<void> Function(String semester)? persistSemesterCode,
  }) async {
    onSemesterResolved(semester);
    applyState(
      LoginFetchUiStateUpdate(
        statusText: LoginFetchCoordinatorText.fetchSemesterStatus(semester),
      ),
    );

    try {
      if (persistSemesterCode != null) {
        await persistSemesterCode(semester);
      }
      await executeScript(
        _loginFetchService.buildFetchScheduleScript(
          bridgeCall: bridgeCall,
          semester: semester,
        ),
      );
    } catch (e) {
      applyState(
        LoginFetchUiStateUpdate(
          isFetching: false,
          statusText: LoginFetchCoordinatorText.requestFailure(e),
        ),
      );
    }
  }

  void handleBridgeMessage({
    required String message,
    required LoginFetchChunkState chunkState,
    required ValueChanged<LoginFetchUiStateUpdate> applyState,
    required Future<void> Function(String semester) onSemesterReady,
    required Future<void> Function(String jsonStr) onPayloadReady,
    required ValueChanged<String> onAutofillStatus,
    required ValueChanged<LoginAutofillResult> onAutofillResult,
    String emptySemesterMessage =
        LoginFetchCoordinatorText.emptySemesterMessage,
  }) {
    _loginFetchService.handleBridgeMessage(
      message: message,
      chunkState: chunkState,
      onStatus:
          (status) => applyState(LoginFetchUiStateUpdate(statusText: status)),
      onSemesterDetected: (semester) {
        if (semester.isEmpty) {
          applyState(
            LoginFetchUiStateUpdate(
              isFetching: false,
              statusText: emptySemesterMessage,
            ),
          );
          return;
        }
        unawaited(onSemesterReady(semester));
      },
      onSemesterSwitched: (semester) {
        unawaited(onSemesterReady(semester));
      },
      onPayloadReady: (jsonStr) {
        unawaited(onPayloadReady(jsonStr));
      },
      onError: (error) {
        applyState(
          LoginFetchUiStateUpdate(
            isFetching: false,
            statusText: LoginFetchCoordinatorText.requestFailure(error),
          ),
        );
      },
      onAutofillStatus: onAutofillStatus,
      onAutofillResult: onAutofillResult,
    );
  }

  Future<void> processFetchedData({
    required BuildContext context,
    required String jsonStr,
    required String? semester,
    required ValueChanged<LoginFetchUiStateUpdate> applyState,
  }) async {
    try {
      final result = await _loginFetchService.processScheduleJson(
        context: context,
        jsonStr: jsonStr,
        semester: semester,
        captureCookieSnapshot: true,
      );

      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            LoginFetchCoordinatorText.successSnackBarText(
              courseCount: result.courses.length,
              cookieSnapshotCaptured: result.cookieSnapshotCaptured,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );

      applyState(
        const LoginFetchUiStateUpdate(
          isFetching: false,
          statusText: LoginFetchCoordinatorText.fetchCompletedStatus,
        ),
      );

      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 800), () {
          if (context.mounted) {
            navigator.pop();
          }
        }),
      );
    } on LoginFetchException catch (e) {
      applyState(
        LoginFetchUiStateUpdate(isFetching: false, statusText: e.message),
      );
    } catch (e) {
      applyState(
        LoginFetchUiStateUpdate(
          isFetching: false,
          statusText: LoginFetchCoordinatorText.parseFailure(e),
        ),
      );
    }
  }
}
