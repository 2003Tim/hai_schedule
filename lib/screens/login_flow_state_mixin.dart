import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_credentials_service.dart';
import '../services/login_fetch_coordinator.dart';
import '../services/schedule_login_fetch_service.dart';
import '../services/schedule_provider.dart';
import '../utils/login_flow_autofill_controller.dart';
import '../utils/login_flow_text.dart';
import '../widgets/login_flow_sections.dart';
import '../widgets/login_webview_adapters.dart';

mixin LoginFlowStateMixin<T extends StatefulWidget> on State<T> {
  final ScheduleLoginFetchService loginFetchService =
      ScheduleLoginFetchService();
  late final LoginFetchCoordinator _loginFlowCoordinator =
      LoginFetchCoordinator(loginFetchService: loginFetchService);
  late final LoginWebviewAdapter _webviewAdapter = createWebviewAdapter();
  final LoginFlowAutofillController _autofillController =
      LoginFlowAutofillController();
  final LoginFetchChunkState _chunkState = LoginFetchChunkState();

  bool _isWebviewReady = false;
  bool _isFetching = false;
  bool _rememberPassword = false;
  bool _suspendLoginAutomation = false;
  bool _credentialEditorOpened = false;
  String _statusText = '';
  String? _lastDetectedSemester;
  String? _selectedSemesterCode;
  SavedPortalCredential? _savedCredential;

  LoginWebviewAdapter createWebviewAdapter();

  String get bridgeCall;

  Duration get autoFetchWarmupDelay;

  String get initialStatusText;

  String? get readyStatusText => null;

  String? get initialSemesterCode;

  bool get shouldOpenCredentialEditor;

  Future<void> persistSemesterCode(String semester) async {}

  void initLoginFlow() {
    _statusText = initialStatusText;
    _selectedSemesterCode = initialSemesterCode;
    _suspendLoginAutomation = shouldOpenCredentialEditor;
    _loadSavedCredential();
    unawaited(_initWebview());
  }

  void disposeLoginFlow() {
    _autofillController.dispose();
    _webviewAdapter.dispose();
  }

  Future<void> _loadSavedCredential() async {
    final credential = await AuthCredentialsService.instance.load();
    if (!mounted) return;
    setState(() {
      _savedCredential = credential;
      _rememberPassword = credential != null;
    });
    _maybeOpenCredentialEditor(force: credential == null);
  }

  void _maybeOpenCredentialEditor({required bool force}) {
    if (!shouldOpenCredentialEditor ||
        _credentialEditorOpened ||
        !_isWebviewReady ||
        !mounted) {
      return;
    }
    _credentialEditorOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _resetLoginSession(autofillAfterReload: false);
      if (!mounted) return;
      await _openCredentialEditor(force: force);
    });
  }

  Future<void> _initWebview() async {
    try {
      await _webviewAdapter.start(
        targetUrl: ScheduleLoginFetchService.targetUrl,
        clearSessionOnStart: shouldOpenCredentialEditor,
        onMessage: _handleMessage,
        onUrlChanged: _onUrlChanged,
      );

      if (!mounted) return;
      setState(() {
        _isWebviewReady = true;
        if (readyStatusText != null) {
          _statusText = readyStatusText!;
        }
      });
      _maybeOpenCredentialEditor(force: _savedCredential == null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusText = LoginFlowText.browserInitFailed(e));
    }
  }

  void _onUrlChanged(String url) {
    if (_isFetching) return;

    if (!_suspendLoginAutomation && loginFetchService.shouldAutoFetch(url)) {
      _autofillController.stop(clearPending: true);
      unawaited(_autoFetch());
      return;
    }

    if (loginFetchService.isLoginUrl(url) && mounted) {
      setState(() {
        _statusText =
            (_savedCredential == null || !_rememberPassword)
                ? LoginFlowText.manualLoginPrompt
                : LoginFlowText.tryingSavedCredentialLogin;
      });
      if (!_suspendLoginAutomation || _autofillController.pendingAutofill) {
        _scheduleAutofillBurst();
      }
      return;
    }

    _autofillController.stop();
  }

  void _applyState(LoginFetchUiStateUpdate update) {
    if (!mounted) return;
    setState(() {
      if (update.isFetching != null) {
        _isFetching = update.isFetching!;
      }
      if (update.pendingAutofill != null) {
        _autofillController.setPending(update.pendingAutofill!);
      }
      if (update.statusText != null) {
        _statusText = update.statusText!;
      }
    });
  }

  void _scheduleAutofillBurst() {
    if (_savedCredential == null ||
        !_rememberPassword ||
        _autofillController.loopActive) {
      return;
    }
    _autofillController.start(_runAutofillAttempt);
  }

  void _handleAutofillStatus(String status) {
    final message = _loginFlowCoordinator.messageForAutofillStatus(status);
    if (message == null) return;
    _applyState(LoginFetchUiStateUpdate(statusText: message));
  }

  void _handleAutofillResult(LoginAutofillResult result) {
    final resolution = _loginFlowCoordinator.resolveAutofillResult(
      result,
      attemptCount: _autofillController.attemptCount,
    );
    _autofillController.handleResolution(resolution);
    if (!mounted) return;
    setState(() {
      _statusText = resolution.statusText;
    });
  }

  void _runAutofillAttempt() {
    if (!mounted || !_autofillController.loopActive) return;
    _autofillController.beginAttempt();
    unawaited(
      _autofillSavedCredential(
        autoSubmit: _autofillController.shouldAutoSubmit,
      ),
    );
    if (_autofillController.hasRemainingRetries) {
      _autofillController.scheduleNext(_runAutofillAttempt);
      return;
    }

    final showIncomplete = _autofillController.exhaustPending();
    if (showIncomplete && mounted) {
      setState(() {
        _statusText = LoginFlowText.autofillIncomplete;
      });
    }
  }

  Future<void> _autofillSavedCredential({required bool autoSubmit}) async {
    final credential = _savedCredential;
    if (!_rememberPassword || credential == null || !_isWebviewReady) {
      _autofillController.stop(clearPending: true);
      return;
    }
    try {
      await _webviewAdapter.executeScript(
        loginFetchService.buildFillCredentialScript(
          username: credential.username,
          password: credential.password,
          bridgeCall: bridgeCall,
          autoSubmit: autoSubmit,
        ),
      );
      if (mounted) {
        setState(() {
          _suspendLoginAutomation = false;
        });
      }
    } catch (_) {
      // Best-effort autofill only.
    }
  }

  Future<void> _resetLoginSession({bool autofillAfterReload = true}) async {
    if (!_isWebviewReady) return;
    _autofillController.stop();
    try {
      await _webviewAdapter.clearSession();
    } catch (_) {
      // Best-effort cleanup only.
    }

    if (!mounted) return;
    setState(() {
      _isFetching = false;
      _statusText = LoginFlowText.sessionCleared;
    });

    try {
      await _webviewAdapter.loadTargetUrl(ScheduleLoginFetchService.targetUrl);
      if (autofillAfterReload) {
        await Future.delayed(const Duration(milliseconds: 600));
        _scheduleAutofillBurst();
      }
    } catch (_) {
      // Ignore reload failures here; the user can still retry manually.
    }
  }

  Future<void> _clearSavedCredential({bool showToast = true}) async {
    await AuthCredentialsService.instance.clear();
    if (!mounted) return;
    setState(() {
      _savedCredential = null;
      _rememberPassword = false;
      _suspendLoginAutomation = false;
      _statusText = LoginFlowText.savedCredentialCleared;
    });
    _autofillController.stop(clearPending: true);
    await _resetLoginSession(autofillAfterReload: false);
    if (!mounted || !showToast) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(LoginFlowText.savedCredentialClearedToast)),
    );
  }

  Future<void> _openCredentialEditor({bool force = false}) async {
    final previousUsername = _savedCredential?.username.trim();
    final result = await showLoginCredentialEditorDialog(
      context: context,
      savedCredential: _savedCredential,
      rememberPassword: _rememberPassword,
      force: force,
    );

    if (result == null || !mounted) return;
    if (!result.rememberPassword) {
      await _clearSavedCredential(showToast: !force);
      return;
    }

    final username = result.username.trim();
    final password = result.password;
    await AuthCredentialsService.instance.save(
      username: username,
      password: password,
    );
    if (!mounted) return;
    setState(() {
      _savedCredential = SavedPortalCredential(
        username: username,
        password: password,
      );
      _rememberPassword = true;
      _autofillController.setPending(true);
      _suspendLoginAutomation = false;
      _statusText =
          previousUsername == username
              ? LoginFlowText.savedCredentialUpdated
              : LoginFlowText.switchingSavedCredentialSession;
    });
    if (previousUsername != null && previousUsername == username) {
      _scheduleAutofillBurst();
    } else {
      await _resetLoginSession();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          LoginFlowText.savedCredentialStored(_savedCredential!.maskedUsername),
        ),
      ),
    );
  }

  Future<void> _autoFetch() async {
    if (_isFetching) return;
    await _loginFlowCoordinator.startAutoFetch(
      selectedSemesterCode: _selectedSemesterCode,
      chunkState: _chunkState,
      warmupDelay: autoFetchWarmupDelay,
      bridgeCall: bridgeCall,
      executeScript: _webviewAdapter.executeScript,
      isStillFetching: () => mounted && _isFetching,
      applyState: _applyState,
    );
  }

  Future<void> _fetchWithSemester(String semester) async {
    await _loginFlowCoordinator.fetchWithSemester(
      semester: semester,
      bridgeCall: bridgeCall,
      executeScript: _webviewAdapter.executeScript,
      onSemesterResolved: (value) => _lastDetectedSemester = value,
      applyState: _applyState,
      persistSemesterCode: persistSemesterCode,
    );
  }

  Future<void> _pickTargetSemester() async {
    final provider = context.read<ScheduleProvider>();
    final codes = {...provider.availableSemesterCodes};
    if (provider.currentSemesterCode != null &&
        provider.currentSemesterCode!.isNotEmpty) {
      codes.add(provider.currentSemesterCode!);
    }
    final sortedCodes = codes.toList()..sort((a, b) => b.compareTo(a));

    final selection = await showLoginSemesterPicker(
      context: context,
      selectedSemesterCode: _selectedSemesterCode,
      sortedCodes: sortedCodes,
      formatSemesterCode: _loginFlowCoordinator.formatSemesterCode,
      looksLikeSemesterCode: _loginFlowCoordinator.looksLikeSemesterCode,
    );
    if (selection == null || !mounted) return;
    setState(() => _selectedSemesterCode = selection.semesterCode);
  }

  void _handleMessage(String message) {
    _loginFlowCoordinator.handleBridgeMessage(
      message: message,
      chunkState: _chunkState,
      applyState: _applyState,
      onSemesterReady: _fetchWithSemester,
      onPayloadReady: _processData,
      onAutofillStatus: _handleAutofillStatus,
      onAutofillResult: _handleAutofillResult,
      emptySemesterMessage: LoginFlowText.emptyDetectedSemester,
    );
  }

  Future<void> _processData(String jsonStr) async {
    await _loginFlowCoordinator.processFetchedData(
      context: context,
      jsonStr: jsonStr,
      semester: _lastDetectedSemester,
      applyState: _applyState,
    );
  }

  Widget buildLoginFlowPage({
    Color? activeBackgroundColor,
    Color? idleBackgroundColor,
    TextStyle? statusTextStyle,
  }) {
    return LoginFlowScaffold(
      isFetching: _isFetching,
      canManualFetch: _isWebviewReady,
      rememberPassword: _rememberPassword,
      savedCredential: _savedCredential,
      selectedSemesterCode: _selectedSemesterCode,
      statusText: _statusText,
      onOpenCredentialEditor: _openCredentialEditor,
      onClearSavedCredential: _clearSavedCredential,
      onPickTargetSemester: _pickTargetSemester,
      onAutoFetch: _autoFetch,
      onRememberPasswordChanged: (value) async {
        if (value) {
          await _openCredentialEditor(force: _savedCredential == null);
          return;
        }
        await _clearSavedCredential(showToast: false);
      },
      activeBackgroundColor: activeBackgroundColor,
      idleBackgroundColor: idleBackgroundColor,
      statusTextStyle: statusTextStyle,
      content:
          _isWebviewReady
              ? _webviewAdapter.buildView()
              : const Center(child: CircularProgressIndicator()),
    );
  }
}
