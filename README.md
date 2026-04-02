# HaiSchedule — 海大课表

海南大学课表应用，基于 Flutter，支持 Android 和 Windows 双平台。

---

## 功能概览

### 课表核心
- 多学期归档与切换，支持手动新建学期
- 教务系统（ehall.hainanu.edu.cn）WebView 登录抓取课表
- 手动粘贴 JSON 导入
- 周课表视图（左右滑动切周）和日课表视图（左右滑动切天）
- 工作日 / 7 天列数切换，非本周课程灰显 / 隐藏
- 临时加课、停课、调课（按学期维护，支持孤立状态检测）

### Android 专属
- 课前提醒（本地通知，支持提前 5 / 10 / 15 / 30 分钟或关闭，7 天滚动窗口）
- 上课自动静音 / 勿扰（AlarmManager 调度，支持精准模式）
- 后台每日自动同步（WorkManager，支持会话续签与差量对比）
- 同步中心（查看同步历史、手动触发、频率配置）
- 今日课表 4×2 桌面小组件（支持前一天 / 今天 / 后一天切换，空态 / 有课态，课程状态文案）

### Windows 专属
- 迷你悬浮小窗（可拖拽、透明度可调、可置顶）

### 通用
- 主题系统（多套预设，跟随系统深浅色）
- 自定义背景图（高斯模糊 + 透明度调节，毛玻璃卡片风格）
- 作息时间自定义（11 节课结构，可编辑每节开始 / 结束时间，支持自动生成）
- 备份与恢复（JSON 文件，恢复失败自动回滚）
- 账号密码安全存储（FlutterSecureStorage，Android 额外同步到原生加密存储供后台同步使用）

---

## 平台支持

| 功能 | Android | Windows |
|---|:---:|:---:|
| 课表查看与导入 | ✓ | ✓ |
| 教务系统 WebView 抓取 | ✓ | ✓ |
| 临时覆盖 | ✓ | ✓ |
| 主题 / 背景 | ✓ | ✓ |
| 备份恢复 | ✓ | ✓ |
| 课前提醒 | ✓ | — |
| 自动静音 | ✓ | — |
| 后台自动同步 | ✓ | — |
| 桌面小组件 | ✓ | — |
| 迷你悬浮窗 | — | ✓ |

---

## 技术栈

| 层次 | 技术 |
|---|---|
| 框架 | Flutter / Dart 3.7+ |
| 状态管理 | Provider（ScheduleProvider、ThemeProvider） |
| 本地存储 | SharedPreferences + FlutterSecureStorage |
| HTTP | Dio |
| WebView | webview_flutter（Android）/ webview_windows（Windows）|
| 通知 | flutter_local_notifications + timezone |
| 小组件 | home_widget + Kotlin AppWidgetProvider |
| 后台同步 | WorkManager（Kotlin） |
| 自动静音 | AlarmManager + NotificationManager（Kotlin） |
| 窗口管理 | window_manager（Windows） |

---

## 目录结构

```
lib/
├── main.dart
├── models/                        # 数据模型
│   ├── course.dart                # 课程、排课槽、周次区间
│   ├── schedule_override.dart     # 临时覆盖（加/停/调课）
│   ├── display_schedule_slot.dart # 视图层渲染模型
│   ├── school_time.dart           # 作息时间配置
│   ├── schedule_parser.dart       # 教务系统 JSON 解析
│   ├── auto_sync_models.dart      # 自动同步状态模型
│   ├── reminder_models.dart       # 课前提醒配置与状态
│   ├── class_silence_models.dart  # 自动静音配置与状态
│   ├── login_fetch_models.dart    # 登录抓取流程模型
│   ├── login_fetch_coordinator_models.dart
│   ├── storage_records.dart       # 存储层数据记录
│   ├── theme_preferences_record.dart
│   └── app_theme_preset.dart      # 主题预设定义
│
├── services/                      # 业务服务层
│   ├── schedule_provider.dart     # 核心状态管理（ChangeNotifier）
│   ├── theme_provider.dart        # 主题状态管理
│   ├── app_storage.dart           # 统一存储入口（单例）
│   ├── app_repositories.dart      # 仓库层（对 AppStorage 的领域包装）
│   ├── auto_sync_service.dart     # 自动同步调度与执行
│   ├── class_reminder_service.dart# 课前提醒调度
│   ├── class_silence_service.dart # 上课自动静音
│   ├── widget_sync_service.dart   # 桌面小组件数据推送
│   ├── auth_credentials_service.dart # 账号密码安全存取
│   ├── schedule_login_fetch_service.dart # 登录抓取编排
│   ├── schedule_login_script_builder.dart# JS 脚本构建
│   ├── login_fetch_coordinator.dart      # 多步抓取状态机
│   ├── portal_relogin_service.dart       # 会话过期恢复登录
│   ├── api_service.dart           # HTTP 课表接口调用
│   └── app_backup_service.dart    # 备份与恢复（含回滚）
│
├── screens/                       # 页面层
│   ├── home_screen.dart           # 主页（课表 + 菜单）
│   ├── login_flow_state_mixin.dart# 登录流程公共 Mixin
│   ├── login_screen.dart          # Windows 登录页
│   ├── login_screen_android.dart  # Android 登录页
│   ├── login_router.dart          # 平台路由
│   ├── import_screen.dart         # 手动导入
│   ├── sync_center_screen.dart    # 同步中心
│   ├── semester_management_screen.dart   # 学期管理
│   ├── schedule_overrides_screen.dart    # 临时覆盖管理
│   ├── school_time_settings_screen.dart  # 作息时间设置
│   ├── reminder_settings_screen.dart     # 课前提醒设置
│   ├── theme_settings_screen.dart        # 主题与背景
│   ├── backup_restore_screen.dart        # 备份恢复
│   ├── windows_desktop_shell_screen.dart # Windows 主壳
│   └── app_launch_splash_screen.dart     # 启动页（Android）
│
├── widgets/                       # UI 组件库
│   ├── schedule_grid.dart         # 周课表网格
│   ├── daily_schedule_view.dart   # 日课表视图
│   ├── swipeable_schedule_view.dart      # 可滑动周视图
│   ├── swipeable_daily_schedule_view.dart# 可滑动日视图
│   ├── mini_overlay.dart          # Windows 迷你悬浮窗
│   ├── schedule_background.dart   # 背景图层
│   ├── schedule_override_form_sheet.dart # 临时覆盖表单
│   ├── schedule_slot_dialogs.dart        # 课程格弹窗
│   ├── login_webview_adapters.dart       # WebView 平台适配器
│   └── ... (各页面对应的 section 组件)
│
└── utils/                         # 纯函数工具
    ├── week_calculator.dart       # 周次计算
    ├── schedule_display_slot_resolver.dart # 课程格渲染逻辑
    ├── class_reminder_planner.dart# 提醒排期（纯函数）
    ├── class_silence_planner.dart # 静音排期（纯函数）
    ├── auto_sync_course_diff.dart # 课表差量对比
    ├── auto_sync_schedule_policy.dart # 同步时间策略
    ├── schedule_override_validator.dart  # 覆盖项孤立检测
    ├── app_storage_codec.dart     # 存储编解码工具
    ├── constants.dart             # 课程配色（FNV-1a 哈希）
    ├── app_logger.dart            # 统一日志
    └── ... (JS 脚本、文本格式化等工具)

android/app/src/main/kotlin/com/hainanu/hai_schedule/
├── MainActivity.kt                # MethodChannel 注册中心
├── AutoSyncScheduler.kt           # WorkManager 后台同步任务
├── ClassSilenceScheduler.kt       # AlarmManager 自动静音调度
├── TodayScheduleWidgetProvider.kt # 桌面小组件渲染
├── WidgetRefreshScheduler.kt      # 小组件定期刷新
└── NativeCredentialStore.kt       # 原生加密凭据存储

test/
├── services/                      # 服务层测试（行为契约）
└── utils/                         # 纯函数工具测试
```

---

## 开发运行

```bash
flutter pub get

# Windows
flutter run -d windows

# Android
flutter run -d android
```

---

## 架构说明

### 状态管理

两个根 Provider：

- `ScheduleProvider`：持有课表数据、周次状态、临时覆盖，更新后自动扇出至小组件同步、课前提醒重排和自动静音重排。
- `ThemeProvider`：持有主题偏好，更新后异步保存并触发小组件外观刷新。

### 存储分层

```
Service / Screen
    └─ Repository（领域方法）
           └─ AppStorage（SharedPreferences + FlutterSecureStorage 统一入口）
```

所有存储操作均通过 `AppStorage` 单例和对应仓库类进行，`AppStorage.resetForTesting()` 支持测试隔离。

### 登录抓取链路

```
LoginRouter（平台分发）
    ├─ LoginScreen（Windows）
    └─ LoginScreenAndroid（Android）
           ↓（共用 LoginFlowStateMixin）
    LoginFetchCoordinator（多步状态机）
           ↓
    LoginWebviewAdapter（平台 WebView 适配器）
           ↓（JS Bridge 回传）
    ScheduleLoginFetchService（解析保存 + 同步记录）
```

---

## 课表数据流

所有课表数据按"学期归档"持久化：

1. 登录抓取、手动导入、前台同步、后台同步均落到对应学期归档。
2. App 启动时从活动学期归档恢复课表。
3. 小组件、课前提醒、自动静音均基于当前归档 + 临时覆盖实时生成衍生数据。

---

## Android 自动同步

后台同步流程：

1. WorkManager 按配置频率唤醒 `AutoSyncScheduler`
2. 读取活动学期和 Cookie 快照
3. 会话失效时尝试用本机保存的凭据重新登录
4. 调用教务系统 API 拉取课表，与本地做差量对比
5. 成功后更新归档，并推送差量摘要至同步中心

前台同步在 App 恢复时也会自动触发（Android）。

---

## 备份与恢复

备份内容（长期有意义的数据）：

- 学期归档（课表 + 原始 JSON）
- 临时覆盖
- 作息时间配置
- 自动同步频率与提醒设置偏好
- 主题与显示偏好

不导出以下数据：

- Cookie 登录态快照
- 最近同步错误与瞬时状态
- 提醒 / 静音的构建缓存

恢复流程先验证备份完整性，再执行覆盖；若遇到非法内容，自动回滚到恢复前的本地数据。

---

## 隐私与安全

- 账号密码仅存储在本机，使用 `FlutterSecureStorage`
- Android 后台同步需要续签时，凭据额外镜像到原生 `EncryptedSharedPreferences`，不上传至任何服务器
- 备份文件不包含 Cookie 快照

---

## Android 签名配置

发布签名材料建议放置于：

- `android/local/key.properties`
- `android/local/upload-keystore.jks`

`android/local/` 已加入 `.gitignore`，不会误提交。`android/app/build.gradle.kts` 会优先读取该路径，并兼容旧版 `android/key.properties` 格式。

---

## 已知注意事项

- Android 包名固定为 `com.hainanu.hai_schedule`，Kotlin 源码路径须严格与之对应
- 原生资源文件必须位于 `android/app/src/main/res/...`，避免创建错误的双层目录
- 桌面小组件布局（RemoteViews）只能使用系统支持的受限 View 类型
- 教务系统页面结构变化时，登录抓取的 JS 注入脚本可能需要同步调整
- Windows 端不支持课前提醒、自动静音和后台同步，这些功能在 Windows 下会被平台守卫静默跳过
