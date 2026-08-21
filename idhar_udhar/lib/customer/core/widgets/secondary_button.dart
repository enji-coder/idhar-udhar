import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Navy text / ghost secondary action with optional chevron.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.enabled = true,
    this.showLeadingArrow = false,
    this.showTrailingArrow = false,
    this.color,
    this.textStyle,
    this.padding,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool showLeadingArrow;
  final bool showTrailingArrow;
  final Color? color;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final Color foreground = color ?? AppColors.navyDeep;
    return TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        padding: padding ??
            const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLeadingArrow) ...[
            Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: foreground),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: (textStyle ?? AppTextStyles.buttonSecondary).copyWith(
              color: foreground,
            ),
          ),
          if (showTrailingArrow) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: foreground),
          ],
        ],
      ),
    );
  }
}
