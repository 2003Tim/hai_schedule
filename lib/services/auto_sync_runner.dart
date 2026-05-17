import 'package:hai_schedule/services/app_repositories.dart';
import 'package:hai_schedule/services/schedule_sync_result_service.dart';

/// 一次自动同步的运行时上下文。
///
/// 把"互斥锁"与"对外部仓库的依赖"封装成可注入的实例，避免 [AutoSyncService]
/// 把这些状态作为静态字段直接挂在类身上 —— 那样会让多个测试共享同一个锁，
/// 也无法替换底层 repository。需要测试隔离时构造一个新实例 / mock 注入即可。
class AutoSyncRunner {
  AutoSyncRunner({
    ScheduleRepository? scheduleRepository,
    SyncRepository? syncRepository,
    ScheduleSyncResultService? syncResultService,
  }) : scheduleRepository = scheduleRepository ?? ScheduleRepository(),
       syncRepository = syncRepository ?? SyncRepository(),
       syncResultService = syncResultService ?? ScheduleSyncResultService();

  final ScheduleRepository scheduleRepository;
  final SyncRepository syncRepository;
  final ScheduleSyncResultService syncResultService;

  bool _running = false;

  bool get isRunning => _running;

  /// 尝试进入互斥区。返回 true 表示当前任务获得了独占执行权；调用方完成
  /// 工作后必须调用 [release]。如果返回 false，说明已有同步在进行，调用方
  /// 应该早返回 / 跳过本次。
  bool tryAcquire() {
    if (_running) return false;
    _running = true;
    return true;
  }

  void release() {
    _running = false;
  }
}
