import 'package:flutter/material.dart';

import '../theme/rider_colors.dart';

/// Soft mint gradient canvas for Rider screens.
class RiderBackground extends StatelessWidget {
  const RiderBackground({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RiderColors.splashBackground,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _blob(
              diameter: 220,
              color: RiderColors.primaryLight.withValues(alpha: 0.28),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -50,
            child: _blob(
              diameter: 180,
              color: RiderColors.primary.withValues(alpha: 0.18),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _blob({required double diameter, required Color color}) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
