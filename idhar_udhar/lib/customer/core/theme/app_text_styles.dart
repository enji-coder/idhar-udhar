import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Poppins-based text styles matching reference hierarchy.
abstract final class AppTextStyles {
  static TextStyle _poppins({
    required double size,
    required FontWeight weight,
    Color color = AppColors.textPrimary,
    double height = 1.3,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle get headingXL => _poppins(
        size: 30,
        weight: FontWeight.w700,
        height: 1.2,
      );

  static TextStyle get headingL => _poppins(
        size: 24,
        weight: FontWeight.w700,
        height: 1.25,
      );

  static TextStyle get headingM => _poppins(
        size: 20,
        weight: FontWeight.w600,
        height: 1.3,
      );

  static TextStyle get headingS => _poppins(
        size: 16,
        weight: FontWeight.w600,
        height: 1.35,
      );

  static TextStyle get body => _poppins(
        size: 14,
        weight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.5,
      );

  static TextStyle get bodyMedium => _poppins(
        size: 14,
        weight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.45,
      );

  static TextStyle get bodyLarge => _poppins(
        size: 15,
        weight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.5,
      );

  static TextStyle get caption => _poppins(
        size: 12,
        weight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  static TextStyle get label => _poppins(
        size: 13,
        weight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.3,
      );

  static TextStyle get button => _poppins(
        size: 16,
        weight: FontWeight.w600,
        color: AppColors.textInverse,
        height: 1.2,
        letterSpacing: 0.2,
      );

  static TextStyle get buttonSecondary => _poppins(
        size: 15,
        weight: FontWeight.w600,
        color: AppColors.navyDeep,
        height: 1.2,
      );

  static TextStyle get otp => _poppins(
        size: 22,
        weight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.1,
      );

  static TextStyle get wordmarkOrange => _poppins(
        size: 18,
        weight: FontWeight.w800,
        color: AppColors.orange,
        letterSpacing: 1.2,
        height: 1.1,
      );

  static TextStyle get wordmarkNavy => _poppins(
        size: 18,
        weight: FontWeight.w800,
        color: AppColors.navy,
        letterSpacing: 1.2,
        height: 1.1,
      );

  static TextStyle get tagline => _poppins(
        size: 12,
        weight: FontWeight.w400,
        color: AppColors.navy,
        letterSpacing: 0.4,
        height: 1.3,
      );

  /// Mixed navy + orange headline span helper.
  static TextSpan mixedHeadline({
    required String navyPart,
    required String orangePart,
    TextStyle? base,
    bool orangeFirst = false,
  }) {
    final TextStyle style = base ?? headingL;
    if (orangeFirst) {
      return TextSpan(
        children: [
          TextSpan(
            text: orangePart,
            style: style.copyWith(color: AppColors.orange),
          ),
          TextSpan(
            text: navyPart,
            style: style.copyWith(color: AppColors.navyDeep),
          ),
        ],
      );
    }
    return TextSpan(
      children: [
        TextSpan(
          text: navyPart,
          style: style.copyWith(color: AppColors.navyDeep),
        ),
        TextSpan(
          text: orangePart,
          style: style.copyWith(color: AppColors.orange),
        ),
      ],
    );
  }
}
