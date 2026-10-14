import 'package:flutter/material.dart';

import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import 'waiting_clock.dart';

class PickupWaitView extends StatelessWidget {
  const PickupWaitView({
    required this.clock,
    required this.freeMinutes,
    required this.elapsedSeconds,
    required this.perMinute,
    required this.amount,
    required this.amountSource,
    required this.onStartTrip,
    required this.onMenu,
    this.primaryEnabled = true,
    this.error,
    this.arrivalMissing = false,
    super.key,
  });

  final String clock;
  final int freeMinutes;
  final int? elapsedSeconds;
  final String perMinute;
  final String amount;
  final String amountSource;
  final VoidCallback? onStartTrip;
  final VoidCallback onMenu;
  final bool primaryEnabled;
  final String? error;
  final bool arrivalMissing;

  @override
  Widget build(BuildContext context) {
    final int remaining = elapsedSeconds == null
        ? 0
        : freeWaitingRemainingSeconds(
            elapsedSeconds: elapsedSeconds!,
            freeMinutes: freeMinutes,
          );
    final bool charging = elapsedSeconds != null && remaining == 0 && freeMinutes > 0
        ? elapsedSeconds! >= freeMinutes * 60
        : amount != '0.00' && amount != '0';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(RiderSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Rider at Pickup Location',
                    style: RiderTextStyles.heading,
                  ),
                ),
                IconButton(
                  tooltip: 'Order details',
                  onPressed: onMenu,
                  icon: const Icon(Icons.menu_rounded),
                  color: RiderColors.textPrimary,
                ),
              ],
            ),
            const Spacer(),
            Text(
              'Waiting for customer',
              textAlign: TextAlign.center,
              style: RiderTextStyles.caption,
            ),
            const SizedBox(height: RiderSpacing.md),
            Text(
              clock,
              key: const Key('waiting-clock'),
              textAlign: TextAlign.center,
              style: RiderTextStyles.heading.copyWith(
                fontSize: 64,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
            const SizedBox(height: RiderSpacing.md),
            Text(
              arrivalMissing
                  ? 'The server has not confirmed the arrival time, so waiting charges are not running.'
                  : remaining > 0
                      ? 'Free waiting left ${formatWaitingClock(remaining)}'
                      : 'Free waiting of $freeMinutes min has ended',
              textAlign: TextAlign.center,
              style: RiderTextStyles.body,
            ),
            const SizedBox(height: RiderSpacing.sm),
            Text(
              'Rate Rs $perMinute / completed minute',
              textAlign: TextAlign.center,
              style: RiderTextStyles.caption,
            ),
            const SizedBox(height: 4),
            Text(
              charging || amount != '0.00'
                  ? 'Waiting charge Rs $amount'
                  : 'Waiting charge Rs 0.00',
              textAlign: TextAlign.center,
              style: RiderTextStyles.title.copyWith(color: RiderColors.primary),
            ),
            if (amountSource == 'assessed')
              Text(
                'Recorded by the server',
                textAlign: TextAlign.center,
                style: RiderTextStyles.caption,
              ),
            if (error != null && error!.isNotEmpty) ...[
              const SizedBox(height: RiderSpacing.md),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: RiderTextStyles.caption.copyWith(color: RiderColors.error),
              ),
            ],
            const Spacer(),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: primaryEnabled ? onStartTrip : null,
                style: FilledButton.styleFrom(
                  backgroundColor: RiderColors.primary,
                  foregroundColor: RiderColors.textOnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text('PACKAGE PICKED UP → START TRIP'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
