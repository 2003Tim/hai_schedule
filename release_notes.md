v1.0.10 正式发布，对应标签 v1.0.10，对应提交待填写。

更新内容：
- 修复：已同步课表后，新建学期时仍提示"请先同步课表以更新学期列表"的问题
  - syncCourse 改为每次同步都主动拉取最新学期目录，不再依赖"catalog 为空"才触发的条件判断
  - _setCoursesNow 只在磁盘 catalog 有效时才覆盖内存值，防止竞态导致有效数据被空值覆盖
  - processScheduleJson 中 semesterOptions 为空时补充调用 refreshKnownSemesterCatalog，保持内存与磁盘一致

发布资产：
- Windows x64 便携包（zip）
- Android split-per-abi APK：`armeabi-v7a`、`arm64-v8a`、`x86_64`

下载说明：
- 大多数 Android 手机请选择 `arm64-v8a`
- 较老的 32 位 Android 设备请选择 `armeabi-v7a`
- `x86_64` 主要用于模拟器或少数特殊环境
- Windows 用户解压 `windows-x64.zip` 后运行 `hai_schedule.exe`

构建校验：
- `flutter pub get` 通过
- `flutter analyze` 通过
- `flutter build apk --release --split-per-abi` 通过
- `flutter build windows --release` 通过
