import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';

typedef LoginWebviewMessageHandler = void Function(String message);
typedef LoginWebviewUrlHandler = void Function(String url);

abstract class LoginWebviewAdapter {
  bool get isReady;

  Future<void> start({
    required String targetUrl,
    required bool clearSessionOnStart,
    required LoginWebviewMessageHandler onMessage,
    required LoginWebviewUrlHandler onUrlChanged,
  });

  Future<void> executeScript(String script);

  Future<void> clearSession();

  Future<void> loadTargetUrl(String targetUrl);

  Future<void> stopLoading();

  Future<String?> currentUrl();

  Widget buildView();

  void dispose();
}

class WindowsLoginWebviewAdapter implements LoginWebviewAdapter {
  final WebviewController _controller = WebviewController();
  final List<StreamSubscription> _subscriptions = [];

  String? _latestUrl;
  bool _isReady = false;

  @override
  bool get isReady => _isReady;

  @override
  Future<void> start({
    required String targetUrl,
    required bool clearSessionOnStart,
    required LoginWebviewMessageHandler onMessage,
    required LoginWebviewUrlHandler onUrlChanged,
  }) async {
    await _controller.initialize();

    _subscriptions.add(
      _controller.webMessage.listen((message) {
        onMessage(message.toString());
      }),
    );

    _subscriptions.add(
      _controller.url.listen((url) {
        _latestUrl = url;
        onUrlChanged(url);
      }),
    );

    _subscriptions.add(
      _controller.loadingState.listen((state) {
        if (state == LoadingState.navigationCompleted && _latestUrl != null) {
          onUrlChanged(_latestUrl!);
        }
      }),
    );

    if (clearSessionOnStart) {
      try {
        await clearSession();
      } catch (_) {
        // Best-effort cleanup only.
      }
    }

    await loadTargetUrl(targetUrl);
    _isReady = true;
  }

  @override
  Future<void> executeScript(String script) {
    return _controller.executeScript(script);
  }

  @override
  Future<void> clearSession() async {
    await _controller.clearCookies();
    await _controller.clearCache();
  }

  @override
  Future<void> loadTargetUrl(String targetUrl) {
    return _controller.loadUrl(targetUrl);
  }

  @override
  Future<void> stopLoading() {
    return _controller.executeScript('try { window.stop(); } catch (_) {}');
  }

  @override
  Future<String?> currentUrl() async {
    try {
      final value = await _controller.executeScript('window.location.href');
      if (value is String && value.isNotEmpty) {
        _latestUrl = value;
        return value;
      }
    } catch (_) {
      // Fall back to the latest navigation event.
    }
    return _latestUrl;
  }

  @override
  Widget buildView() {
    return Webview(_controller);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _controller.dispose();
  }
}

class AndroidLoginWebviewAdapter implements LoginWebviewAdapter {
  AndroidLoginWebviewAdapter()
    : _controller =
          WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted);

  final WebViewController _controller;
  final WebViewCookieManager _cookieManager = WebViewCookieManager();

  bool _isReady = false;

  @override
  bool get isReady => _isReady;

  @override
  Future<void> start({
    required String targetUrl,
    required bool clearSessionOnStart,
    required LoginWebviewMessageHandler onMessage,
    required LoginWebviewUrlHandler onUrlChanged,
  }) async {
    await _controller.setNavigationDelegate(
      NavigationDelegate(onPageFinished: onUrlChanged),
    );
    await _controller.addJavaScriptChannel(
      'FlutterBridge',
      onMessageReceived: (message) {
        onMessage(message.message);
      },
    );

    if (clearSessionOnStart) {
      try {
        await clearSession();
      } catch (_) {
        // Best-effort cleanup only.
      }
    }

    await loadTargetUrl(targetUrl);
    _isReady = true;
  }

  @override
  Future<void> executeScript(String script) {
    return _controller.runJavaScript(script);
  }

  @override
  Future<void> clearSession() async {
    await _cookieManager.clearCookies();
    await _controller.clearCache();
    await _controller.clearLocalStorage();
  }

  @override
  Future<void> loadTargetUrl(String targetUrl) {
    return _controller.loadRequest(Uri.parse(targetUrl));
  }

  @override
  Future<void> stopLoading() {
    return _controller.runJavaScript('try { window.stop(); } catch (_) {}');
  }

  @override
  Future<String?> currentUrl() {
    return _controller.currentUrl();
  }

  @override
  Widget buildView() {
    return WebViewWidget(controller: _controller);
  }

  @override
  void dispose() {}
}
