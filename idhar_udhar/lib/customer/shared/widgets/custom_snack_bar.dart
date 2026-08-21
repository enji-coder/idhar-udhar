import 'package:flutter/material.dart';

import 'package:idhar_udhar/customer/core/theme/app_colors.dart';
import 'package:idhar_udhar/customer/core/theme/app_radius.dart';
import 'package:idhar_udhar/customer/core/theme/app_spacing.dart';
import 'package:idhar_udhar/customer/core/theme/app_text_styles.dart';

/// Floating brand snackbars for success / error / info feedback.
abstract final class CustomSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    CustomSnackBarTone tone = CustomSnackBarTone.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final Color background = switch (tone) {
      CustomSnackBarTone.success => AppColors.success,
      CustomSnackBarTone.error => AppColors.danger,
      CustomSnackBarTone.warning => AppColors.warning,
      CustomSnackBarTone.info => AppColors.navy,
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white),
          ),
          behavior: SnackBarBehavior.floating,
          duration: duration,
          backgroundColor: background,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          margin: const EdgeInsets.all(AppSpacing.lg),
          action: actionLabel == null
              ? null
              : SnackBarAction(
                  label: actionLabel,
                  textColor: AppColors.white,
                  onPressed: onAction ?? () {},
                ),
        ),
      );
  }

  static void success(BuildContext context, String message) {
    show(context, message: message, tone: CustomSnackBarTone.success);
  }

  static void error(BuildContext context, String message) {
    show(context, message: message, tone: CustomSnackBarTone.error);
  }

  static void info(BuildContext context, String message) {
    show(context, message: message, tone: CustomSnackBarTone.info);
  }
}

enum CustomSnackBarTone {
  info,
  success,
  warning,
  error,
}
