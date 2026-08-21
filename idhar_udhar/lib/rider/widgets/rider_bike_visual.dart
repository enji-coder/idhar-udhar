import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../assets/rider_assets.dart';

/// Existing splash vehicle — sized responsively by parent; asset unchanged.
class RiderBikeVisual extends StatelessWidget {
  const RiderBikeVisual({
    required this.appear,
    required this.yaw,
    required this.idle,
    super.key,
    this.width,
    this.height = 220,
  });

  /// 0 → 1 entrance (scale + fade + rise from below).
  final double appear;

  /// Subtle yaw radians after settle (keep small to avoid visual left bias).
  final double yaw;

  /// 0 → 1 idle phase for gentle float.
  final double idle;

  /// Optional max width (responsive). Aspect preserved via [BoxFit.contain].
  final double? width;

  final double height;

  @override
  Widget build(BuildContext context) {
    final double t = appear.clamp(0.0, 1.0);
    final double bob = math.sin(idle * math.pi * 2) * 3.0;
    final double rise = (1.0 - t) * 28.0;

    final Matrix4 transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0009)
      ..rotateY(yaw)
      ..rotateZ(math.sin(idle * math.pi * 2) * 0.01)
      ..translateByDouble(0.0, bob + rise, 0.0, 1.0);

    return Center(
      child: Opacity(
        opacity: Curves.easeOut.transform(t),
        child: Transform.scale(
          scale: 0.94 + (0.06 * t),
          alignment: Alignment.center,
          child: Transform(
            alignment: Alignment.center,
            transform: transform,
            child: Image.asset(
              RiderAssets.deliveryScooter,
              width: width,
              height: height,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}
