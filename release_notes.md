v1.1.0 正式发布，对应标签 `v1.1.0`。

更新内容：
- 新增：本科教务（jxgl.hainanu.edu.cn）课表来源，与研究生（ehall）来源并行
  - 新增 `ScheduleSource` 枚举（研究生 / 本科）作为双源调度的统一抽象
  - 新增本科课表 HTML 解析器，支持同一课程跨星期 / 节次的多时段合并
  - 新增本科登录注入脚本：登录页探测、学期检测、分块拉取课表、学期切换
  - 凭据 / cookie / 同步 / 状态加载 / 存储各层贯通 `ScheduleSource`，本科与研究生凭据在 secure storage 下分键存放，互不影响
  - 同步中心新增 “研究生 / 本科” 分段切换与按来源展示的凭据面板；首页、学期管理、Windows 桌面外壳均按来源显示文案
  - Android 原生 MethodChannel 接受可选的 `source` 参数（凭据 / cookie / 后台同步）
- 修复：本科会话过期触发静默重登时，避免用本科账号去研究生 CAS 表单提交导致 cookie 写入错位（`portal_relogin_service.reLogin` 在本科来源下直接抛 `LoginExpiredException`，让 UI 引导用户走 WebView 重新登录）
- 修复：本科登录失败提示不再一律拼接 “请重新输入验证码”，仅在脚本上报的关键字命中验证码类错误时才提示重输验证码；账号 / 密码类错误按研究生分支原文回显并停止自动尝试
- 工程：`.gitignore` 追加 `/android/build/`，避免 Gradle 聚合产物显示为未跟踪

发布资产：
- Windows x64 便携包（zip）
- Android split-per-abi APK：`armeabi-v7a`、`arm64-v8a`、`x86_64`
- 本次不附带 Android AAB，与 v1.0.10 的资产策略保持一致

下载说明：
- 大多数 Android 手机请选择 `arm64-v8a`
- 较老的 32 位 Android 设备请选择 `armeabi-v7a`
- `x86_64` 主要用于模拟器或少数特殊环境
- Windows 用户解压 `windows-x64.zip` 后运行 `hai_schedule.exe`

构建校验：
- `flutter pub get` 通过
- `flutter analyze` 通过
- `flutter test` 183 项通过
- `flutter build apk --release --split-per-abi` 通过
- `flutter build windows --release` 通过
