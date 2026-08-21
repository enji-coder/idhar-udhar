import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'rider_colors.dart';

/// Rider typography — Poppins (theme reference).
abstract final class RiderTextStyles {
  static TextStyle get display => GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: RiderColors.textPrimary,
        height: 1.2,
      );

  static TextStyle get heading => GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: RiderColors.textPrimary,
        height: 1.25,
      );

  static TextStyle get title => GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: RiderColors.textPrimary,
        height: 1.3,
      );

  static TextStyle get body => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: RiderColors.textPrimary,
        height: 1.45,
      );

  static TextStyle get bodyMedium => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: RiderColors.textPrimary,
        height: 1.4,
      );

  static TextStyle get caption => GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: RiderColors.textSecondary,
        height: 1.35,
      );

  static TextStyle get button => GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: RiderColors.textOnPrimary,
        height: 1.2,
      );

  static TextStyle get hint => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: RiderColors.hint,
        height: 1.4,
      );
}
