import 'package:flutter/material.dart';

import 'package:idhar_udhar/customer/core/theme/app_colors.dart';
import 'package:idhar_udhar/customer/core/theme/app_radius.dart';
import 'package:idhar_udhar/customer/core/theme/app_spacing.dart';
import 'package:idhar_udhar/customer/core/theme/app_text_styles.dart';
import 'package:idhar_udhar/customer/core/theme/glass_effect.dart';

import 'glass_container.dart';

/// Compact booking summary card for history / home lists.
class BookingCard extends StatelessWidget {
  const BookingCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onTap,
    super.key,
    this.leadingIcon = Icons.local_shipping_outlined,
    this.trailing,
    this.fareLabel,
    this.statusColor,
  });

  final String title;
  final String subtitle;
  final String status;
  final VoidCallback onTap;
  final IconData leadingIcon;
  final Widget? trailing;
  final String? fareLabel;
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    final Color chipColor = statusColor ?? AppColors.orange;

    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        depth: GlassDepthLevel.normal,
        padding: const EdgeInsets.all(AppSpacing.lg),
        borderRadius: AppRadius.lgAll,
        child: Row(
          children: [
            Container(
              width: AppSpacing.massive,
              height: AppSpacing.massive,
              decoration: BoxDecoration(
                color: AppColors.softPeach.withOpacity(0.9),
                borderRadius: AppRadius.mdAll,
              ),
              child: Icon(leadingIcon, color: AppColors.orange),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.headingS,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: chipColor.withOpacity(0.12),
                      borderRadius: AppRadius.pillAll,
                    ),
                    child: Text(
                      status,
                      style: AppTextStyles.caption.copyWith(
                        color: chipColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (fareLabel != null)
                  Text(
                    fareLabel!,
                    style: AppTextStyles.headingS.copyWith(
                      color: AppColors.navyDeep,
                    ),
                  ),
                trailing ??
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.navyMuted,
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
