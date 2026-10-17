import 'package:flutter/material.dart';

import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';

/// Drop-arrival summary. Data is supplied by the active trip; this view
/// does not load orders or submit delivery.
class DropSummaryView extends StatelessWidget {
  const DropSummaryView({
    required this.orderId,
    required this.pickup,
    required this.drop,
    required this.distanceLabel,
    required this.rideTimeLabel,
    required this.orderValueLabel,
    required this.paymentMode,
    required this.customerName,
    required this.onBack,
    required this.onMarkDelivered,
    this.busy = false,
    super.key,
  });

  final String orderId;
  final String pickup;
  final String drop;
  final String distanceLabel;
  final String rideTimeLabel;
  final String orderValueLabel;
  final String paymentMode;
  final String customerName;
  final VoidCallback onBack;
  final VoidCallback? onMarkDelivered;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(onBack: onBack),
                    const SizedBox(height: 14),
                    const _CompletedBanner(),
                    const SizedBox(height: 14),
                    _RideDetailsCard(pickup: pickup, drop: drop),
                    const SizedBox(height: 14),
                    _StatsRow(
                      rideTime: rideTimeLabel,
                      distance: distanceLabel,
                      value: orderValueLabel,
                    ),
                    const SizedBox(height: 14),
                    _DetailsCard(
                      orderId: orderId,
                      paymentMode: paymentMode,
                      customerName: customerName,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: _MarkDeliveredButton(
                busy: busy,
                onPressed: onMarkDelivered,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          color: RiderColors.textPrimary,
        ),
        Expanded(
          child: Text(
            'Order Summary',
            textAlign: TextAlign.center,
            style: RiderTextStyles.title.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                'At drop',
                style: RiderTextStyles.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF15803D),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  const _CompletedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3FBF7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: Color(0xFFE8A317),
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pickup & Drop Completed!',
                  style: RiderTextStyles.title.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You have reached the customer. Confirm below to mark this order delivered.',
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

class _RideDetailsCard extends StatelessWidget {
  const _RideDetailsCard({required this.pickup, required this.drop});

  final String pickup;
  final String drop;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.two_wheeler_rounded,
                size: 18,
                color: RiderColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Ride Details',
                style: RiderTextStyles.title.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _StopRow(
            color: const Color(0xFF16A34A),
            title: 'Pickup Location',
            address: pickup,
            showConnector: true,
          ),
          _StopRow(
            color: const Color(0xFFEF4444),
            title: 'Drop Location',
            address: drop,
          ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.color,
    required this.title,
    required this.address,
    this.showConnector = false,
  });

  final Color color;
  final String title;
  final String address;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Icon(Icons.location_on_rounded, size: 18, color: color),
                if (showConnector)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: const Color(0xFFD5E3E4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showConnector ? 12 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: RiderTextStyles.bodyMedium.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address.trim().isEmpty ? '—' : address,
                    style: RiderTextStyles.caption.copyWith(
                      fontSize: 12,
                      height: 1.35,
                      color: RiderColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.rideTime,
    required this.distance,
    required this.value,
  });

  final String rideTime;
  final String distance;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.schedule_rounded,
            label: 'Total Ride Time',
            value: rideTime,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            icon: Icons.route_rounded,
            label: 'Distance Covered',
            value: distance,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            icon: Icons.inventory_2_outlined,
            label: 'Order Value',
            value: value,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3FBF7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: RiderColors.primary),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: RiderTextStyles.caption.copyWith(fontSize: 11, height: 1.2),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: RiderTextStyles.title.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.orderId,
    required this.paymentMode,
    required this.customerName,
  });

  final String orderId;
  final String paymentMode;
  final String customerName;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                size: 18,
                color: RiderColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Additional Details',
                style: RiderTextStyles.title.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailLine(label: 'Order ID', value: orderId),
          _DetailLine(label: 'Payment Mode', value: paymentMode),
          _DetailLine(label: 'Customer Name', value: customerName),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final String shown = value.trim().isEmpty ? '—' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: RiderTextStyles.body.copyWith(
                fontSize: 13,
                color: RiderColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: RiderSpacing.sm),
          Flexible(
            child: Text(
              shown,
              textAlign: TextAlign.right,
              style: RiderTextStyles.bodyMedium.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6F0EE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F3D3E),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MarkDeliveredButton extends StatelessWidget {
  const _MarkDeliveredButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: RiderColors.primary,
          disabledBackgroundColor: RiderColors.primary.withValues(alpha: 0.45),
          foregroundColor: Colors.white,
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
          children: [
            Icon(Icons.check_rounded, size: 20),
            SizedBox(width: 8),
            Text('Mark as Delivered'),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}
