import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/app_launch_splash_screen.dart';
import 'screens/windows_desktop_shell_screen.dart';
import 'services/class_reminder_service.dart';
import 'services/schedule_provider.dart';
import 'services/theme_provider.dart';
import 'screens/home_screen.dart';
import 'widgets/mini_overlay.dart';
import 'package:window_manager/window_manager.dart';

final globalScaffoldKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    try {
      await ClassReminderService.initialize();
    } catch (e, st) {
      debugPrint('课前提醒初始化失败，继续启动: $e\n$st');
    }
  }

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1100, 700),
      minimumSize: Size(860, 560),
      center: true,
      title: '海大课表',
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const HaiScheduleApp());
}

class HaiScheduleApp extends StatelessWidget {
  const HaiScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Builder(
        builder: (context) {
          final theme = context.watch<ThemeProvider>();
          return MaterialApp(
            title: '海大课表',
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: globalScaffoldKey,
            theme: theme.themeData,
            darkTheme: theme.darkThemeData,
            themeMode: theme.themeMode,
            home:
                Platform.isWindows
                    ? const WindowsShell()
                    : const AndroidShell(),
          );
        },
      ),
    );
  }
}

class AndroidShell extends StatefulWidget {
  const AndroidShell({super.key});

  @override
  State<AndroidShell> createState() => _AndroidShellState();
}

class _AndroidShellState extends State<AndroidShell> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareLaunch();
    });
  }

  Future<void> _prepareLaunch() async {
    final start = DateTime.now();
    await precacheImage(
      const AssetImage(AppLaunchSplashScreen.assetPath),
      context,
    );
    final elapsed = DateTime.now().difference(start);
    const minSplashDuration = Duration(milliseconds: 900);
    final remaining = minSplashDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
    if (!mounted) return;
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child:
          _showSplash
              ? const AppLaunchSplashScreen(key: ValueKey('launch_splash'))
              : const HomeScreen(key: ValueKey('home_screen')),
    );
  }
}

class WindowsShell extends StatefulWidget {
  const WindowsShell({super.key});

  @override
  State<WindowsShell> createState() => _WindowsShellState();
}

class _WindowsShellState extends State<WindowsShell> with WindowListener {
  bool _isMiniMode = false;
  bool _switching = false;

  Size _savedSize = const Size(1100, 700);
  Offset _savedPosition = Offset.zero;

  double _opacity = 0.95;
  bool _alwaysOnTop = true;

  static const _miniSize = Size(290, 460);

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _loadMiniPrefs();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _loadMiniPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _opacity = prefs.getDouble('mini_opacity') ?? 0.95;
      _alwaysOnTop = prefs.getBool('mini_always_on_top') ?? true;
    });
  }

  Future<void> _saveMiniPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('mini_opacity', _opacity);
    await prefs.setBool('mini_always_on_top', _alwaysOnTop);
  }

  Future<void> _enterMiniMode() async {
    if (_switching) return;
    _switching = true;
    try {
      _savedSize = await windowManager.getSize();
      _savedPosition = await windowManager.getPosition();

      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      await windowManager.setSize(_miniSize);
      await windowManager.setMinimumSize(const Size(280, 400));
      await windowManager.setAlwaysOnTop(_alwaysOnTop);
      await windowManager.setOpacity(_opacity);
      await windowManager.setTitle('海大课表 - 迷你模式');
      await windowManager.setAlignment(Alignment.bottomRight);

      setState(() => _isMiniMode = true);
    } finally {
      _switching = false;
    }
  }

  Future<void> _exitMiniMode() async {
    if (_switching) return;
    _switching = true;
    try {
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setOpacity(1.0);
      await windowManager.setMinimumSize(const Size(800, 500));
      await windowManager.setSize(_savedSize);
      await windowManager.setPosition(_savedPosition);
      await windowManager.setTitle('海大课表');

      setState(() => _isMiniMode = false);
    } finally {
      _switching = false;
    }
  }

  void _onOpacityChanged(double value) async {
    setState(() => _opacity = value);
    await windowManager.setOpacity(value);
    _saveMiniPrefs();
  }

  void _onAlwaysOnTopChanged(bool value) async {
    setState(() => _alwaysOnTop = value);
    await windowManager.setAlwaysOnTop(value);
    _saveMiniPrefs();
  }

  @override
  Widget build(BuildContext context) {
    if (_isMiniMode) {
      return _buildMiniWindow(context);
    }

    return WindowsDesktopShellScreen(onEnterMiniMode: _enterMiniMode);
  }

  Widget _buildMiniWindow(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Scaffold(
        body: MiniScheduleOverlay(
          provider: provider,
          onClose: _exitMiniMode,
          onOpenMain: _exitMiniMode,
          opacity: _opacity,
          alwaysOnTop: _alwaysOnTop,
          onOpacityChanged: _onOpacityChanged,
          onAlwaysOnTopChanged: _onAlwaysOnTopChanged,
        ),
      ),
    );
  }
}
