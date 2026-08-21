import 'package:flutter/material.dart';

import 'package:idhar_udhar/customer/core/theme/app_colors.dart';
import 'package:idhar_udhar/customer/core/theme/app_radius.dart';
import 'package:idhar_udhar/customer/core/theme/app_spacing.dart';
import 'package:idhar_udhar/customer/core/theme/app_text_styles.dart';

import 'glass_container.dart';

/// Rider identity card for tracking / assignment screens.
class RiderCard extends StatelessWidget {
  const RiderCard({
    required this.name,
    required this.vehicleLabel,
    super.key,
    this.rating,
    this.subtitle,
    this.avatarUrl,
    this.avatar,
    this.onCall,
    this.onMessage,
    this.onTap,
  });

  final String name;
  final String vehicleLabel;
  final double? rating;
  final String? subtitle;
  final String? avatarUrl;
  final Widget? avatar;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget avatarWidget = avatar ??
        CircleAvatar(
          radius: AppSpacing.xxl,
          backgroundColor: AppColors.softPeach,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
          child: avatarUrl == null
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style:
                      AppTextStyles.headingM.copyWith(color: AppColors.orange),
                )
              : null,
        );

    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(AppSpacing.lg),
        borderRadius: AppRadius.lgAll,
        child: Row(
          children: [
            avatarWidget,
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTextStyles.headingS),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(vehicleLabel, style: AppTextStyles.caption),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(subtitle!, style: AppTextStyles.caption),
                  ],
                  if (rating != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: AppSpacing.iconSm,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          rating!.toStringAsFixed(1),
                          style: AppTextStyles.label,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (onCall != null)
              IconButton(
                onPressed: onCall,
                icon: const Icon(Icons.call_rounded, color: AppColors.orange),
                tooltip: 'Call rider',
              ),
            if (onMessage != null)
              IconButton(
                onPressed: onMessage,
                icon: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppColors.navy,
                ),
                tooltip: 'Message rider',
              ),
          ],
        ),
      ),
    );
  }
}
