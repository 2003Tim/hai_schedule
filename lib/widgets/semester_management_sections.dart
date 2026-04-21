import 'package:flutter/material.dart';

import 'package:hai_schedule/models/semester_option.dart';
import 'package:hai_schedule/services/app_repositories.dart';
import 'package:hai_schedule/utils/semester_code_formatter.dart'
    as semester_formatter;

enum NewSemesterDialogAction { cancel, create, goToSync }

class NewSemesterDialogResult {
  final NewSemesterDialogAction action;
  final String? semesterCode;

  const NewSemesterDialogResult({required this.action, this.semesterCode});
}

Future<NewSemesterDialogResult> showCreateSemesterDialog(
  BuildContext context, {
  required List<SemesterOption> semesterCatalog,
  required Set<String> existingCodes,
}) async {
  return await showDialog<NewSemesterDialogResult>(
        context: context,
        builder:
            (_) => NewSemesterDialog(
              semesterCatalog: semesterCatalog,
              existingCodes: existingCodes,
            ),
      ) ??
      const NewSemesterDialogResult(action: NewSemesterDialogAction.cancel);
}

class NewSemesterDialog extends StatefulWidget {
  const NewSemesterDialog({
    super.key,
    required this.semesterCatalog,
    required this.existingCodes,
  });

  final List<SemesterOption> semesterCatalog;
  final Set<String> existingCodes;

  @override
  State<NewSemesterDialog> createState() => _NewSemesterDialogState();
}

class _NewSemesterDialogState extends State<NewSemesterDialog> {
  late final List<SemesterOption> _candidates =
      widget.semesterCatalog
          .where((item) => !widget.existingCodes.contains(item.normalizedCode))
          .toList()
        ..sort(
          (left, right) => right.normalizedCode.compareTo(left.normalizedCode),
        );

  String? _selectedCode;

  @override
  void initState() {
    super.initState();
    if (_candidates.isNotEmpty) {
      _selectedCode = _candidates.first.normalizedCode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCatalog = widget.semesterCatalog.isNotEmpty;
    final hasCandidates = _candidates.isNotEmpty;

    return AlertDialog(
      key: const ValueKey('semester_management.new_semester_dialog'),
      scrollable: true,
      title: const Text('新建学期'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasCandidates) ...[
            DropdownButtonFormField<String>(
              key: const ValueKey('semester_management.new_semester_dropdown'),
              initialValue: _selectedCode,
              decoration: const InputDecoration(labelText: '选择学期'),
              items:
                  _candidates
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.normalizedCode,
                          child: Text(_optionLabel(option)),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedCode = value);
              },
            ),
            const SizedBox(height: 12),
            Text(
              '学期列表来自教务系统目录。请选择一个尚未创建的合法学期。',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.70),
              ),
            ),
          ] else if (!hasCatalog) ...[
            Text(
              '请先同步课表以更新学期列表。',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '当前本地没有可用的学期目录。完成一次课表同步后，这里会自动出现教务系统返回的合法学期选项。',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.70),
              ),
            ),
          ] else ...[
            Text(
              '教务系统目录中的学期都已经创建过了。',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '如果学校开放了新学期，请先到“课表同步”刷新一次目录。',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.70),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(
              const NewSemesterDialogResult(
                action: NewSemesterDialogAction.cancel,
              ),
            );
          },
          child: const Text('取消'),
        ),
        if (hasCandidates)
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(
                NewSemesterDialogResult(
                  action: NewSemesterDialogAction.create,
                  semesterCode: _selectedCode,
                ),
              );
            },
            child: const Text('创建'),
          )
        else if (!hasCatalog)
          FilledButton.tonalIcon(
            key: const ValueKey('semester_management.go_to_sync'),
            onPressed: () {
              Navigator.of(context).pop(
                const NewSemesterDialogResult(
                  action: NewSemesterDialogAction.goToSync,
                ),
              );
            },
            icon: const Icon(Icons.sync_rounded, size: 18),
            label: const Text('前往同步课表'),
          )
        else
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(
                const NewSemesterDialogResult(
                  action: NewSemesterDialogAction.cancel,
                ),
              );
            },
            child: const Text('知道了'),
          ),
      ],
    );
  }
}

Future<bool> confirmDeleteSemester(
  BuildContext context, {
  required String semesterCode,
  required bool isLastSemester,
}) async {
  final title = isLastSemester ? '删除最后一个学期' : '删除学期';
  final message =
      isLastSemester
          ? '这是最后一个学期，删除后首页将无课表。确定吗？\n\n${formatSemesterCode(semesterCode)} 的课表缓存和临时安排也会一起删除。'
          : '确认删除 ${formatSemesterCode(semesterCode)} 吗？\n\n这会同时删除该学期的课表缓存和临时安排。';

  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(title),
            content: Text(message),
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
    required this.currentSemesterLabel,
  });

  final String? currentSemesterLabel;

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
                    currentSemesterLabel == null
                        ? '当前还没有激活学期'
                        : currentSemesterLabel!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '学期容器只允许从教务系统目录中选择创建，并在这里统一切换、同步和删除。',
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
    required this.semesterLabel,
    required this.isCurrent,
    required this.canDelete,
    required this.onDelete,
    required this.onSwitch,
    required this.onLoginFetch,
  });

  final String semesterCode;
  final String semesterLabel;
  final bool isCurrent;
  final bool canDelete;
  final Future<void> Function() onDelete;
  final Future<void> Function() onSwitch;
  final Future<void> Function() onLoginFetch;

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
                              semesterLabel,
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

class SemesterManagementEmptyState extends StatelessWidget {
  const SemesterManagementEmptyState({
    super.key,
    required this.onGoToSyncCenter,
  });

  final VoidCallback onGoToSyncCenter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('semester_management.empty_state'),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前无学期数据',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '你之前已经解锁过学期管理，所以入口会继续保留。现在首页没有课表，建议先去同步一次课表，重新获取教务系统中的学期与课程数据。',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onGoToSyncCenter,
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: const Text('前往同步课表'),
            ),
          ],
        ),
      ),
    );
  }
}

class SemesterManagementLockedState extends StatelessWidget {
  const SemesterManagementLockedState({
    super.key,
    required this.onGoToSyncCenter,
  });

  final VoidCallback onGoToSyncCenter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('semester_management.locked_state'),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '完成一次课表同步后可管理学期',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '学期目录的权威来源是教务系统。请先同步一次课表，系统会自动保存可用学期目录，然后你再回来选择需要创建的学期。',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onGoToSyncCenter,
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: const Text('前往同步课表'),
            ),
          ],
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

String _optionLabel(SemesterOption option) {
  return option.normalizedName.isNotEmpty
      ? option.normalizedName
      : formatSemesterCode(option.code);
}
