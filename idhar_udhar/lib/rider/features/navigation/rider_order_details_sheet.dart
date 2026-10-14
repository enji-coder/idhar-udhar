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
          RiderSpacing.lg,
          RiderSpacing.md,
          RiderSpacing.lg,
          RiderSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Order details', style: RiderTextStyles.title),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            _line('Order', id),
            _line('Status', statusLabel),
            _line('Vehicle', _shown(order.vehicleName)),
            _line('Pickup', order.pickup),
            _line('Drop', order.drop),
            _line('Package', _shown(order.packageLabel)),
            _line('Trip fare', _money(order.tripAmount)),
            _line('Rider amount', _money(order.riderAmount)),
            if (waiting != null)
              _line(
                'Waiting charge',
                'Rs ${waiting!.amount} · ${waiting!.initialWaitingMinutes} min free · Rs ${waiting!.perMinute}/min',
              ),
            _line('Payment', order.paymentLabel),
            _line(
              'Sender',
              _contact(
                order.senderName.trim().isEmpty
                    ? order.customerMaskedName
                    : order.senderName,
                order.senderPhone.trim().isEmpty
                    ? order.customerMaskedPhone
                    : order.senderPhone,
              ),
            ),
            _line(
              'Receiver',
              _contact(order.receiverName, order.receiverPhone),
            ),
            const SizedBox(height: RiderSpacing.md),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: RiderColors.primary,
                  foregroundColor: RiderColors.textOnPrimary,
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RiderSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: RiderTextStyles.caption),
          const SizedBox(height: 2),
          Text(value, style: RiderTextStyles.body),
        ],
      ),
    );
  }

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
