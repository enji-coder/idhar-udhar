import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Brand loading indicator — capsule progress bar and/or spinner.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    this.progress,
    this.label = 'Loading...',
    this.showLabel = true,
    this.style = LoadingIndicatorStyle.bar,
    this.width = 180,
    this.color = AppColors.orange,
    this.trackColor = AppColors.greyLight,
  });

  /// `null` = indeterminate when style supports it.
  final double? progress;
  final String label;
  final bool showLabel;
  final LoadingIndicatorStyle style;
  final double width;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case LoadingIndicatorStyle.circular:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                value: progress,
                color: color,
                backgroundColor: trackColor,
              ),
            ),
            if (showLabel) ...[
              const SizedBox(height: AppSpacing.md),
              Text(label, style: AppTextStyles.caption),
            ],
          ],
        );
      case LoadingIndicatorStyle.bar:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: width,
              height: 8,
              child: ClipRRect(
                borderRadius: AppRadius.pillAll,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  color: color,
                  backgroundColor: trackColor,
                ),
              ),
            ),
            if (showLabel) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(label, style: AppTextStyles.caption),
            ],
          ],
        );
    }
  }
}

enum LoadingIndicatorStyle {
  bar,
  circular,
}
