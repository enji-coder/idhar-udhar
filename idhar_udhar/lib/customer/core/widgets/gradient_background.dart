import 'package:flutter/material.dart';

import '../theme/app_gradients.dart';

/// Gradient-only full-bleed background (cream / peach / sunset).
class GradientBackground extends StatelessWidget {
  const GradientBackground({
    required this.child,
    super.key,
    this.gradient = AppGradients.warmCream,
    this.safeArea = true,
  });

  factory GradientBackground.sunset({
    required Widget child,
    Key? key,
    bool safeArea = true,
  }) {
    return GradientBackground(
      key: key,
      gradient: AppGradients.sunsetBackground,
      safeArea: safeArea,
      child: child,
    );
  }

  factory GradientBackground.peach({
    required Widget child,
    Key? key,
    bool safeArea = true,
  }) {
    return GradientBackground(
      key: key,
      gradient: AppGradients.peachGlow,
      safeArea: safeArea,
      child: child,
    );
  }

  final Widget child;
  final Gradient gradient;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: SizedBox.expand(
        child: safeArea ? SafeArea(child: child) : child,
      ),
    );
  }
}
