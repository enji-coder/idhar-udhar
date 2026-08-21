import 'package:flutter/material.dart';

import 'package:idhar_udhar/customer/core/theme/app_colors.dart';
import 'package:idhar_udhar/customer/core/theme/app_radius.dart';
import 'package:idhar_udhar/customer/core/theme/app_spacing.dart';
import 'package:idhar_udhar/customer/shared/theme/durations.dart';

/// Lightweight shimmer placeholder for list / card loading states.
class ShimmerWidget extends StatefulWidget {
  const ShimmerWidget({
    super.key,
    this.width,
    this.height = AppSpacing.xxxl,
    this.borderRadius,
  });

  /// Convenience: card-shaped shimmer block.
  factory ShimmerWidget.card({
    Key? key,
    double height = 120,
  }) {
    return ShimmerWidget(
      key: key,
      height: height,
      borderRadius: AppRadius.lgAll,
    );
  }

  /// Convenience: circular avatar shimmer.
  factory ShimmerWidget.circle({
    Key? key,
    double size = AppSpacing.massive,
  }) {
    return ShimmerWidget(
      key: key,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2),
    );
  }

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<ShimmerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.shimmer,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return _box(AppColors.greyLight);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return _box(null);
      },
    );
  }

  Widget _box(Color? solid) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius ?? AppRadius.mdAll,
        color: solid,
        gradient: solid == null
            ? LinearGradient(
                begin: Alignment(-1.0 - _controller.value * 2, 0),
                end: Alignment(1.0 - _controller.value * 2, 0),
                colors: const [
                  AppColors.greyLight,
                  AppColors.white,
                  AppColors.greyLight,
                ],
                stops: const [0.25, 0.5, 0.75],
              )
            : null,
      ),
    );
  }
}
