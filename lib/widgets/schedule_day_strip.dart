import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hai_schedule/services/theme_provider.dart';
import 'package:hai_schedule/utils/constants.dart';

class ScheduleDayStrip extends StatelessWidget {
  const ScheduleDayStrip({
    super.key,
    required this.displayDays,
    required this.dateForWeekday,
    this.highlightedWeekday,
    this.onWeekdaySelected,
    this.surfaceKey,
    this.dayKeyPrefix,
    this.leadingWidth = 40,
    this.height = 60,
    this.borderRadius = const BorderRadius.all(Radius.circular(15)),
  });

  final int displayDays;
  final DateTime Function(int weekday) dateForWeekday;
  final int? highlightedWeekday;
  final ValueChanged<int>? onWeekdaySelected;
  final Key? surfaceKey;
  final String? dayKeyPrefix;
  final double leadingWidth;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.read<ThemeProvider>();
    final isLightTheme = theme.brightness == Brightness.light;
    final primaryTextColor =
        isLightTheme ? theme.colorScheme.onSurface : Colors.white;
    final secondaryTextColor =
        isLightTheme
            ? theme.colorScheme.onSurface.withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.84);
    // 浅色模式下，glassPanelFill / Strong 在没有自定义背景时退化为接近白色的
    // cardColor，与上方着色卡片视觉脱节，所以这里在浅色模式下额外叠一层
    // primary tint，让日期条与全局主题色保持呼应；深色模式仍走原来的玻璃面。
    final basePanelTop = themeProvider.glassPanelStrongFill(
      theme.brightness,
      strength: 0.76,
    );
    final basePanelBottom = themeProvider.glassPanelFill(
      theme.brightness,
      strength: 0.66,
    );
    final fillTop =
        isLightTheme
            ? Color.alphaBlend(
              theme.colorScheme.primary.withValues(alpha: 0.10),
              basePanelTop,
            )
            : basePanelTop;
    final fillBottom =
        isLightTheme
            ? Color.alphaBlend(
              theme.colorScheme.primary.withValues(alpha: 0.06),
              basePanelBottom,
            )
            : basePanelBottom;

    return DecoratedBox(
      key: surfaceKey,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [fillTop, fillBottom],
        ),
        borderRadius: borderRadius,
        border: Border.all(
          color:
              isLightTheme
                  ? theme.colorScheme.primary.withValues(alpha: 0.18)
                  : themeProvider.glassOutline(
                    theme.brightness,
                    strength: 0.82,
                  ),
        ),
      ),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            SizedBox(
              width: leadingWidth,
              child: Center(
                child: Text(
                  '${dateForWeekday(1).month}\n月',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: primaryTextColor,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            ...List.generate(displayDays, (i) {
              final weekday = i + 1;
              final date = dateForWeekday(weekday);
              final isHighlighted = weekday == highlightedWeekday;
              final dayCell = Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                child: Center(
                  child: Container(
                    key:
                        dayKeyPrefix == null
                            ? null
                            : ValueKey('$dayKeyPrefix.$weekday'),
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration:
                        isHighlighted
                            ? BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha:
                                    theme.brightness == Brightness.dark
                                        ? 0.18
                                        : 0.10,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(
                                  alpha:
                                      theme.brightness == Brightness.dark
                                          ? 0.08
                                          : 0.16,
                                ),
                              ),
                            )
                            : null,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          WeekdayNames.getShort(weekday),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isHighlighted
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration:
                              isHighlighted
                                  ? BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        theme.colorScheme.primary.withValues(
                                          alpha: 0.92,
                                        ),
                                        theme.colorScheme.primary.withValues(
                                          alpha: 0.76,
                                        ),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  )
                                  : null,
                          child: Text(
                            '${date.day}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isHighlighted
                                      ? Colors.white
                                      : primaryTextColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              return Expanded(
                child:
                    onWeekdaySelected == null
                        ? dayCell
                        : Semantics(
                          button: true,
                          selected: isHighlighted,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onWeekdaySelected!(weekday),
                            child: dayCell,
                          ),
                        ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
