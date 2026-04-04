import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:hai_schedule/utils/app_titles.dart';
import 'package:hai_schedule/services/class_reminder_service.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/services/theme_provider.dart';

class AppBootstrapResult {
  final ScheduleProvider scheduleProvider;
  final ThemeProvider themeProvider;

  const AppBootstrapResult({
    required this.scheduleProvider,
    required this.themeProvider,
  });
}

class AppBootstrap {
  const AppBootstrap._();

  static Future<AppBootstrapResult> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    if (Platform.isAndroid) {
      await _initializeAndroid();
    }

    if (Platform.isWindows) {
      await _initializeWindows();
    }

    final scheduleProvider = ScheduleProvider();
    final themeProvider = ThemeProvider();
    await Future.wait<void>([scheduleProvider.ready, themeProvider.ready]);

    return AppBootstrapResult(
      scheduleProvider: scheduleProvider,
      themeProvider: themeProvider,
    );
  }

  static Future<void> _initializeAndroid() async {
    try {
      await ClassReminderService.initialize();
    } catch (e, st) {
      debugPrint('课前提醒初始化失败，继续启动: $e\n$st');
    }
  }

  static Future<void> _initializeWindows() async {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1100, 700),
      minimumSize: Size(860, 560),
      center: true,
      title: AppTitles.appName,
      titleBarStyle: TitleBarStyle.normal,
    );
    unawaited(windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    }));
  }
}
