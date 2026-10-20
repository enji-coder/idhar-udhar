import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/rider_colors.dart';
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
    this.orderTitle = '',
    this.pickupAddress = '',
    this.dropAddress = '',
    this.packageLabel = '',
    this.distanceLabel = '',
    this.etaLabel = '',
    this.onBack,
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
  final String orderTitle;
  final String pickupAddress;
  final String dropAddress;
  final String packageLabel;
  final String distanceLabel;
  final String etaLabel;
  final VoidCallback? onBack;

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

    final String title = orderTitle.trim().isEmpty
        ? 'Arrived at Pickup'
        : 'Order ${orderTitle.trim()}';
    final bool showRoute =
        pickupAddress.trim().isNotEmpty || dropAddress.trim().isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PhaseHeader(
              title: title,
              onMenu: onMenu,
              onBack: onBack,
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    const _LocationBanner(
                      title: 'Pickup Location',
                      icon: Icons.location_on_rounded,
                      iconColor: RiderColors.primary,
                    ),
                    if (showRoute) ...[
                      const SizedBox(height: 12),
                      _RouteCard(
                        pickup: pickupAddress,
                        drop: dropAddress,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _StatsRow(
                      packageLabel: packageLabel,
                      distanceLabel: distanceLabel,
                      etaLabel: etaLabel,
                    ),
                    const SizedBox(height: 12),
                    const _ArrivalMessage(),
                    const SizedBox(height: 12),
                    _InfoCard(title: infoTitle, body: infoBody),
                    const SizedBox(height: 12),
                    _WaitingCard(
                      charging: charging,
                      clock: _clock,
                      rate: rate,
                      charge: charge,
                    ),
                    if (error != null && error!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: RiderTextStyles.caption.copyWith(
                          color: RiderColors.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            FilledButton(
              onPressed: primaryEnabled ? onStartTrip : null,
              style: FilledButton.styleFrom(
                backgroundColor: RiderColors.primary,
                foregroundColor: RiderColors.textOnPrimary,
                disabledBackgroundColor:
                    RiderColors.primary.withValues(alpha: 0.4),
                minimumSize: const Size.fromHeight(64),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: RiderTextStyles.button.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Row(
                children: <Widget>[
                  _ButtonIcon(icon: Icons.inventory_2_rounded),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Package Picked Up',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Start Trip',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xE6FFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 26),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Once you reach the pickup location, select the button above.',
              textAlign: TextAlign.center,
              style: RiderTextStyles.caption.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseHeader extends StatelessWidget {
  const _PhaseHeader({
    required this.title,
    required this.onMenu,
    this.onBack,
  });

  final String title;
  final VoidCallback onMenu;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              color: RiderColors.textPrimary,
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: RiderTextStyles.title.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
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
    );
  }
}

class _LocationBanner extends StatelessWidget {
  const _LocationBanner({
    required this.title,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _cardDecoration,
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: RiderTextStyles.title.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: RiderColors.primary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE5F6EF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: Color(0xFF16A34A),
                ),
                const SizedBox(width: 4),
                Text(
                  'Arrived',
                  style: RiderTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF15803D),
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

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.pickup, required this.drop});

  final String pickup;
  final String drop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: _cardDecoration,
      child: Column(
        children: [
          _AddressBlock(
            icon: Icons.warehouse_rounded,
            iconColor: RiderColors.primary,
            title: 'Pickup Location',
            address: pickup,
          ),
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: _RouteConnector(),
          ),
          _AddressBlock(
            icon: Icons.location_on_rounded,
            iconColor: const Color(0xFFF59E0B),
            title: 'Drop Location',
            address: drop,
          ),
        ],
      ),
    );
  }
}

class _AddressBlock extends StatelessWidget {
  const _AddressBlock({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.address,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String address;

  @override
  Widget build(BuildContext context) {
    final String shown = address.trim().isEmpty ? '—' : address.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: RiderTextStyles.title.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: RiderColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                shown,
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
    );
  }
}

class _RouteConnector extends StatelessWidget {
  const _RouteConnector();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 36,
      child: Column(
        children: <Widget>[
          _Dash(),
          _Dash(),
          _Dash(),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: RiderColors.hint,
          ),
        ],
      ),
    );
  }
}

class _Dash extends StatelessWidget {
  const _Dash();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 1.5),
      color: RiderColors.border,
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.packageLabel,
    required this.distanceLabel,
    required this.etaLabel,
  });

  final String packageLabel;
  final String distanceLabel;
  final String etaLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: _cardDecoration,
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              icon: Icons.inventory_2_outlined,
              label: 'Package',
              value: _shown(packageLabel, empty: '—'),
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _Stat(
              icon: Icons.location_on_outlined,
              label: 'Distance',
              value: _approx(distanceLabel),
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _Stat(
              icon: Icons.schedule_rounded,
              label: 'Est. Time',
              value: _shown(etaLabel, empty: '—'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: RiderColors.primary),
        const SizedBox(height: 4),
        Text(label, style: RiderTextStyles.caption.copyWith(fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: RiderTextStyles.bodyMedium.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 42, color: const Color(0xFFE3EEEC));
  }
}

class _ArrivalMessage extends StatelessWidget {
  const _ArrivalMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
      decoration: _cardDecoration,
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 108,
            height: 88,
            child: CustomPaint(painter: _PickupWaitHeroPainter()),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  "You've arrived at the pickup location!",
                  style: RiderTextStyles.title.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: RiderColors.primary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please collect the package and confirm to start the trip.',
                  style: RiderTextStyles.caption.copyWith(
                    fontSize: 12,
                    height: 1.35,
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

class _ButtonIcon extends StatelessWidget {
  const _ButtonIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: Colors.white),
    );
  }
}

String _shown(String value, {required String empty}) {
  final String text = value.trim();
  return text.isEmpty ? empty : text;
}

String _approx(String value) {
  final String text = value.trim();
  if (text.isEmpty || text == '—') {
    return '—';
  }
  return text.startsWith('~') ? text : '~ $text';
}

BoxDecoration get _cardDecoration => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x140F3D3E),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    );

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
