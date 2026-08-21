import 'package:flutter/material.dart';

/// Rider App — teal / mint Material 3 glass palette (theme reference).
abstract final class RiderColors {
  static const Color primary = Color(0xFF148BA6);
  static const Color primaryLight = Color(0xFF2DD4BF);
  static const Color secondary = Color(0xFF0D9488);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  static const Color background = Color(0xFFE6F4F1);
  static const Color surface = Color(0xFFF4FAF8);
  static const Color surfaceGlass = Color(0xCCFFFFFF);

  static const Color textPrimary = Color(0xFF0F3D3E);
  static const Color textSecondary = Color(0xFF5B7C7E);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color hint = Color(0xFF8AA8AA);
  static const Color border = Color(0xFFB7D9D4);
  static const Color offline = Color(0xFF94A3B8);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: <Color>[primary, secondary],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[primaryLight, primary],
  );

  static const LinearGradient splashBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0xFFE8F8F5),
      background,
      Color(0xFFD5EFEA),
    ],
  );
}
