import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hai_schedule/models/schedule_parser.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/utils/semester_code_formatter.dart';
import 'package:hai_schedule/widgets/adaptive_layout.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, this.initialSemesterCode});

  final String? initialSemesterCode;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _controller = TextEditingController();
  String? _errorMessage;
  int? _parsedCount;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _targetSemesterLabel => formatOptionalSemesterCode(
    widget.initialSemesterCode,
    emptyLabel: '当前学期',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导入课表')),
      body: SafeArea(
        child: AdaptivePage(
          maxWidth: 1180,
          child: SingleChildScrollView(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWideLayout =
                    constraints.maxWidth >= 960 &&
                    AdaptiveLayout.isTablet(context);

                if (!isWideLayout) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildGuideCard(context),
                      const SizedBox(height: 16),
                      _buildEditorCard(context),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 360, child: _buildGuideCard(context)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildEditorCard(context)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuideCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  '如何获取课表数据',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '导入目标：$_targetSemesterLabel',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            _stepItem('1', '登录教务系统并打开“我的课表”页面'),
            _stepItem('2', '按 F12 打开开发者工具，切到 Network'),
            _stepItem('3', '筛选 Fetch/XHR 并刷新页面'),
            _stepItem('4', '找到 xsjxrwcx.do 请求，复制 Response 内容'),
            _stepItem('5', '把 JSON 粘贴到右侧，再点击“确认导入”'),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '粘贴课表 JSON',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '支持直接预览解析结果，确认无误后导入到 $_targetSemesterLabel。',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(
                  alpha: 0.68,
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              maxLines: 14,
              minLines: 10,
              decoration: InputDecoration(
                hintText: '粘贴 API 返回的 JSON 数据...',
                border: const OutlineInputBorder(),
                errorText: _errorMessage,
                suffixIcon:
                    _controller.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _errorMessage = null;
                              _parsedCount = null;
                            });
                          },
                        )
                        : null,
              ),
              onChanged:
                  (_) => setState(() {
                    _errorMessage = null;
                    _parsedCount = null;
                  }),
            ),
            const SizedBox(height: 12),
            if (_parsedCount != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '成功解析 $_parsedCount 门课程',
                      style: const TextStyle(color: Colors.green),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _previewParse,
                    icon: const Icon(Icons.preview),
                    label: const Text('预览解析'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        _parsedCount != null && _parsedCount! > 0
                            ? _doImport
                            : null,
                    icon: const Icon(Icons.download),
                    label: const Text('确认导入'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  void _previewParse() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _errorMessage = '请粘贴 JSON 数据');
      return;
    }

    try {
      final data = json.decode(text) as Map<String, dynamic>;
      final courses = ScheduleParser.parseApiResponse(data);
      setState(() {
        if (courses.isEmpty) {
          _errorMessage = '未能解析出课程，请检查 JSON 格式';
          _parsedCount = null;
        } else {
          _errorMessage = null;
          _parsedCount = courses.length;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'JSON 格式错误: ${e.toString().split('\n').first}';
        _parsedCount = null;
      });
    }
  }

  Future<void> _doImport() async {
    final provider = context.read<ScheduleProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await provider.importFromJson(
        _controller.text.trim(),
        semesterCode: widget.initialSemesterCode,
      );
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text('成功导入 $_parsedCount 门课程到 $_targetSemesterLabel'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('导入失败: ${e.toString().split('\n').first}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
