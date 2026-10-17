import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import 'waiting_clock.dart';

class PickupWaitView extends StatelessWidget {
  const PickupWaitView({
    required this.freeMinutes,
    required this.elapsedSeconds,
    required this.perMinute,
    required this.amount,
    required this.amountSource,
    required this.onStartTrip,
    required this.onMenu,
    this.rulesLoaded = true,
    this.rateAvailable = true,
    this.primaryEnabled = true,
    this.error,
    this.arrivalMissing = false,
    super.key,
  });

  final int freeMinutes;
  final int? elapsedSeconds;
  final String perMinute;
  final String amount;
  final String amountSource;
  final VoidCallback? onStartTrip;
  final VoidCallback onMenu;
  final bool rulesLoaded;
  final bool rateAvailable;
  final bool primaryEnabled;
  final String? error;
  final bool arrivalMissing;

  bool get _counting =>
      rulesLoaded && !arrivalMissing && elapsedSeconds != null;

  bool get _charging {
    if (!_counting) {
      return false;
    }
    return freeWaitingRemainingSeconds(
          elapsedSeconds: elapsedSeconds!,
          freeMinutes: freeMinutes,
        ) ==
        0;
  }

  String get _clock {
    if (!rulesLoaded) {
      return '--:--';
    }
    if (!_counting) {
      return formatWaitingClock(freeMinutes * 60);
    }
    if (_charging) {
      return formatWaitingClock(
        chargeableWaitingSeconds(
          elapsedSeconds: elapsedSeconds!,
          freeMinutes: freeMinutes,
        ),
      );
    }
    return formatWaitingClock(
      freeWaitingRemainingSeconds(
        elapsedSeconds: elapsedSeconds!,
        freeMinutes: freeMinutes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool charging = _charging;
    final String infoTitle = !_counting
        ? 'Customer not here yet'
        : charging
            ? 'Free waiting time has ended'
            : 'Free waiting in progress';
    final String infoBody = !_counting
        ? 'Your free waiting time starts after arrival is confirmed.'
        : charging
            ? 'Chargeable waiting time is running. Each completed minute is charged at the snapshot rate.'
            : 'Free waiting is counting down. No fee applies until it ends.';
    final String rate = !rateAvailable
        ? 'Unavailable'
        : perMinute.trim().isEmpty
            ? '—'
            : '₹ $perMinute / min';
    final String charge = !rateAvailable ? 'Unavailable' : '₹$amount';

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
                    'Rider at Pickup',
                    style: RiderTextStyles.heading.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
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
            Text(
              'Waiting for customer',
              style: RiderTextStyles.bodyMedium.copyWith(
                fontSize: 16,
                color: RiderColors.textPrimary,
              ),
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
                    const SizedBox(height: RiderSpacing.lg),
                    _InfoCard(title: infoTitle, body: infoBody),
                    const SizedBox(height: RiderSpacing.md),
                    _WaitingCard(
                      charging: charging,
                      clock: _clock,
                      rate: rate,
                      charge: charge,
                    ),
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
                    const SizedBox(height: RiderSpacing.lg),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text('Confirm Pickup & Start Trip'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FBFA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _OutlineIcon(icon: Icons.access_time_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: RiderTextStyles.title.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: RiderTextStyles.body.copyWith(
                    fontSize: 13,
                    height: 1.35,
                    color: RiderColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({
    required this.charging,
    required this.clock,
    required this.rate,
    required this.charge,
  });

  final bool charging;
  final String clock;
  final String rate;
  final String charge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x140F3D3E),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const _OutlineIcon(icon: Icons.access_time_rounded),
              const SizedBox(width: 12),
              Text(
                charging ? 'CHARGEABLE WAITING' : 'FREE WAITING TIME',
                style: _sectionLabel,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            clock,
            key: const Key('waiting-clock'),
            style: RiderTextStyles.heading.copyWith(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              height: 1.05,
              letterSpacing: 0.4,
              fontFeatures: const <FontFeature>[
                FontFeature.tabularFigures(),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            charging
                ? 'Free waiting time has ended'
                : 'No waiting fee during this time',
            style: RiderTextStyles.caption.copyWith(fontSize: 13),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFE3EEEC)),
          ),
          Row(
            children: <Widget>[
              const _OutlineIcon(icon: Icons.currency_rupee_rounded),
              const SizedBox(width: 12),
              Text('AFTER FREE TIME', style: _sectionLabel),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rate,
            style: RiderTextStyles.heading.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Charged for each completed waiting minute',
            style: RiderTextStyles.caption.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F5F2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                  color: RiderColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Current waiting charge',
                    style: RiderTextStyles.bodyMedium.copyWith(
                      fontSize: 14,
                      color: RiderColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  charge,
                  style: RiderTextStyles.title.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle get _sectionLabel => RiderTextStyles.caption.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
      color: const Color(0xFF8AA3A4),
    );

class _OutlineIcon extends StatelessWidget {
  const _OutlineIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD5E3E4)),
      ),
      child: Icon(icon, size: 18, color: RiderColors.textPrimary),
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
