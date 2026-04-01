import 'package:flutter/material.dart';
import 'dart:async';

import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/auth_credentials_service.dart';
import '../services/schedule_login_fetch_service.dart';
import '../services/schedule_provider.dart';

class LoginScreenAndroid extends StatefulWidget {
  const LoginScreenAndroid({
    super.key,
    this.initialSemesterCode,
    this.openCredentialEditor = false,
  });

  final String? initialSemesterCode;
  final bool openCredentialEditor;

  @override
  State<LoginScreenAndroid> createState() => _LoginScreenAndroidState();
}

class _LoginScreenAndroidState extends State<LoginScreenAndroid> {
  static const int _maxAutofillAttempts = 7;

  final ScheduleLoginFetchService _loginFetchService = ScheduleLoginFetchService();
  final LoginFetchChunkState _chunkState = LoginFetchChunkState();
  final WebViewCookieManager _cookieManager = WebViewCookieManager();

  late final WebViewController _controller;
  bool _isFetching = false;
  bool _rememberPassword = false;
  bool _suspendLoginAutomation = false;
  bool _pendingAutofill = false;
  bool _autofillLoopActive = false;
  bool _credentialEditorOpened = false;
  Timer? _autofillTimer;
  int _autofillAttempts = 0;
  String _statusText = '正在加载登录页面...';
  String? _lastDetectedSemester;
  String? _selectedSemesterCode;
  SavedPortalCredential? _savedCredential;

  @override
  void initState() {
    super.initState();
    _selectedSemesterCode = widget.initialSemesterCode;
    _suspendLoginAutomation = widget.openCredentialEditor;
    _loadSavedCredential();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: _onUrlChanged,
        ),
      )
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (message) {
          _handleMessage(message.message);
        },
      );

    _startInitialLoad();
  }

  Future<void> _startInitialLoad() async {
    if (widget.openCredentialEditor) {
      try {
        await _cookieManager.clearCookies();
        await _controller.clearCache();
        await _controller.clearLocalStorage();
      } catch (_) {
        // Best-effort cleanup only.
      }
    }
    await _controller.loadRequest(Uri.parse(ScheduleLoginFetchService.targetUrl));
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
    if (!widget.openCredentialEditor ||
        _credentialEditorOpened ||
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

  void _onUrlChanged(String url) {
    if (_isFetching) return;

    if (!_suspendLoginAutomation && _loginFetchService.shouldAutoFetch(url)) {
      _autofillLoopActive = false;
      _pendingAutofill = false;
      _autoFetch();
      return;
    }

    if (_loginFetchService.isLoginUrl(url) && mounted) {
      setState(() {
        _statusText = (_savedCredential == null || !_rememberPassword)
            ? '请输入账号密码登录'
            : '检测到已保存账号，正在尝试自动填充并登录...';
      });
      if (!_suspendLoginAutomation || _pendingAutofill) {
        _scheduleAutofillBurst();
      }
    } else {
      _autofillLoopActive = false;
    }
  }

  void _scheduleAutofillBurst() {
    if (_savedCredential == null || !_rememberPassword || _autofillLoopActive) {
      return;
    }
    _autofillTimer?.cancel();
    _autofillAttempts = 0;
    _pendingAutofill = true;
    _autofillLoopActive = true;
    _runAutofillAttempt();
  }

  void _handleAutofillStatus(String status) {
    if (!mounted) return;
    switch (status) {
      case 'QR_VIEW':
        setState(() => _statusText = '检测到二维码登录页，正在寻找账号密码登录入口...');
        break;
      case 'SWITCHING_TO_PASSWORD_LOGIN':
      case 'SWITCHED_PASSWORD_LOGIN':
        setState(() => _statusText = '已识别二维码登录，正在切换到账号密码登录...');
        break;
      case 'WAITING_PASSWORD_FORM':
        setState(() => _statusText = '已点击切换按钮，正在等待账号密码表单出现...');
        break;
      case 'WAITING_FORM':
        setState(() => _statusText = '登录表单还在加载，继续尝试识别...');
        break;
      case 'FORM_READY':
        setState(() => _statusText = '已识别到账密表单，正在自动填充...');
        break;
      case 'PARTIAL_CREDENTIALS':
        setState(() => _statusText = '已识别到部分登录表单，正在补全并继续尝试...');
        break;
      case 'TRUST_CHECKED':
        setState(() => _statusText = '已勾选记住/信任选项，准备提交登录...');
        break;
      case 'WAITING_TRUST_OPTION':
        setState(() => _statusText = '已识别到“7天记住/信任选项”，正在等待勾选生效...');
        break;
      case 'CREDENTIALS_FILLED':
        setState(() => _statusText = '已自动填充账号密码，准备自动登录...');
        break;
      case 'SUBMITTING':
        setState(() => _statusText = '登录请求已发出，正在等待页面响应...');
        break;
      case 'SUBMITTED':
        setState(() => _statusText = '已自动提交登录，请稍候...');
        break;
      case 'VERIFICATION_REQUIRED':
        setState(() => _statusText = '检测到多因子或设备验证码验证，需要你手动完成后再继续...');
        break;
      default:
        break;
    }
  }

  void _handleAutofillResult(LoginAutofillResult result) {
    if (!mounted) return;
    setState(() {
      if (result.verificationRequired) {
        _autofillLoopActive = false;
        _pendingAutofill = false;
        _statusText = '检测到多因子或设备验证码校验，需要你手动完成验证';
        return;
      }
      if (result.submitted) {
        _autofillLoopActive = false;
        _pendingAutofill = false;
        _statusText = '已自动提交登录，请稍候...';
        return;
      }
      if (result.usernameFilled && result.passwordFilled) {
        _statusText =
            _autofillAttempts >= 3
                ? '已自动填充账号密码，正在尝试自动登录...'
                : '已自动填充账号密码，正在确认页面状态...';
        return;
      }
      if (result.usernameFilled || result.passwordFilled) {
        _statusText = '已识别到部分登录表单，正在补全并尝试登录...';
        return;
      }
      _statusText = '暂未命中账号密码输入框，正在继续尝试...';
    });
  }

  void _runAutofillAttempt() {
    if (!mounted || !_autofillLoopActive) return;
    _autofillAttempts++;
    _autofillSavedCredential(autoSubmit: _autofillAttempts >= 3);
    if (_pendingAutofill && _autofillAttempts < _maxAutofillAttempts) {
      _autofillTimer = Timer(
        Duration(
          milliseconds:
              _autofillAttempts == 1
                  ? 1100
                  : _autofillAttempts < 4
                  ? 1500
                  : 1800,
        ),
        _runAutofillAttempt,
      );
    } else {
      _autofillLoopActive = false;
      if (_pendingAutofill && mounted) {
        setState(() {
          _pendingAutofill = false;
          _statusText = '自动登录未完全完成，如页面已切到账密登录可手动点登录';
        });
      }
    }
  }

  Future<void> _autofillSavedCredential({required bool autoSubmit}) async {
    final credential = _savedCredential;
    if (!_rememberPassword ||
        credential == null) {
      _autofillLoopActive = false;
      _pendingAutofill = false;
      return;
    }
    try {
      await _controller.runJavaScript(
        _loginFetchService.buildFillCredentialScript(
          username: credential.username,
          password: credential.password,
          bridgeCall: 'FlutterBridge.postMessage',
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
    try {
      await _cookieManager.clearCookies();
      await _controller.clearCache();
      await _controller.clearLocalStorage();
    } catch (_) {
      // Best-effort cleanup only.
    }

    if (!mounted) return;
    setState(() {
      _isFetching = false;
      _statusText = '已清除旧登录态，请重新登录';
    });

    try {
      await _controller.loadRequest(Uri.parse(ScheduleLoginFetchService.targetUrl));
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
      _pendingAutofill = false;
      _suspendLoginAutomation = false;
      _statusText = '请输入账号密码登录';
    });
    await _resetLoginSession(autofillAfterReload: false);
    if (!mounted) return;
    if (showToast) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已清除保存的账号密码')),
      );
    }
  }

  Future<void> _openCredentialEditor({bool force = false}) async {
    final previousUsername = _savedCredential?.username.trim();
    final usernameController =
        TextEditingController(text: _savedCredential?.username ?? '');
    final passwordController =
        TextEditingController(text: _savedCredential?.password ?? '');
    bool remember = _rememberPassword || force;
    bool obscure = true;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: !force,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(force ? '保存登录账号' : '账号与密码'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: '账号',
                      errorText: errorText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: '密码',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(
                          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: remember,
                    title: const Text('记住密码'),
                    subtitle: const Text('用于自动填充登录页和后续切换账号'),
                    onChanged: (value) => setState(() => remember = value),
                  ),
                ],
              ),
              actions: [
                if (!force)
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('取消'),
                  ),
                FilledButton(
                  onPressed: () {
                    final username = usernameController.text.trim();
                    final password = passwordController.text;
                    if (remember && (username.isEmpty || password.isEmpty)) {
                      setState(() => errorText = '请输入完整账号和密码');
                      return;
                    }
                    Navigator.of(dialogContext).pop(remember);
                  },
                  child: Text(remember ? '保存并填充' : '仅关闭记住密码'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == null || !mounted) return;
    if (!saved) {
      await _clearSavedCredential(showToast: !force);
      return;
    }

    final username = usernameController.text.trim();
    final password = passwordController.text;
    await AuthCredentialsService.instance.save(
      username: username,
      password: password,
    );
    if (!mounted) return;
    setState(() {
      _savedCredential = SavedPortalCredential(username: username, password: password);
      _rememberPassword = true;
      _pendingAutofill = true;
      _suspendLoginAutomation = false;
      _statusText = previousUsername == username
          ? '已更新保存的账号密码'
          : '已保存账号，正在切换到新的登录会话';
    });
    if (previousUsername != null && previousUsername == username) {
      _scheduleAutofillBurst();
    } else {
      await _resetLoginSession();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已保存账号 ${_savedCredential!.maskedUsername}')),
    );
  }

  Future<void> _autoFetch() async {
    if (_isFetching) return;

    setState(() {
      _isFetching = true;
      _pendingAutofill = false;
      _statusText = _selectedSemesterCode == null
          ? '登录成功，正在检测学期信息...'
          : '登录成功，准备抓取 ${_selectedSemesterCode!} ...';
    });

    _chunkState.reset();
    await Future.delayed(const Duration(seconds: 2));

    try {
      if (_selectedSemesterCode != null) {
        setState(() => _statusText = '正在切换到目标学期 ${_selectedSemesterCode!} ...');
        await _controller.runJavaScript(
          _loginFetchService.buildSwitchSemesterScript(
            bridgeCall: 'FlutterBridge.postMessage',
            semester: _selectedSemesterCode!,
          ),
        );
        return;
      }

      await _controller.runJavaScript(
        _loginFetchService.buildDetectSemesterScript(
          'FlutterBridge.postMessage',
        ),
      );

      Future.delayed(const Duration(seconds: 25), () {
        if (_isFetching && mounted) {
          setState(() {
            _statusText = '请求超时，请点击右上角重试';
            _isFetching = false;
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = '执行失败: $e';
        _isFetching = false;
      });
    }
  }

  Future<void> _fetchWithSemester(String semester) async {
    _lastDetectedSemester = semester;
    setState(() => _statusText = '学期: $semester，正在拉取课表...');

    try {
      await _controller.runJavaScript(
        _loginFetchService.buildFetchScheduleScript(
          bridgeCall: 'FlutterBridge.postMessage',
          semester: semester,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = '请求失败: $e';
        _isFetching = false;
      });
    }
  }

  Future<void> _pickTargetSemester() async {
    final provider = context.read<ScheduleProvider>();
    final codes = {...provider.availableSemesterCodes};
    if (provider.currentSemesterCode != null &&
        provider.currentSemesterCode!.isNotEmpty) {
      codes.add(provider.currentSemesterCode!);
    }
    final sortedCodes = codes.toList()..sort((a, b) => b.compareTo(a));

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  '目标学期',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('不选择时，将自动检测教务页面当前学期'),
              ),
              RadioGroup<String?>(
                groupValue: _selectedSemesterCode,
                onChanged: (value) {
                  Navigator.of(sheetContext).pop();
                  if (!mounted) return;
                  setState(() => _selectedSemesterCode = value);
                },
                child: Column(
                  children: [
                    const RadioListTile<String?>(
                      value: null,
                      title: Text('自动检测当前学期'),
                    ),
                    ...sortedCodes.map(
                      (code) => RadioListTile<String?>(
                        value: code,
                        title: Text(_formatSemesterCode(code)),
                        subtitle: Text(code),
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('手动输入学期代码'),
                subtitle: const Text('例如：20251 或 20252'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _showCustomSemesterDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCustomSemesterDialog() async {
    final controller = TextEditingController(text: _selectedSemesterCode ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('手动输入学期代码'),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '学期代码',
                  hintText: '例如：20251',
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (!_looksLikeSemesterCode(text)) {
                      setState(() => errorText = '请输入 5 位学期代码，例如 20251');
                      return;
                    }
                    Navigator.of(dialogContext).pop(text);
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );

    if (value == null || !mounted) return;
    setState(() => _selectedSemesterCode = value);
  }

  bool _looksLikeSemesterCode(String value) {
    return RegExp(r'^\d{4}[12]$').hasMatch(value);
  }

  String _formatSemesterCode(String code) {
    if (!_looksLikeSemesterCode(code)) return code;
    final startYear = int.parse(code.substring(0, 4));
    final endYear = startYear + 1;
    final term = code.endsWith('1') ? '第一学期' : '第二学期';
    return '$startYear-$endYear $term';
  }

  void _handleMessage(String message) {
    _loginFetchService.handleBridgeMessage(
      message: message,
      chunkState: _chunkState,
      onStatus: (status) {
        if (!mounted) return;
        setState(() => _statusText = status);
      },
      onSemesterDetected: (semester) {
        if (semester.isEmpty) {
          if (!mounted) return;
          setState(() {
            _statusText = '未检测到学期信息';
            _isFetching = false;
          });
          return;
        }
        _fetchWithSemester(semester);
      },
      onSemesterSwitched: (semester) {
        _fetchWithSemester(semester);
      },
      onPayloadReady: _processData,
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _statusText = '请求失败: $error';
          _isFetching = false;
        });
      },
      onAutofillStatus: _handleAutofillStatus,
      onAutofillResult: _handleAutofillResult,
    );
  }

  Future<void> _processData(String jsonStr) async {
    try {
      final result = await _loginFetchService.processScheduleJson(
        context: context,
        jsonStr: jsonStr,
        semester: _lastDetectedSemester,
        captureCookieSnapshot: true,
      );

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.cookieSnapshotCaptured
                ? '成功拉取 ${result.courses.length} 门课程，自动同步状态已恢复'
                : '成功拉取 ${result.courses.length} 门课程',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _statusText = '拉取完成';
        _isFetching = false;
      });

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          navigator.pop();
        }
      });
    } on LoginFetchException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = e.message;
        _isFetching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusText = '解析失败: $e';
        _isFetching = false;
      });
    }
  }

  @override
  void dispose() {
    _autofillTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录教务系统'),
        actions: [
          if (!_isFetching)
            IconButton(
              tooltip: '账号与密码',
              onPressed: _openCredentialEditor,
              icon: const Icon(Icons.manage_accounts_outlined),
            ),
          if (!_isFetching && _savedCredential != null)
            IconButton(
              tooltip: '清除已保存账号',
              onPressed: _clearSavedCredential,
              icon: const Icon(Icons.logout_rounded),
            ),
          if (!_isFetching)
            TextButton.icon(
              onPressed: _pickTargetSemester,
              icon: const Icon(Icons.school_outlined, size: 18),
              label: Text(
                _selectedSemesterCode == null ? '自动学期' : _selectedSemesterCode!,
              ),
            ),
          if (!_isFetching)
            TextButton.icon(
              onPressed: _autoFetch,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('手动抓取'),
            ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            child: ListTile(
              dense: true,
              leading: Checkbox(
                value: _rememberPassword,
                onChanged: _isFetching
                    ? null
                    : (value) async {
                        if (value == true) {
                          await _openCredentialEditor(force: _savedCredential == null);
                          return;
                        }
                        await _clearSavedCredential(showToast: false);
                      },
              ),
              title: const Text('记住密码'),
              subtitle: Text(
                _savedCredential == null
                    ? '保存后可自动填充登录页，也更方便切换账号'
                    : '当前账号：${_savedCredential!.maskedUsername}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.66),
                ),
              ),
              trailing: TextButton(
                onPressed: _isFetching ? null : _openCredentialEditor,
                child: Text(_savedCredential == null ? '填写账号' : '切换账号'),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _isFetching
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            child: Row(
              children: [
                if (_isFetching)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Expanded(
                  child: Text(
                    _selectedSemesterCode == null
                        ? _statusText
                        : '目标学期 ${_selectedSemesterCode!} · $_statusText',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}
