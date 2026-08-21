import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Lightweight layout helpers for phones and tablets.
abstract final class Responsive {
  static const double tabletBreakpoint = 600;
  static const double contentMaxWidth = 480;

  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= tabletBreakpoint;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.orientationOf(context) == Orientation.landscape;
  }

  static double horizontalPadding(BuildContext context) {
    return isTablet(context) ? AppSpacing.xxxl : AppSpacing.screenHorizontal;
  }

  static EdgeInsets screenPadding(BuildContext context) {
    final double horizontal = horizontalPadding(context);
    return EdgeInsets.symmetric(
      horizontal: horizontal,
      vertical: isLandscape(context) ? AppSpacing.lg : AppSpacing.xxl,
    );
  }

  /// Centers content and caps width on large screens.
  static Widget constrain({
    required Widget child,
    double maxWidth = contentMaxWidth,
  }) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
