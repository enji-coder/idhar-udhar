import 'package:flutter/material.dart';

import '../theme/rider_colors.dart';
import '../theme/rider_spacing.dart';
import '../theme/rider_text_styles.dart';

class RiderSectionHeader extends StatelessWidget {
  const RiderSectionHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: RiderTextStyles.title),
              if (subtitle != null) ...[
                const SizedBox(height: RiderSpacing.xs),
                Text(subtitle!, style: RiderTextStyles.caption),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class RiderStatusChip extends StatelessWidget {
  const RiderStatusChip({
    required this.label,
    super.key,
    this.tone = RiderChipTone.primary,
    this.icon,
  });

  final String label;
  final RiderChipTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (tone) {
      RiderChipTone.primary => RiderColors.primary,
      RiderChipTone.success => RiderColors.success,
      RiderChipTone.warning => RiderColors.warning,
      RiderChipTone.error => RiderColors.error,
      RiderChipTone.neutral => RiderColors.offline,
    };

    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: RiderSpacing.md,
          vertical: RiderSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: RiderRadius.pillAll,
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: RiderSpacing.xs),
            ],
            Text(
              label,
              style: RiderTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum RiderChipTone { primary, success, warning, error, neutral }
