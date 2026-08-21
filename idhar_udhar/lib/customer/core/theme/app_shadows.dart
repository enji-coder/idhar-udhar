import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Soft, diffuse elevation — felt, not hard-edged.
abstract final class AppShadows {
  /// Level 1 — subtle resting surface.
  static List<BoxShadow> get soft => const [
        BoxShadow(
          color: Color(0x0A183B73),
          blurRadius: 12,
          offset: Offset(0, 4),
          spreadRadius: -2,
        ),
      ];

  /// Level 2 — normal floating glass.
  static List<BoxShadow> get floating => const [
        BoxShadow(
          color: Color(0x14183B73),
          blurRadius: 28,
          offset: Offset(0, 12),
          spreadRadius: -4,
        ),
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ];

  /// Level 3 — hero / premium card elevation.
  static List<BoxShadow> get glass => const [
        BoxShadow(
          color: Color(0x1F183B73),
          blurRadius: 40,
          offset: Offset(0, 18),
          spreadRadius: -6,
        ),
        BoxShadow(
          color: Color(0x0F183B73),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ];

  /// Floating bottom nav.
  static List<BoxShadow> get navFloat => const [
        BoxShadow(
          color: Color(0x24183B73),
          blurRadius: 32,
          offset: Offset(0, 14),
          spreadRadius: -4,
        ),
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get orangeGlow => [
        BoxShadow(
          color: AppColors.orange.withValues(alpha: 0.38),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: AppColors.orangeSoft.withValues(alpha: 0.22),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get orangeGlowPressed => [
        BoxShadow(
          color: AppColors.orange.withValues(alpha: 0.45),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get softWhiteGlow => [
        BoxShadow(
          color: AppColors.white.withValues(alpha: 0.45),
          blurRadius: 20,
          offset: Offset.zero,
          spreadRadius: 1,
        ),
      ];

  static List<BoxShadow> get inputFocus => [
        BoxShadow(
          color: AppColors.orange.withValues(alpha: 0.28),
          blurRadius: 18,
          offset: const Offset(0, 6),
          spreadRadius: -2,
        ),
        BoxShadow(
          color: AppColors.orange.withValues(alpha: 0.12),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get otpFocus => [
        BoxShadow(
          color: AppColors.orange.withValues(alpha: 0.4),
          blurRadius: 16,
          offset: Offset.zero,
          spreadRadius: 0,
        ),
      ];

  /// Soft contact shadow under floating 3D assets.
  static List<BoxShadow> get assetContact => [
        BoxShadow(
          color: AppColors.navy.withValues(alpha: 0.18),
          blurRadius: 22,
          offset: const Offset(0, 14),
          spreadRadius: -6,
        ),
        BoxShadow(
          color: AppColors.orange.withValues(alpha: 0.1),
          blurRadius: 28,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get selectedVehicle => [
        BoxShadow(
          color: AppColors.orange.withValues(alpha: 0.32),
          blurRadius: 26,
          offset: const Offset(0, 12),
          spreadRadius: -2,
        ),
        BoxShadow(
          color: AppColors.navy.withValues(alpha: 0.1),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> card({bool elevated = false}) {
    return elevated ? floating : soft;
  }

  static List<BoxShadow> cta({bool pressed = false}) {
    return pressed ? orangeGlowPressed : orangeGlow;
  }

  /// Outer float + subtle rim catch-light.
  static List<BoxShadow> get glassEdge => [
        BoxShadow(
          color: AppColors.white.withValues(alpha: 0.55),
          blurRadius: 1.5,
          offset: const Offset(0, 1),
        ),
        ...glass,
      ];

  static List<BoxShadow> forDepth(GlassDepthLevel level) {
    switch (level) {
      case GlassDepthLevel.subtle:
        return soft;
      case GlassDepthLevel.normal:
        return floating;
      case GlassDepthLevel.hero:
        return glassEdge;
    }
  }
}

/// Visual hierarchy for glass surfaces.
enum GlassDepthLevel {
  subtle,
  normal,
  hero,
}
