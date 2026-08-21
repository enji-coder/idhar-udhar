import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/glass_effect.dart';

/// Benefit / how-it-works row with orange icon well and optional chevron.
class FeatureCard extends StatelessWidget {
  const FeatureCard({
    required this.title,
    required this.icon,
    super.key,
    this.subtitle,
    this.onTap,
    this.showChevron = true,
    this.iconBackground = AppColors.softPeach,
    this.iconColor = AppColors.orange,
    this.padding,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool showChevron;
  final Color iconBackground;
  final Color iconColor;
  final EdgeInsetsGeometry? padding;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double iconWell = compact ? 38.0 : 44.0;
    final Widget content = GlassEffect(
      depth: GlassDepthLevel.subtle,
      borderRadius: AppRadius.mdLgAll,
      showInnerHighlight: true,
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: compact ? AppSpacing.sm : AppSpacing.md,
          ),
      child: Row(
        children: [
          Container(
            width: iconWell,
            height: iconWell,
            decoration: BoxDecoration(
              color: iconBackground.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: compact ? 18 : AppSpacing.iconMd,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: compact ? 14 : null,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: compact ? 11.5 : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showChevron)
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.navyMuted,
            ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }
    return GestureDetector(onTap: onTap, child: content);
  }
}
