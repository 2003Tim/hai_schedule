import 'package:flutter/material.dart';

class SwipeableDailyScheduleView extends StatefulWidget {
  final int totalDays;
  final int currentDay;
  final ValueChanged<int> onDayChanged;
  final Widget Function(int weekday) dayBuilder;

  const SwipeableDailyScheduleView({
    super.key,
    required this.totalDays,
    required this.currentDay,
    required this.onDayChanged,
    required this.dayBuilder,
  });

  @override
  State<SwipeableDailyScheduleView> createState() => _SwipeableDailyScheduleViewState();
}

class _SwipeableDailyScheduleViewState extends State<SwipeableDailyScheduleView> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.currentDay - 1);
  }

  @override
  void didUpdateWidget(covariant SwipeableDailyScheduleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetPage = widget.currentDay - 1;
    if (widget.currentDay != oldWidget.currentDay &&
        _pageController.hasClients &&
        (_pageController.page?.round() ?? 0) != targetPage) {
      _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.totalDays,
      onPageChanged: (index) => widget.onDayChanged(index + 1),
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: widget.dayBuilder(index + 1),
        );
      },
    );
  }
}
