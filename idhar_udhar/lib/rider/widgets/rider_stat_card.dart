import 'package:flutter/material.dart';

import '../theme/rider_colors.dart';
import '../theme/rider_spacing.dart';
import '../theme/rider_text_styles.dart';
import 'rider_glass_card.dart';

class RiderStatCard extends StatelessWidget {
  const RiderStatCard({
    required this.label,
    required this.value,
    super.key,
    this.icon,
    this.subtitle,
    this.elevation = 0,
    this.compact = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? subtitle;
  final double elevation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double pad = compact ? RiderSpacing.lg - 1 : RiderSpacing.lg;
    final double valueSize = compact ? 19 : 20;
    final double iconSize = compact ? 17 : 18;
    final TextStyle labelStyle = compact
        ? RiderTextStyles.caption.copyWith(fontSize: 12)
        : RiderTextStyles.caption;
    final TextStyle valueStyle =
        RiderTextStyles.title.copyWith(fontSize: valueSize);
    final TextStyle? subtitleStyle = subtitle == null
        ? null
        : RiderTextStyles.caption.copyWith(fontSize: compact ? 10 : 11);

    return RiderGlassCard(
      elevation: elevation,
      padding: EdgeInsets.all(pad),
      borderRadius: RiderRadius.lgAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: iconSize, color: RiderColors.primary),
                const SizedBox(width: RiderSpacing.sm),
              ],
              Expanded(
                child: Text(
                  label,
                  style: labelStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: RiderSpacing.sm),
          Text(
            value,
            style: valueStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: RiderSpacing.xs),
            Text(
              subtitle!,
              style: subtitleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class RiderProgressBar extends StatelessWidget {
  const RiderProgressBar({
    required this.value,
    super.key,
    this.height = 8,
  });

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final double v = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: RiderRadius.pillAll,
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(color: RiderColors.primary.withValues(alpha: 0.12)),
            FractionallySizedBox(
              widthFactor: v,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RiderColors.primaryGradient,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
