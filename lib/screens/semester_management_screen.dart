import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hai_schedule/models/semester_option.dart';
import 'package:hai_schedule/screens/login_router.dart';
import 'package:hai_schedule/screens/sync_center_screen.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/widgets/semester_management_sections.dart';

class SemesterManagementScreen extends StatelessWidget {
  const SemesterManagementScreen({super.key});

  Future<void> _showCreateSemesterDialog(BuildContext context) async {
    final provider = context.read<ScheduleProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await showCreateSemesterDialog(
      context,
      semesterCatalog: provider.knownSemesterCatalog,
      existingCodes: provider.availableSemesterCodes.toSet(),
    );

    if (!context.mounted) return;
    switch (result.action) {
      case NewSemesterDialogAction.cancel:
        return;
      case NewSemesterDialogAction.goToSync:
        await _openSyncCenter(context);
        return;
      case NewSemesterDialogAction.create:
        final created = result.semesterCode;
        if (created == null || created.isEmpty) return;
        if (provider.availableSemesterCodes.contains(created)) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('该学期已存在'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        await provider.createSemester(created);
        if (!context.mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('已创建并切换到 ${formatSemesterCode(created)}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
    }
  }

  Future<void> _switchSemester(
    BuildContext context, {
    required String semesterCode,
  }) async {
    final provider = context.read<ScheduleProvider>();
    final messenger = ScaffoldMessenger.of(context);
    await provider.switchSemester(semesterCode);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('已切换到 ${formatSemesterCode(semesterCode)}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteSemester(
    BuildContext context, {
    required String semesterCode,
    required bool isLastSemester,
  }) async {
    final provider = context.read<ScheduleProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmDeleteSemester(
      context,
      semesterCode: semesterCode,
      isLastSemester: isLastSemester,
    );
    if (!confirmed) return;

    await provider.deleteSemester(semesterCode);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('已删除 ${formatSemesterCode(semesterCode)}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openLoginFetch(
    BuildContext context, {
    required String semesterCode,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginRouter(initialSemesterCode: semesterCode),
      ),
    );
  }

  Future<void> _openSyncCenter(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SyncCenterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final hasUnlockedEntry = provider.hasSyncedAtLeastOneSemester;
    final codes = [...provider.availableSemesterCodes]
      ..sort((a, b) => b.compareTo(a));
    final optionByCode = <String, SemesterOption>{
      for (final option in provider.availableSemesterOptions)
        option.normalizedCode: option,
    };

    String semesterLabel(String code) {
      final option = optionByCode[code];
      if (option != null && option.normalizedName.isNotEmpty) {
        return option.normalizedName;
      }
      return formatSemesterCode(code);
    }

    final hasCatalog = provider.knownSemesterCatalog.isNotEmpty;
    final canCreateSemester = hasUnlockedEntry && hasCatalog;

    return Scaffold(
      appBar: AppBar(title: const Text('学期管理'), centerTitle: true),
      floatingActionButton:
          hasUnlockedEntry
              ? FloatingActionButton.extended(
                heroTag: 'semester_management_create',
                onPressed: () => _showCreateSemesterDialog(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(canCreateSemester ? '新建学期' : '更新学期目录'),
              )
              : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          CurrentSemesterSummaryCard(
            currentSemesterLabel:
                provider.currentSemesterCode == null
                    ? null
                    : semesterLabel(provider.currentSemesterCode!),
          ),
          const SizedBox(height: 16),
          if (!hasUnlockedEntry)
            SemesterManagementLockedState(
              onGoToSyncCenter: () {
                _openSyncCenter(context);
              },
            )
          else if (codes.isEmpty)
            SemesterManagementEmptyState(
              onGoToSyncCenter: () {
                _openSyncCenter(context);
              },
            )
          else
            ...codes.map(
              (code) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SemesterManagementCard(
                  semesterCode: code,
                  semesterLabel: semesterLabel(code),
                  isCurrent: code == provider.currentSemesterCode,
                  canDelete: true,
                  onDelete:
                      () => _deleteSemester(
                        context,
                        semesterCode: code,
                        isLastSemester: codes.length == 1,
                      ),
                  onSwitch: () => _switchSemester(context, semesterCode: code),
                  onLoginFetch:
                      () => _openLoginFetch(context, semesterCode: code),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
