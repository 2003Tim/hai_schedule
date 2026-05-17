import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// 统一的运行时平台能力抽象。
///
/// 所有跨平台分支判断都应通过这里访问，避免在 widget / service / screen
/// 各处直接散落 [Platform.isAndroid] / [Platform.isWindows] 等判断。
///
/// 在测试中可以通过 [AppPlatform.debugOverride] 临时替换实现，从而避免
/// 每个 service 都暴露自己的 `debugForceAndroid` 字段。
class AppPlatform {
  const AppPlatform();

  static AppPlatform _instance = const AppPlatform();

  /// 获取当前生效的平台能力实例。
  static AppPlatform get instance => _instance;

  @visibleForTesting
  static set debugOverride(AppPlatform? override) {
    _instance = override ?? const AppPlatform();
  }

  bool get isAndroid => Platform.isAndroid;
  bool get isIOS => Platform.isIOS;
  bool get isWindows => Platform.isWindows;
  bool get isMacOS => Platform.isMacOS;
  bool get isLinux => Platform.isLinux;
  bool get isFuchsia => Platform.isFuchsia;

  /// 是否运行在桌面平台。
  bool get isDesktop => isWindows || isMacOS || isLinux;

  /// 是否运行在移动平台。
  bool get isMobile => isAndroid || isIOS;

  /// 是否支持后台定时自动同步（Android + Windows）。
  bool get supportsTimedAutoSync => isAndroid || isWindows;

  /// 是否支持桌面前台自动同步（仅 Windows）。
  bool get supportsForegroundDesktopAutoSync => isWindows;

  /// 是否支持本地通知（课前提醒）。
  bool get supportsLocalNotifications => isAndroid;

  /// 是否支持自动静音（依赖 Android 勿扰权限）。
  bool get supportsClassSilence => isAndroid;

  /// 是否支持桌面小组件（HomeWidget 仅 Android）。
  bool get supportsHomeWidget => isAndroid;
}

/// 测试期间临时强制平台为 Android 的便捷类。
@visibleForTesting
class FakeAppPlatform extends AppPlatform {
  const FakeAppPlatform({
    this.android = false,
    this.windows = false,
    this.iOS = false,
    this.macOS = false,
    this.linux = false,
  });

  final bool android;
  final bool windows;
  final bool iOS;
  final bool macOS;
  final bool linux;

  @override
  bool get isAndroid => android;

  @override
  bool get isIOS => iOS;

  @override
  bool get isWindows => windows;

  @override
  bool get isMacOS => macOS;

  @override
  bool get isLinux => linux;
}
