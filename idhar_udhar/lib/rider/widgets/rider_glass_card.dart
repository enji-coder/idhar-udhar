import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/rider_colors.dart';
import '../theme/rider_spacing.dart';

/// Glass surface card matching Rider theme reference.
class RiderGlassCard extends StatelessWidget {
  const RiderGlassCard({
    required this.child,
    super.key,
    this.padding,
    this.borderRadius,
    this.elevation = 0,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  /// Material elevation. `0` keeps the existing soft glass shadow.
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = borderRadius ?? RiderRadius.xlAll;
    final Widget card = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: RiderColors.surfaceGlass,
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.65),
            ),
            boxShadow: elevation > 0
                ? null
                : [
                    BoxShadow(
                      color: RiderColors.primary.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(RiderSpacing.xl),
            child: child,
          ),
        ),
      ),
    );

    if (elevation <= 0) return card;

    return Material(
      color: Colors.transparent,
      elevation: elevation,
      shadowColor: RiderColors.primary.withValues(alpha: 0.28),
      borderRadius: radius,
      child: card,
    );
  }
}
