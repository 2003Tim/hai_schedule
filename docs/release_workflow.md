# Release Workflow

HaiSchedule 后续版本统一按这份规范发布，目标是：

- 版本号、tag、release 标题一致
- 资产命名一致
- GitHub release 正文结构一致
- 历史记录可读，不再出现“测试发布痕迹”

## 1. 版本规则

- `pubspec.yaml` 中维护版本号：`version: X.Y.Z+N`
- Git tag 统一使用：`vX.Y.Z`
- GitHub release 标题统一使用：`vX.Y.Z`
- `versionCode` 必须递增

示例：

```yaml
version: 1.0.7+7
```

对应：

- Tag：`v1.0.7`
- Release title：`v1.0.7`

## 2. 发布前检查

建议至少执行：

```bash
flutter pub get
flutter analyze
flutter test
```

如果发布说明中写了“构建校验通过”，必须以这次发布前的实际命令结果为准。

## 3. 构建命令

### Android

正式安装包统一使用 split per ABI：

```bash
flutter build apk --release --split-per-abi
```

如需商店包，再额外执行：

```bash
flutter build appbundle --release
```

默认产物：

- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

### Windows

```bash
flutter build windows --release
```

默认产物目录：

- `build/windows/x64/runner/Release/`

## 4. 资产命名

统一整理到：

- `build/release-assets/vX.Y.Z/`

Android：

- `HaiSchedule-vX.Y.Z-android-armeabi-v7a.apk`
- `HaiSchedule-vX.Y.Z-android-arm64-v8a.apk`
- `HaiSchedule-vX.Y.Z-android-x86_64.apk`
- `HaiSchedule-vX.Y.Z.aab`

Windows：

- `HaiSchedule-vX.Y.Z-windows-x64.zip`

Windows zip 内建议目录名：

- `HaiSchedule-vX.Y.Z-windows-x64/`

## 5. GitHub Release 资产策略

默认正式 release 资产：

- Windows x64 zip
- Android split per ABI APK 三个架构包

按需附加：

- AAB

如果某个版本没有 Windows 包或没有 AAB，应在 release 正文中明确写出来，而不是省略不解释。

## 6. GitHub Release 正文模板

可直接复用：

```md
vX.Y.Z 正式发布，对应标签 `vX.Y.Z`，对应提交 `abcdef0`。

更新内容：
- ...
- ...
- ...

发布资产：
- Windows x64 便携包（zip）
- Android split-per-abi APK：`armeabi-v7a`、`arm64-v8a`、`x86_64`
- Android AAB（如果本次附带）

下载说明：
- 大多数 Android 手机请选择 `arm64-v8a`
- 较老的 32 位 Android 设备请选择 `armeabi-v7a`
- `x86_64` 主要用于模拟器或少数特殊环境
- Windows 用户解压 `windows-x64.zip` 后运行 `hai_schedule.exe`

构建校验：
- `flutter analyze` 通过
- `flutter test` N 项通过
```

## 7. 历史记录策略

已确定的历史规则：

- `打包` 是历史构建快照，不再视为正式 semver release
- 正式版本使用 `vX.Y.Z`
- 早期 release 如果资产命名较旧，可以保留原文件，不强制重传
- 历史 release 可以修正文案、标题、说明，但尽量不改 tag 和原始资产

如果未来再次出现跳号，例如缺少 `v1.0.4` 这种情况，应二选一：

- 补一个正式 tag/release
- 在后续 release 或 README 中明确说明该版本未单独发布

不要长期保持“版本号存在于分支命名里，但 release 历史没有解释”。

## 8. 发布后检查

至少确认：

- 当前分支和远端同步
- `vX.Y.Z` tag 已推送
- GitHub release 已公开
- 资产数量与预期一致
- 资产名称符合规范
- release 正文包含下载说明

## 9. 当前基准

从 `v1.0.7` 开始，release 页面已经基本符合这份规范。
