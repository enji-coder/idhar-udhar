import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_text_styles.dart';

/// Material 3 theme mapped to IDHAR UDHAR brand tokens.
abstract final class AppTheme {
  static ThemeData get light {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.orange,
      primary: AppColors.orange,
      onPrimary: AppColors.white,
      secondary: AppColors.navy,
      onSecondary: AppColors.white,
      surface: AppColors.warmWhite,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
      brightness: Brightness.light,
    );

    final TextTheme textTheme = TextTheme(
      displayLarge: AppTextStyles.headingXL,
      displayMedium: AppTextStyles.headingL,
      displaySmall: AppTextStyles.headingM,
      headlineMedium: AppTextStyles.headingM,
      headlineSmall: AppTextStyles.headingS,
      titleLarge: AppTextStyles.headingS,
      titleMedium: AppTextStyles.bodyMedium,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.body,
      bodySmall: AppTextStyles.caption,
      labelLarge: AppTextStyles.button,
      labelMedium: AppTextStyles.label,
      labelSmall: AppTextStyles.caption,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.cream,
      textTheme: GoogleFonts.poppinsTextTheme(textTheme),
      primaryColor: AppColors.orange,
      splashColor: AppColors.orange.withOpacity(0.12),
      highlightColor: AppColors.orange.withOpacity(0.08),
      dividerColor: AppColors.borderSubtle,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.navyDeep,
        titleTextStyle: AppTextStyles.headingS,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          foregroundColor: AppColors.white,
          backgroundColor: AppColors.orange,
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          textStyle: AppTextStyles.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.navyDeep,
          textStyle: AppTextStyles.buttonSecondary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glassFillLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.mdLgAll,
          borderSide: BorderSide(color: AppColors.borderGlass),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.mdLgAll,
          borderSide: BorderSide(color: AppColors.borderGlass),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.mdLgAll,
          borderSide: BorderSide(color: AppColors.orange, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.mdLgAll,
          borderSide: BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.mdLgAll,
          borderSide: BorderSide(color: AppColors.danger, width: 1.5),
        ),
        hintStyle: AppTextStyles.body,
        labelStyle: AppTextStyles.label,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return AppColors.orange;
          }
          return AppColors.white;
        }),
        checkColor: MaterialStateProperty.all(AppColors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.orange,
        linearTrackColor: AppColors.greyLight,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.navyDeep,
        contentTextStyle: AppTextStyles.body.copyWith(color: AppColors.white),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
    );
  }
}
