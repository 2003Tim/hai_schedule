import 'package:flutter/material.dart';

class WeekSelector extends StatefulWidget {
  final int currentWeek;
  final int selectedWeek;
  final int totalWeeks;
  final ValueChanged<int> onWeekSelected;

  const WeekSelector({
    super.key,
    required this.currentWeek,
    required this.selectedWeek,
    required this.totalWeeks,
    required this.onWeekSelected,
  });

  @override
  State<WeekSelector> createState() => _WeekSelectorState();
}

class _WeekSelectorState extends State<WeekSelector> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  @override
  void didUpdateWidget(covariant WeekSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedWeek != widget.selectedWeek) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    final offset = (widget.selectedWeek - 1) * 50.0 - 100;
    _scrollController.animateTo(
      offset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 52,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: widget.totalWeeks,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemBuilder: (context, index) {
          final week = index + 1;
          final isSelected = week == widget.selectedWeek;
          final isCurrent = week == widget.currentWeek;

          return GestureDetector(
            onTap: () => widget.onWeekSelected(week),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                gradient:
                    isSelected
                        ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            cs.primary.withValues(alpha: isDark ? 0.92 : 0.84),
                            cs.primary.withValues(alpha: isDark ? 0.74 : 0.70),
                          ],
                        )
                        : null,
                color:
                    !isSelected
                        ? (isCurrent
                            ? cs.primary.withValues(alpha: isDark ? 0.18 : 0.10)
                            : Colors.white.withValues(
                              alpha: isDark ? 0.06 : 0.14,
                            ))
                        : null,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      isSelected
                          ? Colors.white.withValues(alpha: isDark ? 0.12 : 0.22)
                          : isCurrent
                          ? cs.primary.withValues(alpha: 0.24)
                          : cs.outlineVariant.withValues(
                            alpha: isDark ? 0.10 : 0.06,
                          ),
                  width: isSelected ? 0.9 : 1.0,
                ),
                boxShadow:
                    isSelected
                        ? [
                          BoxShadow(
                            color: cs.primary.withValues(
                              alpha: isDark ? 0.18 : 0.16,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                        : null,
              ),
              alignment: Alignment.center,
              child: SizedBox(
                key: ValueKey('weekSelector.item.$week'),
                width: 44,
                child: Center(
                  child: Text(
                    '$week',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected || isCurrent
                              ? FontWeight.w700
                              : FontWeight.w500,
                      color:
                          isSelected
                              ? Colors.white
                              : isCurrent
                              ? cs.primary
                              : theme.textTheme.bodyMedium?.color?.withValues(
                                alpha: isDark ? 0.72 : 0.56,
                              ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
