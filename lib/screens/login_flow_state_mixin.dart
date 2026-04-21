import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hai_schedule/models/semester_option.dart';
import 'package:hai_schedule/services/auth_credentials_service.dart';
import 'package:hai_schedule/services/auto_sync_service.dart';
import 'package:hai_schedule/services/login_fetch_coordinator.dart';
import 'package:hai_schedule/services/schedule_login_fetch_service.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/utils/login_flow_autofill_controller.dart';
import 'package:hai_schedule/utils/login_flow_text.dart';
import 'package:hai_schedule/widgets/login_flow_sections.dart';
import 'package:hai_schedule/widgets/login_webview_adapters.dart';

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
  bool _isInteractingWithDialog = false;
  bool _rememberPassword = false;
  bool _suspendLoginAutomation = false;
  bool _credentialEditorOpened = false;
  String _statusText = '';
  String? _currentUrl;
  String? _lastDetectedSemester;
  String? _selectedSemesterCode;
  SavedPortalCredential? _savedCredential;
  SavedPortalCredential? _activeCredential;
  List<SemesterOption> _semesterOptions = const [];

  LoginWebviewAdapter createWebviewAdapter();

  String get bridgeCall;

  Duration get autoFetchWarmupDelay;

  String get initialStatusText;

  String? get readyStatusText => null;

  String? get initialSemesterCode;

  bool get shouldOpenCredentialEditor;

  void initLoginFlow() {
    _statusText = initialStatusText;
    _selectedSemesterCode = initialSemesterCode;
    _suspendLoginAutomation = shouldOpenCredentialEditor;
    _semesterOptions =
        context.read<ScheduleProvider>().availableSemesterOptions;
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
      _activeCredential = credential;
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
    _currentUrl = url;
    if (_isFetching) return;

    if (!_isInteractingWithDialog &&
        !_suspendLoginAutomation &&
        loginFetchService.shouldAutoFetch(url)) {
      _autofillController.stop(clearPending: true);
      unawaited(_autoFetch());
      return;
    }

    if (loginFetchService.isLoginUrl(url) && mounted) {
      setState(() {
        _statusText =
            _activeCredential == null
                ? LoginFlowText.manualLoginPrompt
                : LoginFlowText.tryingSavedCredentialLogin;
      });
      if (!_isInteractingWithDialog &&
          _activeCredential != null &&
          (!_suspendLoginAutomation || _autofillController.pendingAutofill)) {
        _scheduleAutofillBurst();
      }
      return;
    }

    if (_isInteractingWithDialog) return;
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
    if (_isInteractingWithDialog ||
        _activeCredential == null ||
        _autofillController.loopActive) {
      return;
    }
    _autofillController.start(_runAutofillAttempt);
  }

  Future<R?> _runWhileDialogOpen<R>(
    Future<R?> Function() action, {
    bool resumeAutofillOnClose = true,
  }) async {
    if (mounted) {
      setState(() => _isInteractingWithDialog = true);
    }
    _autofillController.stop();
    try {
      return await action();
    } finally {
      if (mounted) {
        setState(() => _isInteractingWithDialog = false);
        if (resumeAutofillOnClose) {
          _resumeAutofillIfPossible();
        }
      }
    }
  }

  void _resumeAutofillIfPossible() {
    final currentUrl = _currentUrl;
    if (_isInteractingWithDialog ||
        _isFetching ||
        _activeCredential == null ||
        !_isWebviewReady ||
        !_autofillController.pendingAutofill ||
        currentUrl == null ||
        !loginFetchService.isLoginUrl(currentUrl)) {
      return;
    }
    _scheduleAutofillBurst();
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
    if (_isInteractingWithDialog) {
      _autofillController.stop();
      return;
    }
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
    final credential = _activeCredential;
    if (_isInteractingWithDialog) {
      return;
    }
    if (credential == null || !_isWebviewReady) {
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
          enableTrustOption: _rememberPassword,
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

  Future<void> _handleLoginError(String errorText) async {
    _autofillController.stop(clearPending: true);
    try {
      await _webviewAdapter.stopLoading();
    } catch (_) {
      // Best-effort stop only.
    }
    await AutoSyncService.handleCredentialCleared();
    if (!mounted) return;
    setState(() {
      _savedCredential = null;
      _activeCredential = null;
      _rememberPassword = false;
      _isFetching = false;
      _suspendLoginAutomation = true;
      _statusText = errorText.isNotEmpty ? errorText : '检测到登录报错，已停止自动尝试，请核对账密';
    });
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('检测到登录报错，已停止自动尝试，请核对账密')));
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
    await AutoSyncService.handleCredentialCleared();
    if (!mounted) return;
    setState(() {
      _savedCredential = null;
      _activeCredential = null;
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
    final result = await _runWhileDialogOpen(
      () => showLoginCredentialEditorDialog(
        context: context,
        currentCredential: _activeCredential ?? _savedCredential,
        rememberPassword: _rememberPassword,
        force: force,
      ),
      resumeAutofillOnClose: false,
    );

    if (result == null || !mounted) {
      _resumeAutofillIfPossible();
      return;
    }
    final username = result.username.trim();
    final password = result.password;
    final credential = SavedPortalCredential(
      username: username,
      password: password,
    );
    if (result.rememberPassword) {
      await AuthCredentialsService.instance.save(
        username: username,
        password: password,
      );
    } else {
      await AuthCredentialsService.instance.clear();
      await AutoSyncService.handleCredentialCleared();
    }
    if (!mounted) return;
    setState(() {
      _savedCredential = result.rememberPassword ? credential : null;
      _activeCredential = credential;
      _rememberPassword = result.rememberPassword;
      _autofillController.setPending(true);
      _suspendLoginAutomation = false;
      _statusText =
          result.rememberPassword
              ? LoginFlowText.switchingSavedCredentialSession
              : LoginFlowText.temporaryCredentialLogin;
    });
    await _resetLoginSession(autofillAfterReload: false);
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _autofillSavedCredential(autoSubmit: true);
    _scheduleAutofillBurst();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.rememberPassword
              ? LoginFlowText.savedCredentialStored(credential.maskedUsername)
              : LoginFlowText.temporaryCredentialUsed(
                credential.maskedUsername,
              ),
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
    final targetSemester = _selectedSemesterCode ?? semester;
    await _loginFlowCoordinator.fetchWithSemester(
      semester: targetSemester,
      chunkState: _chunkState,
      bridgeCall: bridgeCall,
      executeScript: _webviewAdapter.executeScript,
      onSemesterResolved: (value) => _lastDetectedSemester = value,
      applyState: _applyState,
    );
  }

  Future<void> _pickTargetSemester() async {
    final selection = await _runWhileDialogOpen(
      () => showLoginSemesterPicker(
        context: context,
        selectedSemesterCode: _selectedSemesterCode,
        optionLabels:
            _semesterOptions
                .map(
                  (option) =>
                      option.normalizedName.isNotEmpty
                          ? option.normalizedName
                          : _loginFlowCoordinator.formatSemesterCode(
                            option.code,
                          ),
                )
                .toList(),
        optionCodes: _semesterOptions.map((option) => option.code).toList(),
      ),
    );
    if (selection == null || !mounted) return;
    setState(() => _selectedSemesterCode = selection.semesterCode);
  }

  void _cacheSemesterOptions(List<SemesterOption> options) {
    if (!mounted || options.isEmpty) return;
    setState(() {
      _semesterOptions = options;
      _selectedSemesterCode ??= options.first.code;
    });
  }

  Future<void> _handleSemesterOptions(List<SemesterOption> options) async {
    if (options.isEmpty) return;
    _cacheSemesterOptions(options);
    final provider = context.read<ScheduleProvider>();
    await provider.mergeKnownSemesterOptions(options);
    if (!mounted) return;
    setState(() {
      _semesterOptions = provider.availableSemesterOptions;
    });
  }

  void _handleMessage(String message) {
    _loginFlowCoordinator.handleBridgeMessage(
      message: message,
      chunkState: _chunkState,
      applyState: _applyState,
      onSemesterReady: _fetchWithSemester,
      onSemesterOptions: (options) {
        unawaited(_handleSemesterOptions(options));
      },
      onPayloadReady: _processData,
      onLoginError: (error) {
        unawaited(_handleLoginError(error));
      },
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
      persistLoginSession: _rememberPassword,
      applyState: _applyState,
    );
  }

  Widget buildLoginFlowPage({
    Color? activeBackgroundColor,
    Color? idleBackgroundColor,
    TextStyle? statusTextStyle,
  }) {
    final selectedSemesterLabel =
        _selectedSemesterCode == null
            ? null
            : _semesterOptions
                .where((option) => option.code == _selectedSemesterCode)
                .map((option) => option.normalizedName)
                .where((name) => name.isNotEmpty)
                .cast<String?>()
                .firstWhere(
                  (value) => value != null && value.isNotEmpty,
                  orElse:
                      () => _loginFlowCoordinator.formatSemesterCode(
                        _selectedSemesterCode!,
                      ),
                );
    return LoginFlowScaffold(
      isFetching: _isFetching,
      canManualFetch: _isWebviewReady,
      rememberPassword: _rememberPassword,
      activeCredential: _activeCredential,
      hasSavedCredential: _savedCredential != null,
      selectedSemesterCode: _selectedSemesterCode,
      selectedSemesterLabel: selectedSemesterLabel,
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
