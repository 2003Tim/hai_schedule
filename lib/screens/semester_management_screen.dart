import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/schedule_provider.dart';
import '../widgets/semester_management_sections.dart';
import 'import_screen.dart';
import 'login_router.dart';

class SemesterManagementScreen extends StatelessWidget {
  const SemesterManagementScreen({super.key});

  Future<void> _showCreateSemesterDialog(BuildContext context) async {
    final provider = context.read<ScheduleProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final created = await showCreateSemesterDialog(context);

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
  }) async {
    final provider = context.read<ScheduleProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmDeleteSemester(
      context,
      semesterCode: semesterCode,
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

  Future<void> _openManualImport(
    BuildContext context, {
    required String semesterCode,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImportScreen(initialSemesterCode: semesterCode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final codes = [...provider.availableSemesterCodes]
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: const Text('学期管理'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'semester_management_create',
        onPressed: () => _showCreateSemesterDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('新建学期'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          CurrentSemesterSummaryCard(
            currentSemesterCode: provider.currentSemesterCode,
          ),
          const SizedBox(height: 16),
          if (codes.isEmpty)
            const EmptySemesterHint()
          else
            ...codes.map(
              (code) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SemesterManagementCard(
                  semesterCode: code,
                  isCurrent: code == provider.currentSemesterCode,
                  canDelete: codes.length > 1,
                  onDelete: () => _deleteSemester(context, semesterCode: code),
                  onSwitch: () => _switchSemester(context, semesterCode: code),
                  onLoginFetch:
                      () => _openLoginFetch(context, semesterCode: code),
                  onManualImport:
                      () => _openManualImport(context, semesterCode: code),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
