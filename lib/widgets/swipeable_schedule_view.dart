import 'dart:async';

import 'package:flutter/material.dart';

class SwipeableScheduleView extends StatefulWidget {
  final Widget Function(int weekNumber) scheduleBuilder;
  final int totalWeeks;
  final int currentWeek;
  final ValueChanged<int> onWeekChanged;
  final bool showIndicator;

  const SwipeableScheduleView({
    super.key,
    required this.scheduleBuilder,
    required this.totalWeeks,
    required this.currentWeek,
    required this.onWeekChanged,
    this.showIndicator = true,
  });

  @override
  State<SwipeableScheduleView> createState() => _SwipeableScheduleViewState();
}

class _SwipeableScheduleViewState extends State<SwipeableScheduleView> {
  late final PageController _pageController;
  Timer? _indicatorTimer;
  int _displayedWeek = 1;
  bool _showingIndicator = false;

  @override
  void initState() {
    super.initState();
    _displayedWeek = widget.currentWeek;
    _pageController = PageController(
      initialPage: widget.currentWeek - 1,
      viewportFraction: 1.0,
    );
  }

  @override
  void didUpdateWidget(covariant SwipeableScheduleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentWeek != oldWidget.currentWeek) {
      final targetPage = widget.currentWeek - 1;
      if (_pageController.hasClients &&
          (_pageController.page?.round() ?? 0) != targetPage) {
        _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      _displayedWeek = widget.currentWeek;
    }
  }

  @override
  void dispose() {
    _indicatorTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _scheduleIndicatorDismiss() {
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showingIndicator = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.totalWeeks,
          allowImplicitScrolling: false,
          onPageChanged: (pageIndex) {
            final newWeek = pageIndex + 1;
            setState(() {
              _displayedWeek = newWeek;
              _showingIndicator = true;
            });
            widget.onWeekChanged(newWeek);
            _scheduleIndicatorDismiss();
          },
          itemBuilder: (context, index) {
            return RepaintBoundary(
              child: widget.scheduleBuilder(index + 1),
            );
          },
        ),
        if (widget.showIndicator && _showingIndicator)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: _showingIndicator ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '第$_displayedWeek周',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
