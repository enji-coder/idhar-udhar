import 'package:flutter/material.dart';

import 'package:idhar_udhar/customer/core/theme/app_spacing.dart';
import 'package:idhar_udhar/customer/core/widgets/loading_indicator.dart';

/// Shared loading indicator (bar or circular).
///
/// Delegates to core [LoadingIndicator].
class LoadingWidget extends StatelessWidget {
  const LoadingWidget({
    super.key,
    this.progress,
    this.label = 'Loading...',
    this.showLabel = true,
    this.style = LoadingIndicatorStyle.circular,
    this.width = 180,
  });

  /// Full-screen centered loader.
  const LoadingWidget.fullScreen({
    super.key,
    this.label = 'Loading...',
  })  : progress = null,
        showLabel = true,
        style = LoadingIndicatorStyle.circular,
        width = 180;

  final double? progress;
  final String label;
  final bool showLabel;
  final LoadingIndicatorStyle style;
  final double width;

  @override
  Widget build(BuildContext context) {
    final Widget indicator = LoadingIndicator(
      progress: progress,
      label: label,
      showLabel: showLabel,
      style: style,
      width: width,
    );

    if (style == LoadingIndicatorStyle.circular && showLabel) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: indicator,
        ),
      );
    }
    return indicator;
  }
}
