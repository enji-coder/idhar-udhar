import 'package:flutter/material.dart';

import 'package:idhar_udhar/customer/core/theme/app_colors.dart';
import 'package:idhar_udhar/customer/core/theme/app_radius.dart';
import 'package:idhar_udhar/customer/core/theme/app_spacing.dart';
import 'package:idhar_udhar/customer/core/theme/app_text_styles.dart';

import 'glass_button.dart';
import 'gradient_button.dart';

/// Brand dialog helper with glass-friendly content.
abstract final class CustomDialog {
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String? cancelLabel = 'Cancel',
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool barrierDismissible = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: AppColors.scrim,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
            vertical: AppSpacing.xxxl,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.warmWhite,
              borderRadius: AppRadius.xlAll,
              border: Border.all(color: AppColors.borderGlassStrong),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: AppTextStyles.headingM),
                  const SizedBox(height: AppSpacing.md),
                  Text(message, style: AppTextStyles.body),
                  const SizedBox(height: AppSpacing.xxl),
                  GradientButton(
                    label: confirmLabel,
                    showArrow: false,
                    onPressed: () {
                      Navigator.of(context).pop(true);
                      onConfirm?.call();
                    },
                  ),
                  if (cancelLabel != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    GlassButton(
                      label: cancelLabel,
                      onPressed: () {
                        Navigator.of(context).pop(false);
                        onCancel?.call();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
