import 'package:flutter/material.dart';
import 'package:idhar_udhar/shared/api/wallet_api.dart';
import 'package:idhar_udhar/shared/format/inr_format.dart';
import 'package:intl/intl.dart';

import '../../theme/rider_colors.dart';
import '../../theme/rider_text_styles.dart';

/// White statement card with a teal title tab, matching the rider order detail.
class RiderStatementCard extends StatelessWidget {
  const RiderStatementCard({
    required this.icon,
    required this.title,
    required this.child,
    this.accent = RiderColors.primary,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14148BA6),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border.fromBorderSide(BorderSide(color: Color(0xFFE3EEEC))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: RiderTextStyles.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RiderStatementRow extends StatelessWidget {
  const RiderStatementRow({
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.valueColor,
    this.emphasize = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final Color? valueColor;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final Widget valueWidget = trailing ??
        Text(
          value ?? '',
          textAlign: TextAlign.end,
          softWrap: true,
          style: RiderTextStyles.bodyMedium.copyWith(
            fontSize: emphasize ? 15 : 13,
            fontWeight: FontWeight.w700,
            color: valueColor ?? RiderColors.textPrimary,
            height: 1.35,
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE7F2F0)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: RiderColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 15, color: RiderColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
                    style: RiderTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: Align(
                  alignment: Alignment.topRight,
                  child: valueWidget,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RiderStatusPill extends StatelessWidget {
  const RiderStatusPill({
    required this.label,
    required this.color,
    this.icon = Icons.check_circle_rounded,
    super.key,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.end,
              style: RiderTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    this.cancelled = false,
    this.completed = true,
    this.cancelledAt,
    this.settlementStatus,
    this.settlementState,
    this.cashCollected,
    this.walletCredited,
    this.codApplied,
    this.walletCompanyDebit,
    this.hasSnapshot = true,
    this.paymentLabel,
    this.customerBill,
    this.extras = const <Widget>[],
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
  final bool cancelled;
  final bool completed;
  final DateTime? cancelledAt;
  final String? settlementStatus;
  final String? settlementState;
  final double? cashCollected;
  final double? walletCredited;
  final double? codApplied;
  final double? walletCompanyDebit;

  /// False when the earnings snapshot was not returned. Placeholders are omitted.
  final bool hasSnapshot;
  final String? paymentLabel;
  final double? customerBill;
  final List<Widget> extras;

  @override
  Widget build(BuildContext context) {
    final DateFormat day = DateFormat('EEEE, d MMMM yyyy');
    final DateFormat clock = DateFormat('h:mm a');
    final DateTime localTrip = tripAt.toLocal();
    final bool cash = settlementStatus == 'CASH';
    final String? outcome = earningSettlementLabel(settlementStatus);
    final bool showHighlight =
        hasSnapshot && completed && !cancelled && riderAmount != null;
    final bool showEarning = hasSnapshot ||
        tripFare != null ||
        riderAmount != null ||
        companyAmount != null ||
        customerBill != null;
    final bool showSettlement = hasSnapshot ||
        (paymentLabel != null && paymentLabel!.trim().isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RiderStatementCard(
          icon: Icons.place_rounded,
          title: 'Trip Statement',
          child: Column(
            children: [
              RiderStatementRow(
                icon: Icons.tag_rounded,
                label: 'CRN Number',
                value: (crn ?? '').trim().isEmpty
                    ? 'Not available'
                    : crn!.trim(),
              ),
              RiderStatementRow(
                icon: Icons.calendar_today_rounded,
                label: 'Trip Date',
                value: day.format(localTrip),
              ),
              RiderStatementRow(
                icon: Icons.schedule_rounded,
                label: 'Trip Time',
                value: clock.format(localTrip),
              ),
              RiderStatementRow(
                icon: Icons.play_arrow_rounded,
                label: 'Pickup Time',
                value: _when(pickupAt, clock),
              ),
              RiderStatementRow(
                icon: Icons.location_on_outlined,
                label: 'Pickup Address',
                value: pickupAddress.trim().isEmpty
                    ? 'Address not available'
                    : pickupAddress.trim(),
              ),
              RiderStatementRow(
                icon: cancelled
                    ? Icons.cancel_outlined
                    : Icons.flag_outlined,
                label: cancelled ? 'Cancelled Time' : 'Delivered Time',
                value: cancelled
                    ? _when(cancelledAt, clock)
                    : _when(deliveredAt, clock),
              ),
              RiderStatementRow(
                icon: Icons.where_to_vote_outlined,
                label: 'Delivery Address',
                value: dropAddress.trim().isEmpty
                    ? 'Address not available'
                    : dropAddress.trim(),
              ),
              ...extras,
            ],
          ),
        ),
        if (showEarning) ...[
          const SizedBox(height: 14),
          RiderStatementCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Earning Details',
            child: Column(
              children: [
                if (hasSnapshot || tripFare != null)
                  RiderStatementRow(
                    icon: Icons.currency_rupee_rounded,
                    label: 'Trip Fare',
                    value: _money(tripFare),
                  ),
                if (hasSnapshot || riderAmount != null)
                  RiderStatementRow(
                    icon: Icons.currency_rupee_rounded,
                    label: 'Partner Earning',
                    value: _money(riderAmount),
                  ),
                if (hasSnapshot || companyAmount != null)
                  RiderStatementRow(
                    icon: Icons.currency_rupee_rounded,
                    label: 'IDHAR UDHAR Amount',
                    value: _money(companyAmount),
                  ),
                if (customerBill != null)
                  RiderStatementRow(
                    icon: Icons.receipt_outlined,
                    label: 'Customer bill',
                    value: formatInr(customerBill!),
                  ),
                if (showHighlight) ...[
                  const SizedBox(height: 10),
                  _EarningHighlight(amount: riderAmount!),
                ] else if (hasSnapshot && cancelled && riderAmount != null) ...[
                  RiderStatementRow(
                    icon: Icons.payments_outlined,
                    label: 'Your earning',
                    value: formatInr(riderAmount!),
                    emphasize: true,
                  ),
                ],
              ],
            ),
          ),
        ],
        if (showSettlement) ...[
          const SizedBox(height: 14),
          RiderStatementCard(
            icon: Icons.account_balance_rounded,
            title: 'Settlement Details',
            child: Column(
              children: [
                if (!hasSnapshot)
                  RiderStatementRow(
                    icon: Icons.payments_outlined,
                    label: 'Payment Type',
                    value: paymentLabel!.trim(),
                  )
                else if (cash) ...[
                  RiderStatementRow(
                    icon: Icons.payments_outlined,
                    label: 'Cash Collected',
                    value: _signed(cashCollected, credit: true),
                    valueColor: (cashCollected ?? 0) > 0
                        ? RiderColors.success
                        : RiderColors.textPrimary,
                  ),
                  RiderStatementRow(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Wallet',
                    value: _signed(
                      walletCompanyDebit == null ? null : -walletCompanyDebit!,
                      credit: false,
                    ),
                  ),
                ] else ...[
                  RiderStatementRow(
                    icon: Icons.credit_card_rounded,
                    label: 'Online Payment',
                    value: outcome == null ? 'Status not available' : null,
                    trailing: outcome == null
                        ? null
                        : RiderStatusPill(
                            label: outcome,
                            color: settlementStatus == 'PENDING'
                                ? const Color(0xFF157A3A)
                                : RiderColors.success,
                          ),
                  ),
                  RiderStatementRow(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Wallet Credit',
                    value: _signed(walletCredited, credit: true),
                    valueColor: (walletCredited ?? 0) > 0
                        ? RiderColors.success
                        : RiderColors.textPrimary,
                  ),
                  RiderStatementRow(
                    icon: Icons.receipt_long_outlined,
                    label: 'Applied To COD Due',
                    value: _money(codApplied),
                  ),
                ],
                if (hasSnapshot)
                  RiderStatementRow(
                    icon: Icons.verified_outlined,
                    label: 'Settlement',
                    value: settlementState == 'SETTLED'
                        ? 'Settled'
                        : settlementState == 'PENDING'
                            ? 'Pending'
                            : 'Not available',
                  ),
                if (hasSnapshot && cash && outcome != null)
                  RiderStatementRow(
                    icon: Icons.info_outline_rounded,
                    label: 'Cash',
                    trailing: RiderStatusPill(
                      label: outcome,
                      color: RiderColors.success,
                    ),
                  ),
              ],
            ),
          ),
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

  static String _money(double? amount) {
    if (amount == null) {
      return '—';
    }
    return formatInr(amount);
  }

  static String _signed(double? amount, {required bool credit}) {
    if (amount == null) {
      return '—';
    }
    if (credit && amount > 0) {
      return '+${formatInr(amount)}';
    }
    return formatInr(amount);
  }
}

class _EarningHighlight extends StatelessWidget {
  const _EarningHighlight({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F6F3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: RiderColors.primary,
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your Earning',
              style: RiderTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            formatInr(amount),
            style: RiderTextStyles.title.copyWith(
              color: RiderColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
