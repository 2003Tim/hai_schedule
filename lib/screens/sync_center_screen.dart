import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_credentials_service.dart';
import '../services/auto_sync_service.dart';
import '../services/portal_relogin_service.dart';
import '../services/schedule_provider.dart';
import '../services/theme_provider.dart';
import 'import_screen.dart';
import 'login_router.dart';

class SyncCenterScreen extends StatefulWidget {
  const SyncCenterScreen({super.key});

  @override
  State<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends State<SyncCenterScreen> {
  static const List<int> _customIntervalPresetHours = <int>[
    6,
    12,
    24,
    72,
    168,
  ];

  AutoSyncSnapshot? _snapshot;
  SavedPortalCredential? _savedCredential;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final snapshot = await AutoSyncService.loadSnapshot();
    final credential = await AuthCredentialsService.instance.load();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _savedCredential = credential;
    });
  }

  Future<void> _syncNow() async {
    if (_isSyncing) return;

    if (!Platform.isAndroid) {
      await _runDesktopForegroundSync(
        source: 'desktop_manual',
        showCompletionSnack: true,
      );
      return;
    }

    setState(() => _isSyncing = true);
    final provider = context.read<ScheduleProvider>();
    var result = await AutoSyncService.tryAutoSync(
      provider,
      force: true,
      source: 'manual',
    );

    if (result.requiresLogin) {
      if (!mounted) return;
      final didStartRelogin = await PortalReloginService.tryRelogin(
        context,
        semesterCode: provider.currentSemesterCode,
      );
      if (didStartRelogin && mounted) {
        result = await AutoSyncService.tryAutoSync(
          provider,
          force: true,
          source: 'manual_relogin',
        );
      }
    }

    await _refresh();
    if (!mounted) return;
    setState(() => _isSyncing = false);
    _showSnack(result.message, error: result.requiresLogin || !result.didSync);
  }

  Future<void> _runDesktopForegroundSync({
    required String source,
    required bool showCompletionSnack,
  }) async {
    if (_isSyncing) return;

    final provider = context.read<ScheduleProvider>();
    final beforeSnapshot = await AutoSyncService.loadSnapshot();
    if (!mounted) return;

    setState(() => _isSyncing = true);
    try {
      await AutoSyncService.recordDesktopForegroundSyncStart(
        source: source,
        message:
            source == 'desktop_manual'
                ? '正在启动桌面同步流程...'
                : '正在启动桌面前台自动同步...',
      );
      await _refresh();
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) =>
                  LoginRouter(initialSemesterCode: provider.currentSemesterCode),
        ),
      );

      var afterSnapshot = await AutoSyncService.loadSnapshot();
      final didUpdate =
          afterSnapshot.lastFetchTime != null &&
          (beforeSnapshot.lastFetchTime == null ||
              afterSnapshot.lastFetchTime!.isAfter(
                beforeSnapshot.lastFetchTime!,
              ));

      if (afterSnapshot.state == AutoSyncState.syncing && !didUpdate) {
        await AutoSyncService.recordDesktopForegroundSyncIncomplete(
          source: source,
          message: '桌面前台同步未完成，可稍后重试',
        );
        afterSnapshot = await AutoSyncService.loadSnapshot();
      }

      await _refresh();
      if (!mounted) return;

      if (showCompletionSnack) {
        _showSnack(
          afterSnapshot.message,
          error:
              afterSnapshot.state == AutoSyncState.failed ||
              afterSnapshot.state == AutoSyncState.loginRequired,
        );
      }
    } catch (e) {
      if (mounted && showCompletionSnack) {
        _showSnack('桌面同步流程启动失败: $e', error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _openLoginPage() async {
    final provider = context.read<ScheduleProvider>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                LoginRouter(initialSemesterCode: provider.currentSemesterCode),
      ),
    );
    await _refresh();
  }

  Future<void> _switchAccount() async {
    final provider = context.read<ScheduleProvider>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => LoginRouter(
              initialSemesterCode: provider.currentSemesterCode,
              openCredentialEditor: true,
            ),
      ),
    );
    await _refresh();
  }

  Future<void> _openManualImport() async {
    final provider = context.read<ScheduleProvider>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                ImportScreen(initialSemesterCode: provider.currentSemesterCode),
      ),
    );
    await _refresh();
  }

  Future<void> _clearSavedCredential() async {
    await AuthCredentialsService.instance.clear();
    if (!mounted) return;
    await _refresh();
    _showSnack('已清除保存的账号密码');
  }

  Future<void> _changeFrequency(AutoSyncFrequency frequency) async {
    try {
      int? customIntervalMinutes;
      if (frequency == AutoSyncFrequency.custom) {
        customIntervalMinutes = await _pickCustomIntervalMinutes(
          initialMinutes:
              _snapshot?.settings.customIntervalMinutes ??
              AutoSyncService.defaultCustomIntervalMinutes,
        );
        if (customIntervalMinutes == null) {
          await _refresh();
          return;
        }
      }

      await AutoSyncService.saveSettings(
        frequency,
        customIntervalMinutes: customIntervalMinutes,
      );
      await _refresh();
      if (!mounted) return;
      final successText = frequency == AutoSyncFrequency.manual
          ? '已切换为仅手动同步'
          : frequency == AutoSyncFrequency.custom
          ? '已切换为每${AutoSyncService.formatIntervalMinutes(customIntervalMinutes!)}自动同步'
          : '已切换为${frequency.label}自动同步';
      _showSnack(
        successText,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Bad state: ', ''), error: true);
      await _refresh();
    }
  }

  Future<void> _editCustomInterval() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;

    try {
      final customIntervalMinutes = await _pickCustomIntervalMinutes(
        initialMinutes: snapshot.settings.customIntervalMinutes,
      );
      if (customIntervalMinutes == null) {
        await _refresh();
        return;
      }

      await AutoSyncService.saveSettings(
        AutoSyncFrequency.custom,
        customIntervalMinutes: customIntervalMinutes,
      );
      await _refresh();
      if (!mounted) return;
      _showSnack(
        '已更新为每${AutoSyncService.formatIntervalMinutes(customIntervalMinutes)}自动同步',
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Bad state: ', ''), error: true);
      await _refresh();
    }
  }

  Future<int?> _pickCustomIntervalMinutes({
    required int initialMinutes,
  }) async {
    final initialHours = (initialMinutes / 60).round().clamp(1, 720);
    final controller = TextEditingController(text: '$initialHours');
    String? errorText;

    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('自定义同步间隔'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('请输入同步间隔，单位为小时。建议不要低于 6 小时。'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        _customIntervalPresetHours
                            .map(
                              (hours) => ChoiceChip(
                                label: Text('$hours 小时'),
                                selected: controller.text.trim() == '$hours',
                                onSelected: (_) {
                                  setState(() {
                                    controller.text = '$hours';
                                    errorText = null;
                                  });
                                },
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '间隔小时数',
                      suffixText: '小时',
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final hours = int.tryParse(controller.text.trim());
                    if (hours == null || hours < 1 || hours > 720) {
                      setState(() => errorText = '请输入 1 到 720 之间的整数小时');
                      return;
                    }
                    Navigator.of(dialogContext).pop(hours * 60);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  void _showSnack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.black87 : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _statusLabel(AutoSyncSnapshot snapshot) {
    if (_isSyncing || snapshot.state == AutoSyncState.syncing) return '同步中';
    switch (snapshot.state) {
      case AutoSyncState.success:
        return '已同步';
      case AutoSyncState.failed:
        return '失败';
      case AutoSyncState.loginRequired:
        return '需登录';
      case AutoSyncState.idle:
        return snapshot.settings.frequency == AutoSyncFrequency.manual
            ? '手动'
            : '待机';
      case AutoSyncState.syncing:
        return '同步中';
    }
  }

  Color _statusColor(BuildContext context, AutoSyncSnapshot snapshot) {
    final cs = Theme.of(context).colorScheme;
    if (_isSyncing || snapshot.state == AutoSyncState.syncing) {
      return cs.primary;
    }
    switch (snapshot.state) {
      case AutoSyncState.success:
        return Colors.green;
      case AutoSyncState.failed:
      case AutoSyncState.loginRequired:
        return Colors.orange;
      case AutoSyncState.idle:
      case AutoSyncState.syncing:
        return cs.primary;
    }
  }

  String _bodyText(AutoSyncSnapshot snapshot) {
    if (!Platform.isAndroid) {
      if (_isSyncing) {
        return '正在启动桌面前台同步流程，请稍候。';
      }
      if (!snapshot.credentialReady) {
        return 'Windows 端现在支持按频率执行前台自动同步。先完成一次“登录并刷新课表”，再保存账号密码，后续应用启动或回到前台时就能按设置自动检查。';
      }
      if (snapshot.settings.frequency == AutoSyncFrequency.manual) {
        return _savedCredential != null
            ? '当前桌面端处于仅手动同步模式。需要更新课表时，点“立即同步”即可自动打开登录页、填充账号并刷新课表。'
            : '当前桌面端处于仅手动同步模式。你可以随时点击“立即同步”手动登录并刷新课表。';
      }
      if (snapshot.requiresLogin) {
        return _savedCredential != null
            ? '当前桌面端保存的登录态可能已经失效，但你已经保存了账号密码。下次应用启动、回到前台或手动点“立即同步”时，系统会优先尝试自动填充并重新抓课。'
            : '当前桌面端保存的登录态可能已经失效。重新打开登录页并刷新一次课表，就能恢复前台自动同步能力。';
      }
      if (snapshot.state == AutoSyncState.success) {
        return _savedCredential != null
            ? '桌面前台自动同步已准备就绪。应用启动或回到前台时，会按你设置的频率自动检查；到点后会直接进入同步流程，并尽量自动填充、提交和抓取课表。'
            : '桌面前台自动同步已开启，但建议你保存账号密码，这样到点后的同步流程会更顺滑。';
      }
      if (snapshot.state == AutoSyncState.failed) {
        return snapshot.message;
      }
      return _savedCredential != null
          ? '桌面前台自动同步已开启。应用启动或回到前台时，会按你设置的频率自动检查；如果刚好到点，系统会直接拉起同步流程。'
          : '桌面前台自动同步已开启。建议你先保存账号密码，这样到点后系统就能自动填充登录页并继续抓课。';
    }

    if (_isSyncing || snapshot.state == AutoSyncState.syncing) {
      return '正在同步课表，请稍候。';
    }
    if (!snapshot.credentialReady) {
      return '后台自动同步需要先完成一次“登录并刷新课表”。登录成功后，系统会保存当前有效的登录态；如果同时保存了账号密码，下次打开 app 时也能更顺畅地自动续登。';
    }
    if (snapshot.requiresLogin) {
      if (_savedCredential != null) {
        return '之前保存的登录态快照已经失效，但当前已保存账号密码。下次打开 app 或手动同步时，系统会优先尝试自动续登；如果续登仍失败，再手动重新登录即可。';
      }
      return '之前保存的登录态快照已经失效。通常是 Cookie 过期或会话失效，重新执行一次“登录并刷新课表”即可恢复自动同步。';
    }
    if (snapshot.state == AutoSyncState.success) {
      return _savedCredential != null
          ? '自动同步已准备就绪，系统会按你设置的频率在后台检查课表更新；如登录态过期，下次打开 app 或手动同步时会优先尝试用已保存凭据自动续登。'
          : '自动同步已准备就绪，系统会按你设置的频率在后台检查课表更新。';
    }
    if (snapshot.state == AutoSyncState.failed) {
      return snapshot.message;
    }
    return snapshot.settings.frequency == AutoSyncFrequency.manual
        ? '当前为仅手动同步模式。你可以随时点击“立即同步”手动刷新。'
        : '自动同步已开启，系统会在下一次调度时间自动检查课表更新。';
  }

  String _frequencyHelpText(
    AutoSyncFrequency frequency, {
    int? customIntervalMinutes,
    bool isDesktop = false,
  }) {
    switch (frequency) {
      case AutoSyncFrequency.manual:
        return '只在你手动点击“立即同步”时更新';
      case AutoSyncFrequency.daily:
        return isDesktop ? '应用启动或回到前台时，按天频率自动检查' : '推荐默认选项，适合课表偶尔调整';
      case AutoSyncFrequency.weekly:
        return isDesktop ? '适合课表较稳定，只在桌面前台低频检查' : '适合课表比较稳定，只想低频更新';
      case AutoSyncFrequency.monthly:
        return isDesktop ? '检查频率最低，适合几乎不变的课表' : '最省电，但可能错过临时调课';
      case AutoSyncFrequency.custom:
        final minutes =
            customIntervalMinutes ??
            AutoSyncService.defaultCustomIntervalMinutes;
        return isDesktop
            ? '应用在前台运行、启动或恢复时，按 ${AutoSyncService.formatIntervalMinutes(minutes)} 检查一次'
            : '当前间隔 ${AutoSyncService.formatIntervalMinutes(minutes)}，可改成 1 到 720 小时';
    }
  }

  Widget _buildGlassCard({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(14, 14, 14, 14),
  }) {
    final themeProvider = context.watch<ThemeProvider>();
    final brightness = Theme.of(context).brightness;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                themeProvider.glassPanelStrongFill(brightness, strength: 0.70),
                themeProvider.glassPanelFill(brightness, strength: 0.62),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: themeProvider.glassOutline(brightness, strength: 0.76),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: brightness == Brightness.dark ? 0.12 : 0.04,
                ),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    AutoSyncSnapshot snapshot,
    Color statusColor,
    bool isDesktop,
  ) {
    return _buildGlassCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.sync_rounded,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '同步状态',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDesktop
                          ? 'Windows · ${AutoSyncService.describeSettings(snapshot.settings)}'
                          : AutoSyncService.describeSettings(snapshot.settings),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.16),
                  ),
                ),
                child: Text(
                  isDesktop
                      ? snapshot.credentialReady
                          ? _statusLabel(snapshot)
                          : '待登录'
                      : _statusLabel(snapshot),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (snapshot.lastDiffSummary != null &&
              snapshot.lastDiffSummary!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoChip(
              icon: Icons.compare_arrows_rounded,
              label: snapshot.lastDiffSummary!,
            ),
          ],
          if (isDesktop) ...[
            const SizedBox(height: 10),
            const _InfoChip(
              icon: Icons.desktop_windows_rounded,
              label: '桌面端支持前台自动同步、登录抓课和自动填充，不依赖系统级后台常驻',
            ),
          ],
          const SizedBox(height: 14),
          Text(
            _bodyText(snapshot),
            style: const TextStyle(fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.history_rounded,
                label:
                    '上次更新 ${AutoSyncService.formatDateTime(snapshot.lastFetchTime)}',
              ),
              _InfoChip(
                icon: Icons.schedule_rounded,
                label:
                    isDesktop
                        ? snapshot.settings.frequency == AutoSyncFrequency.manual
                            ? '当前仅手动同步'
                            : '下次前台 ${AutoSyncService.formatDateTime(snapshot.nextSyncTime)}'
                        : snapshot.settings.frequency ==
                            AutoSyncFrequency.manual
                        ? '当前仅手动同步'
                        : '下次后台 ${AutoSyncService.formatDateTime(snapshot.nextSyncTime)}',
              ),
              _InfoChip(
                icon:
                    snapshot.requiresLogin
                        ? Icons.error_outline_rounded
                        : snapshot.credentialReady
                        ? Icons.verified_user_rounded
                        : Icons.lock_outline_rounded,
                label:
                    snapshot.requiresLogin
                        ? _savedCredential != null
                            ? '登录态快照已过期，可自动续登'
                            : '登录态快照已过期'
                        : snapshot.credentialReady
                        ? _savedCredential != null
                            ? '已保存登录态与续登凭据'
                            : '已保存自动同步登录态快照'
                        : '需先登录并刷新一次',
              ),
            ],
          ),
          if (_isSyncing || snapshot.state == AutoSyncState.syncing) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: const LinearProgressIndicator(minHeight: 3),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _isSyncing ? null : _syncNow,
                icon:
                    _isSyncing
                        ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.sync_rounded, size: 18),
                label: Text(
                  _isSyncing
                      ? '同步中...'
                      : isDesktop
                      ? (_savedCredential != null
                          ? '使用已保存账号同步'
                          : '登录并刷新课表')
                      : '立即同步',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _openLoginPage,
                icon: const Icon(Icons.login_rounded, size: 18),
                label: Text(
                  isDesktop
                      ? (snapshot.requiresLogin ? '重新登录' : '打开登录页')
                      : (snapshot.requiresLogin
                          ? '重新登录并刷新'
                          : '登录并刷新课表'),
                ),
              ),
              if (isDesktop)
                OutlinedButton.icon(
                  onPressed: _openManualImport,
                  icon: const Icon(Icons.paste_rounded, size: 18),
                  label: const Text('手动导入'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialCard(BuildContext context) {
    return _buildGlassCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '登录凭据',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            _savedCredential == null
                ? '当前没有保存账号密码。保存后可自动填充登录页，也能在登录态失效后让桌面端恢复登录更顺畅。'
                : '当前账号：${_savedCredential!.maskedUsername}。已支持自动填充登录页、快捷切换账号，以及登录态失效后的前台自动续登。',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.70),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _switchAccount,
                icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                label: Text(_savedCredential == null ? '填写账号' : '切换账号'),
              ),
              if (_savedCredential != null)
                TextButton.icon(
                  onPressed: _clearSavedCredential,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('清除凭据'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyCard(
    BuildContext context,
    AutoSyncSnapshot snapshot,
    bool canEnableAutomatic,
    bool isDesktop,
  ) {
    return _buildGlassCard(
      context: context,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 6, 8, 2),
            child: Text(
              '自动同步频率',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Text(
              canEnableAutomatic
                  ? isDesktop
                      ? '桌面端会按你设置的频率，在应用启动或回到前台时自动检查。'
                      : '后台自动同步已经准备就绪，可以随时切换频率。'
                  : isDesktop
                  ? '要启用桌面前台自动同步，请先保存账号密码，并至少完成一次“登录并刷新课表”。'
                  : '要开启自动同步，请先点击上方“登录并刷新课表”保存一次有效登录态。',
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.66),
                height: 1.4,
              ),
            ),
          ),
          RadioGroup<AutoSyncFrequency>(
            groupValue: snapshot.settings.frequency,
            onChanged: (value) {
              if (value != null) {
                _changeFrequency(value);
              }
            },
            child: Column(
              children:
                  AutoSyncFrequency.values
                      .map(
                        (frequency) => RadioListTile<AutoSyncFrequency>(
                          value: frequency,
                          enabled:
                              frequency == AutoSyncFrequency.manual ||
                              canEnableAutomatic,
                          title: Text(
                            frequency == AutoSyncFrequency.manual
                                ? '仅手动同步'
                                : frequency == AutoSyncFrequency.custom
                                ? '自定义自动同步'
                                : '${frequency.label}自动同步',
                          ),
                          subtitle: Text(
                            _frequencyHelpText(
                              frequency,
                              customIntervalMinutes:
                                  snapshot.settings.customIntervalMinutes,
                              isDesktop: isDesktop,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          if (snapshot.settings.frequency == AutoSyncFrequency.custom) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '当前自定义间隔：${AutoSyncService.formatIntervalMinutes(snapshot.settings.customIntervalMinutes)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.70),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: canEnableAutomatic ? _editCustomInterval : null,
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('修改间隔'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                '保存后会按新的自定义间隔重新计算下一次自动同步时间。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.58),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopCapabilityCard(BuildContext context) {
    return _buildGlassCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Windows 端能力',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Windows 端现在补齐的是“前台自动同步”能力：应用启动或回到前台时，会按你设置的频率自动检查；如果刚好到点，就直接进入登录抓课流程。它不是系统级后台常驻任务，但日常使用会顺手很多。',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFlowCard(BuildContext context) {
    return _buildGlassCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '推荐使用流程',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _buildFlowStep(
            context,
            step: '1',
            text: '先保存账号密码，后续 Windows 登录页就能自动填充。',
          ),
          _buildFlowStep(
            context,
            step: '2',
            text: '执行一次“登录并刷新课表”，把当前学期和最新课表一起同步下来。',
          ),
          _buildFlowStep(
            context,
            step: '3',
            text: '启用自动同步频率后，Windows 会在应用启动或回到前台时自动检查是否到点。',
          ),
          _buildFlowStep(
            context,
            step: '4',
            text: '同步成功后，课前提醒、作息时间和临时安排会立刻复用这套最新课表数据。',
          ),
        ],
      ),
    );
  }

  Widget _buildFlowStep(
    BuildContext context, {
    required String step,
    required String text,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: scheme.onSurface.withValues(alpha: 0.74),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(BuildContext context, bool isDesktop) {
    return _buildGlassCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '说明',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            isDesktop
                ? 'Windows 版现在会复用同一套登录抓课链路和凭据管理逻辑，并支持按频率做“前台自动同步检查”。它不是系统级后台常驻任务，但只要应用启动或回到前台，就会按你的设置判断是否该同步。'
                : '当前版本的后台同步会优先复用本机保存的登录态快照自动拉取课表，不会上传账号密码。若登录态过期，后台调度本身会暂停更新；你下次打开 app 或手动同步时，若已启用“记住密码”，系统会优先尝试自动续登，只有续登失败时才需要重新“登录并刷新课表”。',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionColumn(List<Widget> sections, {double spacing = 12}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < sections.length; index++) ...[
          sections[index],
          if (index != sections.length - 1) SizedBox(height: spacing),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot =
        _snapshot ??
        const AutoSyncSnapshot(
          settings: AutoSyncSettings(
            frequency: AutoSyncFrequency.daily,
            customIntervalMinutes: AutoSyncService.defaultCustomIntervalMinutes,
          ),
          state: AutoSyncState.idle,
          message: '等待下一次同步',
        );
    final statusColor = _statusColor(context, snapshot);
    final canEnableAutomatic = snapshot.credentialReady;
    final isDesktop = !Platform.isAndroid;
    final isWideDesktop =
        isDesktop && MediaQuery.of(context).size.width >= 1180;

    final statusCard = _buildStatusCard(
      context,
      snapshot,
      statusColor,
      isDesktop,
    );
    final credentialCard = _buildCredentialCard(context);
    final settingsCard = _buildFrequencyCard(
      context,
      snapshot,
      canEnableAutomatic,
      isDesktop,
    );
    final desktopCapabilityCard =
        isDesktop ? _buildDesktopCapabilityCard(context) : null;
    final descriptionCard = _buildDescriptionCard(context, isDesktop);

    return Scaffold(
      appBar: AppBar(title: const Text('课表同步')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              statusCard,
              const SizedBox(height: 12),
              if (isWideDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildSectionColumn([
                        credentialCard,
                        descriptionCard,
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSectionColumn([
                        settingsCard,
                        if (desktopCapabilityCard != null) desktopCapabilityCard,
                        _buildDesktopFlowCard(context),
                      ]),
                    ),
                  ],
                )
              else ...[
                credentialCard,
                const SizedBox(height: 12),
                settingsCard,
                if (isDesktop) ...[
                  const SizedBox(height: 12),
                  if (desktopCapabilityCard != null) desktopCapabilityCard,
                  const SizedBox(height: 12),
                  _buildDesktopFlowCard(context),
                ],
                const SizedBox(height: 12),
                descriptionCard,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12.5)),
        ],
      ),
    );
  }
}
