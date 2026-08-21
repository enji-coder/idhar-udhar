import 'package:flutter/material.dart';

import 'package:idhar_udhar/customer/core/theme/app_colors.dart';
import 'package:idhar_udhar/customer/core/theme/app_spacing.dart';
import 'package:idhar_udhar/customer/core/theme/app_text_styles.dart';

/// Section heading with optional action link.
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    super.key,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.headingM),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle!, style: AppTextStyles.body),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.orange,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              child: Text(
                actionLabel!,
                style: AppTextStyles.label.copyWith(color: AppColors.orange),
              ),
            ),
        ],
      ),
    );
  }
}
