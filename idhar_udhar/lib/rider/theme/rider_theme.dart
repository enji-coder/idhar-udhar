import 'package:flutter/material.dart';

import 'rider_colors.dart';
import 'rider_spacing.dart';
import 'rider_text_styles.dart';

/// Rider Material theme — isolated from Customer [AppTheme].
abstract final class RiderTheme {
  static ThemeData get light {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: RiderColors.primary,
      primary: RiderColors.primary,
      secondary: RiderColors.secondary,
      surface: RiderColors.surface,
      error: RiderColors.error,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: RiderColors.background,
      textTheme: TextTheme(
        displaySmall: RiderTextStyles.display,
        headlineMedium: RiderTextStyles.heading,
        titleLarge: RiderTextStyles.title,
        bodyMedium: RiderTextStyles.body,
        bodyLarge: RiderTextStyles.bodyMedium,
        labelLarge: RiderTextStyles.button,
        bodySmall: RiderTextStyles.caption,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: RiderColors.textPrimary,
        titleTextStyle: RiderTextStyles.title,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RiderColors.surfaceGlass,
        hintStyle: RiderTextStyles.hint,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: RiderSpacing.lg,
          vertical: RiderSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: RiderRadius.lgAll,
          borderSide: const BorderSide(color: RiderColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: RiderRadius.lgAll,
          borderSide: const BorderSide(color: RiderColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: RiderRadius.lgAll,
          borderSide: const BorderSide(color: RiderColors.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RiderColors.primary,
          foregroundColor: RiderColors.textOnPrimary,
          minimumSize: const Size.fromHeight(RiderSpacing.buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: RiderRadius.pillAll),
          textStyle: RiderTextStyles.button,
          elevation: 0,
        ),
      ),
    );
  }
}
