import 'package:flutter/material.dart';

import '../theme/rider_colors.dart';
import '../theme/rider_spacing.dart';
import '../theme/rider_text_styles.dart';
import 'rider_glass_card.dart';
import 'rider_section_header.dart';

class RiderVehicleOptionCard extends StatelessWidget {
  const RiderVehicleOptionCard({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.recommended = false,
    super.key,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  IconData get _icon {
    final value = label.toLowerCase();
    if (value.contains('bike') || value.contains('scooter')) {
      return Icons.two_wheeler_rounded;
    }
    if (value.contains('auto')) {
      return Icons.airport_shuttle_rounded;
    }
    return Icons.local_shipping_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: AnimatedScale(
        scale: selected ? 1.01 : 1,
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: RiderRadius.xlAll,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: RiderRadius.xlAll,
                border: Border.all(
                  color: selected
                      ? RiderColors.primary
                      : Colors.white.withValues(alpha: 0.65),
                  width: selected ? 2 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: RiderColors.primary.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: RiderGlassCard(
                padding: const EdgeInsets.all(RiderSpacing.lg),
                borderRadius: RiderRadius.xlAll,
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: selected
                            ? RiderColors.primaryGradient
                            : null,
                        color: selected
                            ? null
                            : RiderColors.primary.withValues(alpha: 0.12),
                        borderRadius: RiderRadius.mdAll,
                      ),
                      child: Icon(
                        _icon,
                        color: selected
                            ? RiderColors.textOnPrimary
                            : RiderColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: RiderSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  label,
                                  style: RiderTextStyles.title.copyWith(
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                              if (recommended) ...[
                                const SizedBox(width: RiderSpacing.sm),
                                const RiderStatusChip(
                                  label: 'Recommended',
                                  tone: RiderChipTone.success,
                                ),
                              ],
                            ],
                          ),
                          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                            const SizedBox(height: RiderSpacing.xs),
                            Text(subtitle!, style: RiderTextStyles.caption),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: selected
                          ? RiderColors.primary
                          : RiderColors.hint,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
