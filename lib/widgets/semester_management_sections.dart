import 'package:flutter/material.dart';

import 'package:hai_schedule/services/app_repositories.dart';
import 'package:hai_schedule/utils/semester_code_formatter.dart' as semester_formatter;

Future<String?> showCreateSemesterDialog(BuildContext context) async {
  final controller = TextEditingController();
  try {
    return await showDialog<String>(
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.68),
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
                    if (!looksLikeSemesterCode(value)) {
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
  } finally {
    controller.dispose();
  }
}

Future<bool> confirmDeleteSemester(
  BuildContext context, {
  required String semesterCode,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('删除学期'),
            content: Text(
              '确认删除 ${formatSemesterCode(semesterCode)} 吗？\n\n这会同时删除该学期的课表缓存和临时安排。',
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
}

class CurrentSemesterSummaryCard extends StatelessWidget {
  const CurrentSemesterSummaryCard({
    super.key,
    required this.currentSemesterCode,
  });

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
              child: Icon(
                Icons.school_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentSemesterCode == null
                        ? '当前还没有激活学期'
                        : formatSemesterCode(currentSemesterCode!),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '在这里统一管理学期容器，并直接对指定学期进行同步或导入。',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.68,
                      ),
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

class SemesterManagementCard extends StatelessWidget {
  const SemesterManagementCard({
    super.key,
    required this.semesterCode,
    required this.isCurrent,
    required this.canDelete,
    required this.onDelete,
    required this.onSwitch,
    required this.onLoginFetch,
    required this.onManualImport,
  });

  final String semesterCode;
  final bool isCurrent;
  final bool canDelete;
  final Future<void> Function() onDelete;
  final Future<void> Function() onSwitch;
  final Future<void> Function() onLoginFetch;
  final Future<void> Function() onManualImport;

  @override
  Widget build(BuildContext context) {
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
                              formatSemesterCode(semesterCode),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.10,
                                ),
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
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.64,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (canDelete)
                  IconButton(
                    tooltip: '删除学期',
                    onPressed: () async {
                      await onDelete();
                    },
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: theme.colorScheme.error.withValues(alpha: 0.82),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SemesterCacheSummary(semesterCode: semesterCode),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!isCurrent)
                  OutlinedButton(
                    onPressed: () async {
                      await onSwitch();
                    },
                    child: const Text('切换'),
                  ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await onLoginFetch();
                  },
                  icon: const Icon(Icons.cloud_sync_outlined, size: 18),
                  label: const Text('同步该学期'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await onManualImport();
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

class SemesterCacheSummary extends StatelessWidget {
  const SemesterCacheSummary({super.key, required this.semesterCode});

  final String semesterCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<ScheduleCache>(
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
    );
  }
}

class EmptySemesterHint extends StatelessWidget {
  const EmptySemesterHint({super.key});

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

bool looksLikeSemesterCode(String value) {
  return semester_formatter.looksLikeSemesterCode(value);
}

String formatSemesterCode(String code) =>
    semester_formatter.formatSemesterCode(code);
/*
  if (!looksLikeSemesterCode(code)) return code;
  final startYear = int.parse(code.substring(0, 4));
  final endYear = startYear + 1;
  final term = code.endsWith('1') ? '第一学期' : '第二学期';
  return '$startYear-$endYear $term';
}
*/
