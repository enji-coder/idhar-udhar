import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/models/rider_order.dart';
import '../theme/rider_colors.dart';
import '../theme/rider_spacing.dart';
import '../theme/rider_text_styles.dart';
import 'rider_glass_card.dart';
import 'rider_primary_button.dart';
import 'rider_secondary_button.dart';

/// Foreground order alert: one-shot system sound + visible popup.
/// Does not claim to draw over other apps unless Android overlay is enabled
/// by the system; this dialog only appears while the Rider app is in front.
abstract final class RiderOrderAlert {
  static Future<bool?> show(
    BuildContext context, {
    required RiderOrder order,
  }) async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.heavyImpact();
    } catch (_) {
      // Never crash if sound / haptics / notification permission is denied.
    }

    if (!context.mounted) return null;

    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'New delivery',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      pageBuilder: (context, animation, secondary) {
        return SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(RiderSpacing.screenH),
              child: Material(
                color: Colors.transparent,
                child: RiderGlassCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.notifications_active_rounded,
                            color: RiderColors.primary,
                          ),
                          const SizedBox(width: RiderSpacing.sm),
                          Expanded(
                            child: Text(
                              'New delivery available',
                              style: RiderTextStyles.title,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: RiderSpacing.lg),
                      _line(
                        Icons.store_mall_directory_rounded,
                        'Pickup',
                        order.pickup,
                      ),
                      const SizedBox(height: RiderSpacing.sm),
                      _line(Icons.location_on_rounded, 'Drop', order.drop),
                      const SizedBox(height: RiderSpacing.sm),
                      _line(
                        Icons.route_rounded,
                        'Distance',
                        '${order.distanceKm} km',
                      ),
                      const SizedBox(height: RiderSpacing.sm),
                      _line(
                        Icons.payments_rounded,
                        'Estimated earning',
                        currency.format(order.estimatedEarnings),
                        emphasize: true,
                      ),
                      const SizedBox(height: RiderSpacing.xl),
                      Row(
                        children: [
                          Expanded(
                            child: RiderSecondaryButton(
                              label: 'Reject',
                              destructive: true,
                              onPressed: () =>
                                  Navigator.of(context).pop(false),
                            ),
                          ),
                          const SizedBox(width: RiderSpacing.md),
                          Expanded(
                            flex: 2,
                            child: RiderPrimaryButton(
                              label: 'Accept',
                              onPressed: () =>
                                  Navigator.of(context).pop(true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _line(
    IconData icon,
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: RiderColors.primary),
        const SizedBox(width: RiderSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: RiderTextStyles.caption),
              Text(
                value,
                style: emphasize
                    ? RiderTextStyles.bodyMedium.copyWith(
                        color: RiderColors.primary,
                        fontWeight: FontWeight.w700,
                      )
                    : RiderTextStyles.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
