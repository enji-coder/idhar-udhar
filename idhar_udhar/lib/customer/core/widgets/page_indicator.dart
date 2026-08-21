import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Onboarding / auth page dots — active orange and larger.
class PageIndicator extends StatelessWidget {
  const PageIndicator({
    required this.count,
    required this.index,
    super.key,
    this.activeColor = AppColors.orange,
    this.inactiveColor = AppColors.indicatorInactive,
    this.activeWidth = 22,
    this.dotSize = 8,
    this.spacing = AppSpacing.sm,
  });

  final int count;
  final int index;
  final Color activeColor;
  final Color inactiveColor;
  final double activeWidth;
  final double dotSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(count, (i) {
        final bool active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          margin: EdgeInsets.symmetric(horizontal: spacing / 2),
          width: active ? activeWidth : dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: active ? activeColor : inactiveColor,
            borderRadius: AppRadius.pillAll,
          ),
        );
      }),
    );
  }
}
