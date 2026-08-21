import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Gradient tokens aligned to the approved sunset glass reference.
abstract final class AppGradients {
  static const LinearGradient primaryCta = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      AppColors.orangeSoft,
      AppColors.orange,
      AppColors.orangeDeep,
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient primaryCtaSoft = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      AppColors.orangeSoft,
      AppColors.orange,
    ],
  );

  static const LinearGradient navyOrangeCta = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      AppColors.navy,
      AppColors.orange,
    ],
  );

  /// Attached-reference sunset sky (orange → peach → lavender).
  static const LinearGradient referenceSunset = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFC98A),
      Color(0xFFFFB08A),
      Color(0xFFFF9A7A),
      Color(0xFFE8B4C8),
      Color(0xFFC9B0DC),
    ],
    stops: [0.0, 0.22, 0.45, 0.72, 1.0],
  );

  static const LinearGradient sunsetBackground = referenceSunset;

  /// Warm auth canvas matching reference glass screens.
  static const LinearGradient authPremium = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFF1E4),
      Color(0xFFFFD8B8),
      Color(0xFFFFC4A0),
      Color(0xFFE8C4D8),
    ],
    stops: [0.0, 0.35, 0.7, 1.0],
  );

  /// Kept as alias for older call sites — maps to reference sunset.
  static const LinearGradient cinematicNavy = referenceSunset;

  static const LinearGradient warmCream = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.warmWhite,
      AppColors.cream,
      AppColors.softPeach,
    ],
  );

  static const LinearGradient peachGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFF0E6),
      AppColors.peach,
      Color(0xFFFFC4A8),
    ],
  );

  static const RadialGradient orangeAmbient = RadialGradient(
    center: Alignment.center,
    radius: 0.85,
    colors: [
      Color(0x66FF8A00),
      Color(0x00FF6A00),
    ],
  );

  static const RadialGradient navyAmbient = RadialGradient(
    center: Alignment.center,
    radius: 0.9,
    colors: [
      Color(0x55183B73),
      Color(0x00183B73),
    ],
  );

  static const RadialGradient sunsetRadial = RadialGradient(
    center: Alignment(0.0, -0.2),
    radius: 1.2,
    colors: [
      Color(0xFFFFE0C2),
      AppColors.softPeach,
      Color(0xFFDCC8F0),
    ],
  );

  /// Reference glass fill — translucent white (~25–40%), never opaque.
  static LinearGradient glassFill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.white.withValues(alpha: 0.38),
      AppColors.white.withValues(alpha: 0.22),
      AppColors.white.withValues(alpha: 0.28),
    ],
    stops: const [0.0, 0.55, 1.0],
  );

  static LinearGradient glassFillHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.white.withValues(alpha: 0.42),
      AppColors.white.withValues(alpha: 0.24),
      AppColors.white.withValues(alpha: 0.32),
    ],
    stops: const [0.0, 0.5, 1.0],
  );

  static LinearGradient glassFillDark = glassFill;

  static LinearGradient glassSheen = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.white.withValues(alpha: 0.42),
      AppColors.white.withValues(alpha: 0.06),
      AppColors.white.withValues(alpha: 0.0),
    ],
    stops: const [0.0, 0.35, 1.0],
  );

  static LinearGradient glassBorderSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.white.withValues(alpha: 0.65),
      AppColors.white.withValues(alpha: 0.22),
      AppColors.white.withValues(alpha: 0.4),
    ],
  );
}
