# HaiSchedule

海南大学课表应用，基于 Flutter，当前同时覆盖：

- Android 主应用
- Android 桌面小组件
- Windows 桌面端

## 当前能力

- 多学期课表归档与切换
- 教务系统登录抓取课表
- 手动粘贴 JSON 导入
- 临时加课、停课、调课
- Android 课前提醒
- Android 上课自动静音
- Android 后台自动同步
- Android 今日课表小组件
- 备份与恢复
- 主题与背景自定义
- Windows 迷你悬浮模式

## 目录说明

- `lib/` Flutter 主代码
- `android/` Android 原生能力与小组件实现
- `windows/` Windows 打包与窗口支持
- `test/` 单元测试与基础行为测试

## 开发运行

```bash
flutter pub get
flutter run
```

Windows:

```bash
flutter run -d windows
```

Android:

```bash
flutter run -d android
```

## 课表数据流

项目现在统一按“学期归档”持久化：

1. 登录抓取、手动导入、前台同步、后台同步都会落到当前学期归档。
2. App 启动时优先从当前活动学期归档恢复。
3. Android 小组件、提醒、自动静音都基于当前课表与临时安排生成衍生数据。

这样可以尽量避免“同步成功了，但 App / 小组件 / 提醒看到的不是同一份课表”。

## 自动同步

Android 自动同步会：

- 读取当前活动学期
- 尝试复用当前登录态
- 必要时使用本机保存的账号密码做前台恢复登录
- 分页拉取完整课表，避免只拿到第一页
- 更新学期归档与小组件数据

## 备份与恢复

备份现在只包含长期有意义的数据：

- 学期归档
- 临时安排
- 作息配置
- 自动化开关与提醒偏好
- 主题与显示偏好

不会导出以下敏感或运行态信息：

- Cookie 登录态快照
- 最近同步错误与瞬时状态
- 提醒/静音的瞬时构建结果

恢复时会先完整校验，再执行覆盖；如果遇到非法备份内容，会保留当前本地数据。

## Android 签名文件

发布签名材料现在建议放在：

- `android/local/key.properties`
- `android/local/upload-keystore.jks`

`android/local/` 已加入忽略规则，避免误提交。

`android/app/build.gradle.kts` 会优先读取 `android/local/key.properties`，并兼容旧的 `android/key.properties` 配置格式。

## 隐私与安全

- 账号密码只保存在本机安全存储中
- Android 侧为了后台续登，会同步一份到本机加密存储
- 备份文件不再包含 Cookie 快照

## 已知注意事项

- Android 自动同步、小组件、提醒、自动静音只在 Android 平台生效
- Windows 端主要提供课表查看和迷你窗口能力
- 教务系统页面结构变化时，登录抓取脚本可能需要跟进调整

## 推荐后续工作

- 继续补同步链路与备份恢复的契约测试
- 拆分超大文件，例如 `schedule_grid.dart`、`daily_schedule_view.dart`、`home_screen.dart`
- 把登录抓取的跨平台公共逻辑进一步抽离
