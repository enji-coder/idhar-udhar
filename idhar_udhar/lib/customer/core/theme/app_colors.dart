import 'package:flutter/material.dart';

/// IDHAR UDHAR brand and semantic color tokens.
///
/// Canonical brand hex (single source of truth for docs + UI):
/// - Orange `#FF6A00`
/// - Navy `#183B73`
/// Do not reintroduce legacy doc values `#FF6624` / `#2E4072`.
abstract final class AppColors {
  // Brand
  static const Color orange = Color(0xFFFF6A00);
  static const Color orangePressed = Color(0xFFE55F00);
  static const Color orangeSoft = Color(0xFFFF8A00);
  static const Color orangeDeep = Color(0xFFE85F00);
  static const Color orangeGlow = Color(0xFFFF8A00);

  static const Color navy = Color(0xFF183B73);
  static const Color navyDeep = Color(0xFF183B73);
  static const Color navyMuted = Color(0xFF294A8A);
  static const Color navySoft = Color(0xFF294A8A);

  // Surfaces
  static const Color warmWhite = Color(0xFFFFFBFA);
  static const Color cream = Color(0xFFFFF7F0);
  static const Color surfaceBrand = Color(0xFFFFF8F4);
  static const Color softPeach = Color(0xFFFFE4D4);
  static const Color peach = Color(0xFFFFD4BC);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // Text
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textInverse = white;
  static const Color textOrange = orange;
  static const Color textNavy = navy;

  // Borders
  static const Color borderSubtle = Color(0xFFE6EAF2);
  static const Color borderGlass = Color(0x66FFFFFF);
  static const Color borderGlassStrong = Color(0x73FFFFFF);
  static const Color borderFocus = orange;

  // Glass fills — translucent (never opaque white rectangles)
  static const Color glassFill = Color(0x66FFFFFF);
  static const Color glassFillLight = Color(0x4DFFFFFF);
  static const Color glassFillHeavy = Color(0x8CFFFFFF);
  static const Color glassFillSoft = Color(0x38FFFFFF);
  static const Color glassFillDark = Color(0x66183B73);
  static const Color glassFillDarkSoft = Color(0x40183B73);
  static const Color glassWarm = Color(0x59FFF7F0);
  static const Color glassNavyTint = Color(0x26183B73);

  // Semantic
  static const Color success = Color(0xFF22A06B);
  static const Color warning = Color(0xFFF5A524);
  static const Color danger = Color(0xFFE11D48);
  static const Color info = Color(0xFF3B82F6);

  // Neutrals
  static const Color greyLight = Color(0xFFF0F2F7);
  static const Color grey = Color(0xFFC5CAD6);
  static const Color greyDark = Color(0xFF8A93A8);
  static const Color indicatorInactive = Color(0xFFD9DEE8);

  // Overlay
  static const Color scrim = Color(0x66183B73);
  static const Color sunsetGold = Color(0xFFFFC98A);
  static const Color sunsetLavender = Color(0xFFD4C4F0);
  static const Color sunsetPink = Color(0xFFFFB8A0);
}
