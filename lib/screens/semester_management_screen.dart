import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_repositories.dart';
import '../services/schedule_provider.dart';
import 'import_screen.dart';
import 'login_router.dart';

class SemesterManagementScreen extends StatelessWidget {
  const SemesterManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final codes = [...provider.availableSemesterCodes]..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('学期管理'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'semester_management_create',
        onPressed: () => _showCreateSemesterDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('新建学期'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _CurrentSemesterCard(currentSemesterCode: provider.currentSemesterCode),
          const SizedBox(height: 16),
          if (codes.isEmpty)
            const _EmptySemesterHint()
          else
            ...codes.map(
              (code) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SemesterCard(
                  semesterCode: code,
                  isCurrent: code == provider.currentSemesterCode,
                  canDelete: codes.length > 1,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showCreateSemesterDialog(BuildContext context) async {
    final provider = context.read<ScheduleProvider>();
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final created = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('新建学期'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: '学期代码',
                      hintText: '例如：20251 或 20252',
                      errorText: errorText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '先创建学期容器，再对这个学期执行登录同步或手动导入。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.68),
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
                    final value = controller.text.trim();
                    if (!_looksLikeSemesterCode(value)) {
                      setState(() => errorText = '请输入 5 位学期代码，例如 20251');
                      return;
                    }
                    Navigator.of(dialogContext).pop(value);
                  },
                  child: const Text('创建'),
                ),
              ],
            );
          },
        );
      },
    );

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
        content: Text('已创建并切换到 ${_formatSemesterCode(created)}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _CurrentSemesterCard extends StatelessWidget {
  const _CurrentSemesterCard({required this.currentSemesterCode});

  final String? currentSemesterCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.school_rounded, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentSemesterCode == null
                        ? '当前还没有激活学期'
                        : _formatSemesterCode(currentSemesterCode!),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '在这里统一管理学期容器，并直接对指定学期进行同步或导入。',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SemesterCard extends StatelessWidget {
  const _SemesterCard({
    required this.semesterCode,
    required this.isCurrent,
    required this.canDelete,
  });

  final String semesterCode;
  final bool isCurrent;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ScheduleProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _formatSemesterCode(semesterCode),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '当前',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        semesterCode,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
                        ),
                      ),
                    ],
                  ),
                ),
                if (canDelete)
                  IconButton(
                    tooltip: '删除学期',
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) {
                              return AlertDialog(
                                title: const Text('删除学期'),
                                content: Text(
                                  '确认删除 ${_formatSemesterCode(semesterCode)} 吗？\n\n这会同时删除该学期的课表缓存和临时安排。',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(true),
                                    child: const Text('删除'),
                                  ),
                                ],
                              );
                            },
                          ) ??
                          false;
                      if (!confirmed) return;

                      await provider.deleteSemester(semesterCode);
                      if (!context.mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('已删除 ${_formatSemesterCode(semesterCode)}'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: theme.colorScheme.error.withValues(alpha: 0.82),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            FutureBuilder<ScheduleCache>(
              future: ScheduleRepository().loadCache(semesterCode: semesterCode),
              builder: (context, snapshot) {
                final count = snapshot.data?.courses.length;
                final hasData = count != null && count > 0;
                return Text(
                  hasData ? '已缓存 $count 门课程' : '空学期，尚未导入或同步课表',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.70),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!isCurrent)
                  OutlinedButton(
                    onPressed: () async {
                      await provider.switchSemester(semesterCode);
                      if (!context.mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('已切换到 ${_formatSemesterCode(semesterCode)}'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: const Text('切换'),
                  ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LoginRouter(initialSemesterCode: semesterCode),
                      ),
                    );
                  },
                  icon: const Icon(Icons.cloud_sync_outlined, size: 18),
                  label: const Text('同步该学期'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ImportScreen(initialSemesterCode: semesterCode),
                      ),
                    );
                  },
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: const Text('导入到该学期'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySemesterHint extends StatelessWidget {
  const _EmptySemesterHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          '当前还没有学期容器。你可以先新建一个学期，再对该学期执行登录同步或手动导入。',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
          ),
        ),
      ),
    );
  }
}

bool _looksLikeSemesterCode(String value) {
  return RegExp(r'^\d{4}[12]$').hasMatch(value);
}

String _formatSemesterCode(String code) {
  if (!_looksLikeSemesterCode(code)) return code;
  final startYear = int.parse(code.substring(0, 4));
  final endYear = startYear + 1;
  final term = code.endsWith('1') ? '第一学期' : '第二学期';
  return '$startYear-$endYear $term';
}
