import 'package:flutter/animation.dart';

/// Motion tokens — durations and curves for premium 60fps motion.
abstract final class AppMotion {
  static const Duration micro = Duration(milliseconds: 150);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration enter = Duration(milliseconds: 400);
  static const Duration page = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration float = Duration(milliseconds: 2400);
  static const Duration shimmer = Duration(milliseconds: 1200);

  static const Curve easeOut = Curves.easeOut;
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOutCubic = Curves.easeOutCubic;
  static const Curve spring = Curves.easeOutBack;
  static const Curve linear = Curves.linear;

  static const double pressScale = 0.98;
  static const double enterSlide = 24;
  static const double floatOffset = 8;
}
