# HaiSchedule

> Languages / 语言: [简体中文](README.md) · **English**

A class schedule app for Hainan University, built with Flutter, targeting Android and Windows.

---

## Overview

### Schedule core
- Per-semester archives with manual semester creation and switching
- WebView-based login + scrape against the university portal (`ehall.hainanu.edu.cn`)
- Week view (swipe left/right to change week) and day view (swipe left/right to change day)
- Toggle between weekday-only and 7-day columns; off-week courses can be dimmed or hidden
- Per-semester ad-hoc overrides (add, cancel, reschedule a class) with orphaned-override detection
- Home "next lesson" band: focuses on the next class within today/tomorrow only, with a no-class empty state, a week-progress ring, and a week overview sheet

### Android-only
- Pre-class reminders (local notifications, 5 / 10 / 15 / 30 min lead time or off, rolling 7-day window)
- Auto-silence / DND during class (AlarmManager scheduled, precise mode supported)
- Daily background auto-sync (AlarmManager + BroadcastReceiver, with session renewal and diff)
- Sync center (history, manual trigger, frequency tuning)
- 4×2 "today's schedule" home-screen widget (previous-day / today / next-day toggle, empty / busy states, lesson status copy)

### Windows-only
- Pre-class reminder strategy persistence + 7-day future desktop preview (no native system notifications)
- Foreground auto-sync (frequency-driven check on app start / re-foreground, then re-enters the login + fetch flow)
- Mini overlay window (draggable, opacity-adjustable, always-on-top)

### Cross-platform
- Themes (multiple presets, follows system light/dark)
- Custom background image (Gaussian blur + opacity, frosted-glass card style)
- Customizable timetable (11 sections, edit start/end times per section, auto-generation supported)
- Secure credential storage (`FlutterSecureStorage`; on Android, additionally mirrored to native encrypted storage so background sync can renew sessions)

---

## Platform support

| Feature | Android | Windows |
|---|:---:|:---:|
| View & fetch schedule | ✓ | ✓ |
| WebView portal scrape | ✓ | ✓ |
| Ad-hoc overrides | ✓ | ✓ |
| Themes / background | ✓ | ✓ |
| Home next-lesson card | ✓ | ✓ |
| Pre-class notifications | ✓ | — |
| Pre-class strategy / future preview | ✓ | ✓ |
| Auto-silence | ✓ | — |
| Auto-sync | ✓ (background) | ✓ (foreground) |
| Home-screen widget | ✓ | — |
| Mini overlay window | — | ✓ |

---

## Tech stack

| Layer | Technology |
|---|---|
| Framework | Flutter / Dart 3.7+ |
| State management | Provider (`ScheduleProvider`, `ThemeProvider`) |
| Local storage | `SharedPreferences` + `FlutterSecureStorage` |
| HTTP | Dio |
| WebView | `webview_flutter` (Android) / `webview_windows` (Windows) |
| Notifications | `flutter_local_notifications` + `timezone` |
| Home-screen widget | `home_widget` + Kotlin `AppWidgetProvider` |
| Auto-sync | `AlarmManager` + `BroadcastReceiver` (Android), foreground frequency check (Windows) |
| Auto-silence | `AlarmManager` + `NotificationManager` (Kotlin) |
| Window management | `window_manager` (Windows) |

---

## Project layout

```
lib/
├── main.dart
├── models/                        # Data models
│   ├── course.dart                # Course, schedule slot, week ranges
│   ├── schedule_override.dart     # Ad-hoc overrides (add / cancel / reschedule)
│   ├── display_schedule_slot.dart # View-layer render model
│   ├── school_time.dart           # Timetable configuration
│   ├── schedule_parser.dart       # Portal JSON parser
│   ├── auto_sync_models.dart      # Auto-sync state models
│   ├── reminder_models.dart       # Pre-class reminder config and state
│   ├── class_silence_models.dart  # Auto-silence config and state
│   ├── login_fetch_models.dart    # Login + fetch pipeline models
│   ├── login_fetch_coordinator_models.dart
│   ├── storage_records.dart       # Storage-layer records
│   ├── theme_preferences_record.dart
│   └── app_theme_preset.dart      # Theme preset definitions
│
├── services/                      # Business / service layer
│   ├── app_bootstrap.dart         # App startup orchestration (platform init + Provider warmup)
│   ├── schedule_provider.dart     # Core state (ChangeNotifier)
│   ├── theme_provider.dart        # Theme state
│   ├── app_storage.dart           # Unified storage entry point (singleton)
│   ├── app_repositories.dart      # Repository layer (domain wrappers over AppStorage)
│   ├── auto_sync_service.dart     # Auto-sync scheduling and execution (Android background / Windows foreground)
│   ├── class_reminder_service.dart# Pre-class reminder scheduling (Android notifications / Windows preview)
│   ├── class_silence_service.dart # Auto-silence in class
│   ├── widget_sync_service.dart   # Pushes data to the home-screen widget
│   ├── schedule_derived_output_coordinator.dart # Coordinates reminder / silence / widget derivations
│   ├── schedule_state_loader.dart # Restores from archive and assembles semester context
│   ├── schedule_sync_result_service.dart # Post-sync diff summary + status persistence
│   ├── auth_credentials_service.dart # Secure credential I/O
│   ├── schedule_login_fetch_service.dart # Login + fetch orchestration
│   ├── schedule_login_script_builder.dart# JS script builder
│   ├── login_fetch_coordinator.dart      # Multi-step fetch state machine
│   ├── portal_relogin_service.dart       # Session-expiry recovery
│   ├── course_repository.dart    # Course fetch repository (with silent re-login)
│   └── api_service.dart           # HTTP portal calls
│
├── screens/                       # Screens
│   ├── home_screen.dart           # Home (schedule + menu)
│   ├── login_flow_state_mixin.dart# Shared login-flow mixin
│   ├── login_screen.dart          # Windows login screen
│   ├── login_screen_android.dart  # Android login screen
│   ├── login_router.dart          # Platform router
│   ├── sync_center_screen.dart    # Sync center
│   ├── semester_management_screen.dart   # Semester management
│   ├── schedule_overrides_screen.dart    # Ad-hoc override management
│   ├── school_time_settings_screen.dart  # Timetable settings
│   ├── reminder_settings_screen.dart     # Pre-class reminder settings
│   ├── theme_settings_screen.dart        # Themes and background
│   ├── windows_desktop_shell_screen.dart # Windows desktop shell
│   └── app_launch_splash_screen.dart     # Splash (Android)
│
├── widgets/                       # UI components
│   ├── schedule_grid.dart         # Weekly schedule grid
│   ├── daily_schedule_view.dart   # Day-view schedule
│   ├── home_next_lesson_card.dart # Home next-lesson card (today/tomorrow + week-progress ring)
│   ├── swipeable_schedule_view.dart      # Swipeable week view
│   ├── swipeable_daily_schedule_view.dart# Swipeable day view
│   ├── mini_overlay.dart          # Windows mini overlay
│   ├── schedule_background.dart   # Background layer
│   ├── schedule_override_form_sheet.dart # Ad-hoc override form
│   ├── schedule_slot_dialogs.dart        # Lesson cell dialogs
│   ├── login_webview_adapters.dart       # WebView platform adapters
│   └── ... (per-screen section components)
│
└── utils/                         # Pure-function utilities
    ├── week_calculator.dart       # Week calculation
    ├── schedule_display_slot_resolver.dart # Lesson cell render logic
    ├── class_reminder_planner.dart# Reminder scheduling (pure)
    ├── class_silence_planner.dart # Silence scheduling (pure)
    ├── auto_sync_course_diff.dart # Course diff
    ├── auto_sync_schedule_policy.dart # Sync timing policy
    ├── schedule_override_validator.dart  # Orphaned-override detection
    ├── schedule_ui_tokens.dart    # Home/countdown visual tokens
    ├── theme_appearance.dart      # Theme appearance + readability color math
    ├── app_storage_codec.dart     # Storage codec helpers
    ├── constants.dart             # Course color palette (FNV-1a hashing)
    ├── app_logger.dart            # Unified logging
    └── ... (JS scripts, text formatters, etc.)

android/app/src/main/kotlin/com/hainanu/hai_schedule/
├── MainActivity.kt                # MethodChannel registry
├── AutoSyncScheduler.kt           # AlarmManager / BroadcastReceiver background sync
├── ClassSilenceScheduler.kt       # AlarmManager auto-silence
├── TodayScheduleWidgetProvider.kt # Home-screen widget rendering
├── WidgetRefreshScheduler.kt      # Widget refresh scheduling
└── NativeCredentialStore.kt       # Native encrypted credential storage

test/
├── widgets/                       # Widget and layout tests (home, desktop adaptation, schedule grid)
├── services/                      # Service-layer tests (behavioural contracts)
└── utils/                         # Pure-function utility tests
```

---

## Development

```bash
flutter pub get

# Windows
flutter run -d windows

# Android
flutter run -d android
```

---

## Architecture

### State management

Two root Providers:

- `ScheduleProvider`: holds courses, week state, and ad-hoc overrides; fans derived outputs (widget sync, reminder re-planning, auto-silence re-planning) through `ScheduleDerivedOutputCoordinator`.
- `ThemeProvider`: holds theme preferences; persists asynchronously after updates and triggers a widget appearance refresh.

### Startup

`main()` calls `AppBootstrap.initialize()` for platform init, then warms up `ScheduleProvider` and `ThemeProvider`:

- Android: initialises the pre-class reminder channel, shows the splash, then enters the home screen
- Windows: configures window size / title / centering, then enters the desktop shell

### Storage layering

```
Service / Screen
    └─ Repository (domain methods)
           └─ AppStorage (unified SharedPreferences + FlutterSecureStorage entry point)
```

All storage operations go through the `AppStorage` singleton and its repositories. `AppStorage.resetForTesting()` supports test isolation.

### Login + fetch pipeline

```
LoginRouter (platform dispatch)
    ├─ LoginScreen (Windows)
    └─ LoginScreenAndroid (Android)
           ↓ (shared LoginFlowStateMixin)
    LoginFetchCoordinator (multi-step state machine)
           ↓
    LoginWebviewAdapter (platform WebView adapter)
           ↓ (JS bridge callbacks)
    ScheduleLoginFetchService (parse, save, record sync)
```

---

## Course data flow

All course data is persisted per semester archive:

1. Login fetch, foreground sync, and background sync all land in the active semester archive.
2. On startup, the app restores from the active semester archive.
3. The widget, pre-class reminders, and auto-silence all derive their outputs in real time from the active archive + ad-hoc overrides.

---

## Home next-lesson card

- `HomeNextLessonCard` only shows the next class within today/tomorrow; it no longer spans further dates.
- When there is no class, a lightweight empty-state copy is shown so the home layout does not collapse.
- The progress ring on the right surfaces the course's week distribution within the active semester.
- This home presentation does not affect how the reminder settings screen builds and previews future 7-day reminders.

---

## Auto-sync modes

Android background sync:

1. AlarmManager wakes `AutoSyncScheduler` at the configured cadence
2. Reads the active semester and the cookie snapshot
3. If the session has expired, attempts a silent re-login with the locally stored credential
4. Calls the portal API to fetch the schedule and diffs against the local copy
5. On success, updates the archive and pushes the diff summary to the sync center

Windows foreground sync:

1. On app start or re-foreground, checks whether the configured cadence has elapsed
2. If due, reuses the same login + fetch pipeline as the foreground flow
3. Not a system-level background task, but still reuses credential management, diffing, and archive persistence

Android also triggers a foreground sync on app resume; Windows relies on this foreground check rather than a persistent background scheduler.

---

## Privacy & security

- Credentials are stored only on-device via `FlutterSecureStorage`.
- When Android background sync needs to renew a session, the credential is additionally mirrored to native `EncryptedSharedPreferences`. Nothing is uploaded to any server.

---

## Packaging & release

### Version management

The version lives in `pubspec.yaml`:

```yaml
version: 1.0.0+1
#         ↑       ↑
#    versionName  versionCode (must increase on every release)
```

### Android

Make sure `android/local/key.properties` and the corresponding keystore are in place, then:

```bash
# Split-per-ABI APKs (for direct install)
flutter build apk --release --split-per-abi

# AAB (for Google Play upload)
flutter build appbundle --release
```

Output paths:
- APK:
  - `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
  - `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
  - `build/app/outputs/flutter-apk/app-x86_64-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

Recommended release naming:
- `HaiSchedule-vX.Y.Z-android-armeabi-v7a.apk`
- `HaiSchedule-vX.Y.Z-android-arm64-v8a.apk`
- `HaiSchedule-vX.Y.Z-android-x86_64.apk`
- `HaiSchedule-vX.Y.Z.aab`

Download guidance:
- Most Android phones should prefer `arm64-v8a`
- Older 32-bit Android devices should pick `armeabi-v7a`
- `x86_64` is mainly for emulators or a few special environments

Without a signing config, the build falls back to a debug key; those artifacts cannot be published to the Play Store.

### Windows

```bash
flutter build windows --release
```

Output path: `build/windows/x64/runner/Release/`

Copy the entire `Release/` directory to `build/release-assets/vX.Y.Z/HaiSchedule-vX.Y.Z-windows-x64/`, then zip it as:

- `HaiSchedule-vX.Y.Z-windows-x64.zip`

Windows users unzip and run `hai_schedule.exe`.

### GitHub Release

A formal release should consistently include:

- Title: `vX.Y.Z`
- Body: version, tag / commit, change log, release assets, download guidance, build verification
- Assets:
  - Windows x64 zip
  - Android split-per-ABI APKs
  - AAB (if shipping to Play this release)

See [docs/release_workflow.md](docs/release_workflow.md) for the full release flow, body template, and historical conventions.

---

## Android signing

It is recommended to place release-signing material at:

- `android/local/key.properties`
- `android/local/upload-keystore.jks`

`android/local/` is already gitignored, so nothing gets committed by accident. `android/app/build.gradle.kts` reads from that path first, and remains compatible with the older `android/key.properties` layout.

---

## Known caveats

- Android package name is fixed at `com.hainanu.hai_schedule`; Kotlin source paths must match exactly
- Native resources must live under `android/app/src/main/res/...` — do not create a nested duplicate directory
- The home-screen widget layout (RemoteViews) can only use a restricted set of system-supported View types
- When the portal page structure changes, the login + fetch JS injection scripts may need to be adjusted accordingly
- Windows does not raise pre-class system notifications and does not support auto-silence
- The Windows side currently provides reminder strategy persistence, a 7-day desktop preview, and foreground auto-sync — it is not a system-level background-resident task
