import 'dart:math' as math;

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
    final bool charging =
        elapsedSeconds != null && remaining == 0 && freeMinutes > 0
            ? elapsedSeconds! >= freeMinutes * 60
            : amount != '0.00' && amount != '0';
    final String infoMessage = arrivalMissing
        ? 'Arrival time not confirmed. Waiting charges have not started.'
        : remaining > 0
            ? 'Free waiting left ${formatWaitingClock(remaining)}'
            : 'Free waiting of $freeMinutes min has ended';
    final String chargeLabel = charging || amount != '0.00'
        ? 'Waiting charge Rs $amount'
        : 'Waiting charge Rs 0.00';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          RiderSpacing.screenH,
          RiderSpacing.md,
          RiderSpacing.screenH,
          RiderSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Rider at Pickup Location',
                    style: RiderTextStyles.heading.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Order details',
                  onPressed: onMenu,
                  icon: const Icon(Icons.menu_rounded, size: 28),
                  color: RiderColors.textPrimary,
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: RiderSpacing.lg),
                    const SizedBox(
                      height: 168,
                      width: 220,
                      child: CustomPaint(
                        painter: _PickupWaitHeroPainter(),
                      ),
                    ),
                    const SizedBox(height: RiderSpacing.xl),
                    Text(
                      'Waiting for customer',
                      textAlign: TextAlign.center,
                      style: RiderTextStyles.bodyMedium.copyWith(
                        fontSize: 16,
                        color: RiderColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: RiderSpacing.sm),
                    Text(
                      clock,
                      key: const Key('waiting-clock'),
                      textAlign: TextAlign.center,
                      style: RiderTextStyles.heading.copyWith(
                        fontSize: 56,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    const SizedBox(height: RiderSpacing.lg),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: RiderSpacing.md,
                        vertical: RiderSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8F0EA),
                        borderRadius: BorderRadius.circular(RiderRadius.md),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 22,
                            color: RiderColors.textPrimary,
                          ),
                          const SizedBox(width: RiderSpacing.sm),
                          Expanded(
                            child: Text(
                              infoMessage,
                              style: RiderTextStyles.body.copyWith(
                                fontSize: 13,
                                height: 1.35,
                                color: RiderColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: RiderSpacing.lg),
                    Text(
                      'Rate Rs $perMinute / completed minute',
                      textAlign: TextAlign.center,
                      style: RiderTextStyles.caption.copyWith(
                        color: RiderColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: RiderSpacing.xs),
                    Text(
                      chargeLabel,
                      textAlign: TextAlign.center,
                      style: RiderTextStyles.title.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: RiderColors.primary,
                      ),
                    ),
                    if (amountSource == 'assessed') ...[
                      const SizedBox(height: 2),
                      Text(
                        'Recorded by the server',
                        textAlign: TextAlign.center,
                        style: RiderTextStyles.caption,
                      ),
                    ],
                    if (error != null && error!.isNotEmpty) ...[
                      const SizedBox(height: RiderSpacing.sm),
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: RiderTextStyles.caption.copyWith(
                          color: RiderColors.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: RiderSpacing.xl),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: primaryEnabled ? onStartTrip : null,
                style: FilledButton.styleFrom(
                  backgroundColor: RiderColors.primary,
                  foregroundColor: RiderColors.textOnPrimary,
                  disabledBackgroundColor:
                      RiderColors.primary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  textStyle: RiderTextStyles.button.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
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

/// Flat mint hero matching the pickup-wait reference (no extra asset file).
class _PickupWaitHeroPainter extends CustomPainter {
  const _PickupWaitHeroPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height * 0.55);
    final double radius = math.min(size.width, size.height) * 0.46;

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFFD5EFEA),
    );

    final Paint mid = Paint()..color = const Color(0xFFB7D9D4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          center.dx - radius * 0.72,
          center.dy - radius * 0.18,
          radius * 0.22,
          radius * 0.55,
        ),
        const Radius.circular(4),
      ),
      mid,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          center.dx - radius * 0.42,
          center.dy - radius * 0.35,
          radius * 0.18,
          radius * 0.72,
        ),
        const Radius.circular(4),
      ),
      mid,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          center.dx + radius * 0.05,
          center.dy - radius * 0.28,
          radius * 0.2,
          radius * 0.65,
        ),
        const Radius.circular(4),
      ),
      mid,
    );

    final Paint tree = Paint()..color = RiderColors.primary;
    canvas.drawCircle(
      Offset(center.dx - radius * 0.55, center.dy + radius * 0.05),
      radius * 0.16,
      tree,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx - radius * 0.55, center.dy + radius * 0.28),
          width: radius * 0.06,
          height: radius * 0.28,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = RiderColors.textPrimary,
    );

    final Offset pin =
        Offset(center.dx + radius * 0.02, center.dy - radius * 0.05);
    final Path pinPath = Path()
      ..moveTo(pin.dx, pin.dy + radius * 0.38)
      ..quadraticBezierTo(
        pin.dx - radius * 0.22,
        pin.dy + radius * 0.05,
        pin.dx - radius * 0.22,
        pin.dy - radius * 0.08,
      )
      ..arcToPoint(
        Offset(pin.dx + radius * 0.22, pin.dy - radius * 0.08),
        radius: Radius.circular(radius * 0.22),
        clockwise: true,
      )
      ..quadraticBezierTo(
        pin.dx + radius * 0.22,
        pin.dy + radius * 0.05,
        pin.dx,
        pin.dy + radius * 0.38,
      )
      ..close();
    canvas.drawPath(pinPath, Paint()..color = RiderColors.primary);
    canvas.drawCircle(
      Offset(pin.dx, pin.dy - radius * 0.08),
      radius * 0.08,
      Paint()..color = Colors.white,
    );

    final Offset bike =
        Offset(center.dx + radius * 0.42, center.dy + radius * 0.22);
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = RiderColors.textPrimary;
    canvas.drawCircle(bike, radius * 0.1, stroke);
    canvas.drawCircle(
      Offset(bike.dx - radius * 0.28, bike.dy),
      radius * 0.1,
      stroke,
    );
    canvas.drawLine(
      Offset(bike.dx - radius * 0.22, bike.dy - radius * 0.02),
      Offset(bike.dx - radius * 0.02, bike.dy - radius * 0.02),
      stroke,
    );
    canvas.drawLine(
      Offset(bike.dx - radius * 0.08, bike.dy - radius * 0.02),
      Offset(bike.dx - radius * 0.12, bike.dy - radius * 0.22),
      stroke,
    );
    canvas.drawCircle(
      Offset(bike.dx - radius * 0.12, bike.dy - radius * 0.34),
      radius * 0.07,
      Paint()..color = RiderColors.primary,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          bike.dx - radius * 0.02,
          bike.dy - radius * 0.28,
          radius * 0.16,
          radius * 0.18,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = RiderColors.primary,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
