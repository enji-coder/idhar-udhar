import 'package:flutter/material.dart';
import 'package:idhar_udhar/shared/api/wallet_api.dart';
import 'package:idhar_udhar/shared/format/inr_format.dart';
import 'package:intl/intl.dart';

import '../../theme/rider_colors.dart';
import '../../theme/rider_text_styles.dart';

/// Trip statement built only from values the server already returned.
class RiderTripStatement extends StatelessWidget {
  const RiderTripStatement({
    required this.crn,
    required this.tripAt,
    required this.pickupAddress,
    required this.dropAddress,
    required this.tripFare,
    required this.riderAmount,
    required this.companyAmount,
    this.pickupAt,
    this.deliveredAt,
    this.settlementStatus,
    this.settlementState,
    this.cashCollected,
    this.walletCredited,
    this.codApplied,
    this.walletCompanyDebit,
    super.key,
  });

  final String? crn;
  final DateTime tripAt;
  final DateTime? pickupAt;
  final String pickupAddress;
  final DateTime? deliveredAt;
  final String dropAddress;
  final double? tripFare;
  final double? riderAmount;
  final double? companyAmount;
  final String? settlementStatus;
  final String? settlementState;
  final double? cashCollected;
  final double? walletCredited;
  final double? codApplied;
  final double? walletCompanyDebit;

  @override
  Widget build(BuildContext context) {
    final DateFormat day = DateFormat('EEEE, d MMMM yyyy');
    final DateFormat clock = DateFormat('h:mm a');
    final DateTime localTrip = tripAt.toLocal();
    final bool cash = settlementStatus == 'CASH';
    final String? outcome = earningSettlementLabel(settlementStatus);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _line('CRN Number', (crn ?? '').trim().isEmpty ? 'Not available' : crn!.trim()),
        _line('Trip Date', day.format(localTrip)),
        _line('Trip Time', clock.format(localTrip)),
        const SizedBox(height: 8),
        _line('Pickup Time', _when(pickupAt, clock)),
        Text(
          pickupAddress.trim().isEmpty ? 'Address not available' : pickupAddress.trim(),
          style: RiderTextStyles.body,
        ),
        const SizedBox(height: 8),
        _line('Delivered Time', _when(deliveredAt, clock)),
        Text(
          dropAddress.trim().isEmpty ? 'Address not available' : dropAddress.trim(),
          style: RiderTextStyles.body,
        ),
        const SizedBox(height: 12),
        Text('EARNING DETAILS', style: RiderTextStyles.bodyMedium),
        const SizedBox(height: 4),
        _money('Trip Fare', tripFare),
        _money('Partner Earning', riderAmount),
        _money('IDHAR UDHAR Amount', companyAmount),
        const Divider(height: 20),
        _money('YOUR EARNING', riderAmount),
        const SizedBox(height: 12),
        Text('SETTLEMENT DETAILS', style: RiderTextStyles.bodyMedium),
        const SizedBox(height: 4),
        if (cash) ...[
          _signed('CASH COLLECTED', cashCollected, credit: true),
          _signed(
            'WALLET',
            walletCompanyDebit == null ? null : -walletCompanyDebit!,
            credit: false,
          ),
        ] else ...[
          _line('ONLINE PAYMENT', outcome ?? 'Status not available'),
          _signed('WALLET CREDIT', walletCredited, credit: true),
          _money('APPLIED TO COD DUE', codApplied),
        ],
        _line(
          'SETTLEMENT STATUS',
          settlementState == 'SETTLED'
              ? 'SETTLED'
              : settlementState == 'PENDING'
                  ? 'PENDING'
                  : 'Not available',
        ),
        if (outcome != null) ...[
          const SizedBox(height: 4),
          Text(outcome, style: RiderTextStyles.caption),
        ],
      ],
    );
  }

  static String _when(DateTime? value, DateFormat clock) {
    if (value == null) {
      return 'Not recorded';
    }
    return clock.format(value.toLocal());
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: RiderTextStyles.caption)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: RiderTextStyles.bodyMedium,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _money(String label, double? amount) {
    return _line(
      label,
      amount == null ? '—' : formatInr(amount),
    );
  }

  Widget _signed(String label, double? amount, {required bool credit}) {
    final String text = amount == null
        ? '—'
        : '${credit && amount > 0 ? '+' : ''}${formatInr(amount)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: RiderTextStyles.caption)),
          Text(
            text,
            style: RiderTextStyles.bodyMedium.copyWith(
              color: credit && (amount ?? 0) > 0
                  ? RiderColors.success
                  : RiderColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
