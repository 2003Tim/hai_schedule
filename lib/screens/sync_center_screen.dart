import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hai_schedule/services/auth_credentials_service.dart';
import 'package:hai_schedule/services/auto_sync_service.dart';
import 'package:hai_schedule/services/portal_relogin_service.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/widgets/sync_center_sections.dart';
import 'package:hai_schedule/screens/import_screen.dart';
import 'package:hai_schedule/screens/login_router.dart';

class SyncCenterScreen extends StatefulWidget {
  const SyncCenterScreen({super.key});

  @override
  State<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends State<SyncCenterScreen> {
  static const List<int> _customIntervalPresetHours = <int>[6, 12, 24, 72, 168];

  AutoSyncSnapshot? _snapshot;
  SavedPortalCredential? _savedCredential;
  bool _isSyncing = false;
  DateTime? _lastManualSyncTime;
  static const _manualSyncCooldown = Duration(seconds: 30);

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

    final last = _lastManualSyncTime;
    if (last != null &&
        DateTime.now().difference(last) < _manualSyncCooldown) {
      final remaining =
          _manualSyncCooldown - DateTime.now().difference(last);
      _showSnack(
        '操作太频繁，请 ${remaining.inSeconds + 1} 秒后再试',
        error: true,
      );
      return;
    }
    _lastManualSyncTime = DateTime.now();

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
      final didRelogin = await PortalReloginService.tryRelogin(
        context,
        semesterCode: provider.currentSemesterCode,
      );
      if (didRelogin && mounted) {
        final snapshot = await AutoSyncService.loadSnapshot();
        result = AutoSyncResult.success(
          provider.courses.length,
          snapshot.message,
          snapshot,
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
            source == 'desktop_manual' ? '正在启动桌面同步流程...' : '正在启动桌面前台自动同步...',
      );
      await _refresh();
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => LoginRouter(
                initialSemesterCode: provider.currentSemesterCode,
              ),
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
    await AutoSyncService.handleCredentialCleared();
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
      final successText =
          frequency == AutoSyncFrequency.manual
              ? '已切换为仅手动同步'
              : frequency == AutoSyncFrequency.custom
              ? '已切换为每${AutoSyncService.formatIntervalMinutes(customIntervalMinutes!)}自动同步'
              : '已切换为${frequency.label}自动同步';
      _showSnack(successText);
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

  Future<int?> _pickCustomIntervalMinutes({required int initialMinutes}) async {
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
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.black87 : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
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

    final statusCard = SyncCenterStatusCard(
      snapshot: snapshot,
      savedCredential: _savedCredential,
      isSyncing: _isSyncing,
      isDesktop: isDesktop,
      statusColor: statusColor,
      onSyncNow: _isSyncing ? null : _syncNow,
      onOpenLoginPage: _openLoginPage,
      onOpenManualImport: isDesktop ? _openManualImport : null,
    );
    final credentialCard = SyncCenterCredentialCard(
      savedCredential: _savedCredential,
      onSwitchAccount: _switchAccount,
      onClearCredential: _clearSavedCredential,
    );
    final settingsCard = SyncCenterFrequencyCard(
      snapshot: snapshot,
      canEnableAutomatic: canEnableAutomatic,
      isDesktop: isDesktop,
      onChangeFrequency: (value) {
        if (value != null) {
          _changeFrequency(value);
        }
      },
      onEditCustomInterval: canEnableAutomatic ? _editCustomInterval : null,
    );
    final desktopCapabilityCard =
        isDesktop ? const SyncCenterDesktopCapabilityCard() : null;
    final descriptionCard = SyncCenterDescriptionCard(isDesktop: isDesktop);

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
                      child: SyncCenterSectionColumn(
                        sections: [credentialCard, descriptionCard],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SyncCenterSectionColumn(
                        sections: [
                          settingsCard,
                          if (desktopCapabilityCard != null)
                            desktopCapabilityCard,
                          const SyncCenterDesktopFlowCard(),
                        ],
                      ),
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
                  const SyncCenterDesktopFlowCard(),
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
