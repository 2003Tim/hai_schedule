import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'package:hai_schedule/models/window_shell_preferences.dart';
import 'package:hai_schedule/screens/app_launch_splash_screen.dart';
import 'package:hai_schedule/screens/home_screen.dart';
import 'package:hai_schedule/utils/app_platform.dart';
import 'package:hai_schedule/screens/windows_desktop_shell_screen.dart';
import 'package:hai_schedule/services/app_bootstrap.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/services/theme_provider.dart';
import 'package:hai_schedule/utils/app_titles.dart';
import 'package:hai_schedule/utils/window_shell_preferences_store.dart';
import 'package:hai_schedule/widgets/mini_overlay.dart';

final globalScaffoldKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureAndroidSystemUi();
  final bootstrap = await AppBootstrap.initialize();
  runApp(
    HaiScheduleApp(
      scheduleProvider: bootstrap.scheduleProvider,
      themeProvider: bootstrap.themeProvider,
    ),
  );
}

Future<void> _configureAndroidSystemUi() async {
  if (!AppPlatform.instance.isAndroid) return;
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}

class HaiScheduleApp extends StatelessWidget {
  const HaiScheduleApp({
    super.key,
    required this.scheduleProvider,
    required this.themeProvider,
    this.homeOverride,
  });

  final ScheduleProvider scheduleProvider;
  final ThemeProvider themeProvider;
  final Widget? homeOverride;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ScheduleProvider>.value(value: scheduleProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: Builder(
        builder: (context) {
          final theme = context.watch<ThemeProvider>();
          return MaterialApp(
            title: AppTitles.appName,
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: globalScaffoldKey,
            theme: theme.themeData,
            darkTheme: theme.darkThemeData,
            themeMode: theme.themeMode,
            home:
                homeOverride ??
                (AppPlatform.instance.isWindows
                    ? const WindowsShell()
                    : const AndroidShell()),
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
    final width = MediaQuery.sizeOf(context).width;
    final assetPath = AppLaunchSplashScreen.assetPathForWidth(width);
    await precacheImage(AssetImage(assetPath), context);
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
    _loadWindowPreferences();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _loadWindowPreferences() async {
    final prefs = await WindowShellPreferencesStore.load();
    setState(() {
      _opacity = prefs.opacity;
      _alwaysOnTop = prefs.alwaysOnTop;
    });
  }

  Future<void> _saveWindowPreferences() {
    return WindowShellPreferencesStore.save(
      WindowShellPreferences(opacity: _opacity, alwaysOnTop: _alwaysOnTop),
    );
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
      await windowManager.setTitle(AppTitles.miniModeTitle);
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
      await windowManager.setTitle(AppTitles.appName);

      setState(() => _isMiniMode = false);
    } finally {
      _switching = false;
    }
  }

  void _onOpacityChanged(double value) async {
    setState(() => _opacity = value);
    await windowManager.setOpacity(value);
    await _saveWindowPreferences();
  }

  void _onAlwaysOnTopChanged(bool value) async {
    setState(() => _alwaysOnTop = value);
    await windowManager.setAlwaysOnTop(value);
    await _saveWindowPreferences();
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
