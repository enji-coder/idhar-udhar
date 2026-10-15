import 'package:flutter/material.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';

import '../../data/models/rider_order.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';

class RiderOrderDetailsSheet extends StatelessWidget {
  const RiderOrderDetailsSheet({
    required this.order,
    required this.statusLabel,
    this.waiting,
    super.key,
  });

  final RiderOrder order;
  final String statusLabel;
  final PickupWaitSnapshot? waiting;

  @override
  Widget build(BuildContext context) {
    final String id = order.crn == null || order.crn!.trim().isEmpty
        ? order.id
        : '${order.id} · CRN ${order.crn}';
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          RiderSpacing.screenH,
          RiderSpacing.md,
          RiderSpacing.screenH,
          RiderSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order details',
                    style: RiderTextStyles.heading.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 28),
                  color: RiderColors.textPrimary,
                ),
              ],
            ),
            const SizedBox(height: RiderSpacing.sm),
            _DetailRow(
              icon: Icons.assignment_outlined,
              label: 'Order',
              child: Text(id, style: _valueStyle),
            ),
            _DetailRow(
              icon: Icons.check_circle_outline_rounded,
              label: 'Status',
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8F0EA),
                    borderRadius: BorderRadius.circular(RiderRadius.pill),
                  ),
                  child: Text(
                    statusLabel,
                    style: RiderTextStyles.bodyMedium.copyWith(
                      fontSize: 13,
                      color: RiderColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            _DetailRow(
              icon: Icons.two_wheeler_rounded,
              label: 'Vehicle',
              child: Text(_shown(order.vehicleName), style: _valueStyle),
            ),
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: 'Pickup',
              child: Text(order.pickup, style: _valueStyle),
            ),
            _DetailRow(
              icon: Icons.location_on_rounded,
              label: 'Drop',
              child: Text(order.drop, style: _valueStyle),
            ),
            _DetailRow(
              icon: Icons.inventory_2_outlined,
              label: 'Package',
              child: Text(_shown(order.packageLabel), style: _valueStyle),
            ),
            _DetailRow(
              icon: Icons.currency_rupee_rounded,
              label: 'Trip fare',
              child: Text(_money(order.tripAmount), style: _valueStyle),
            ),
            _DetailRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Rider amount',
              child: Text(_money(order.riderAmount), style: _valueStyle),
            ),
            if (waiting != null)
              _DetailRow(
                icon: Icons.hourglass_bottom_rounded,
                label: 'Waiting charge',
                child: Text(
                  'Rs ${waiting!.amount} · ${waiting!.initialWaitingMinutes} min free · Rs ${waiting!.perMinute}/min',
                  style: _valueStyle,
                ),
              ),
            _DetailRow(
              icon: Icons.credit_card_rounded,
              label: 'Payment',
              child: Text(order.paymentLabel, style: _valueStyle),
            ),
            _DetailRow(
              icon: Icons.person_outline_rounded,
              label: 'Sender',
              child: Text(
                _contact(
                  order.senderName.trim().isEmpty
                      ? order.customerMaskedName
                      : order.senderName,
                  order.senderPhone.trim().isEmpty
                      ? order.customerMaskedPhone
                      : order.senderPhone,
                ),
                style: _valueStyle,
              ),
            ),
            _DetailRow(
              icon: Icons.person_outline_rounded,
              label: 'Receiver',
              showDivider: false,
              child: Text(
                _contact(order.receiverName, order.receiverPhone),
                style: _valueStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static TextStyle get _valueStyle => RiderTextStyles.bodyMedium.copyWith(
        fontSize: 14,
        height: 1.4,
        color: RiderColors.textPrimary,
      );

  static String _shown(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? '—' : trimmed;
  }

  static String _money(double amount) {
    if (!amount.isFinite) {
      return '—';
    }
    if (amount == amount.roundToDouble()) {
      return 'Rs ${amount.toStringAsFixed(0)}';
    }
    return 'Rs ${amount.toStringAsFixed(2)}';
  }

  static String _contact(String name, String phone) {
    final String who = name.trim().isEmpty ? '—' : name.trim();
    final String number = phone.trim();
    if (number.isEmpty) {
      return who;
    }
    return '$who · $number';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.child,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final Widget child;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: RiderSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: RiderColors.textPrimary),
              const SizedBox(width: RiderSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: RiderTextStyles.caption.copyWith(
                        fontSize: 12,
                        color: RiderColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    child,
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFE3EEEC),
          ),
      ],
    );
  }
}
