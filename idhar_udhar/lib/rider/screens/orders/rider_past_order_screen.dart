import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/api/wallet_api.dart';
import 'package:idhar_udhar/shared/format/inr_format.dart';

import '../../features/orders/rider_order_board.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_scaffold.dart';
import 'rider_trip_statement.dart';

class _PastTrip {
  const _PastTrip({
    required this.order,
    this.tripFare,
    this.riderAmount,
    this.paymentLabel,
    this.customerBill,
    this.earning,
  });

  final ApiOrder order;
  final double? tripFare;
  final double? riderAmount;
  final String? paymentLabel;
  final double? customerBill;
  final RiderEarningRow? earning;
}

class RiderPastOrderScreen extends ConsumerStatefulWidget {
  const RiderPastOrderScreen({required this.orderId, super.key});

  final String orderId;

  @override
  ConsumerState<RiderPastOrderScreen> createState() =>
      _RiderPastOrderScreenState();
}

class _RiderPastOrderScreenState extends ConsumerState<RiderPastOrderScreen> {
  late Future<_PastTrip> _order;

  @override
  void initState() {
    super.initState();
    _order = _load();
  }

  Future<_PastTrip> _load() async {
    final String id = widget.orderId.trim();
    if (id.isEmpty) {
      throw const ApiException(
        code: 'ORDER_ID',
        message: 'This order has no id.',
      );
    }
    final ApiOrder order = await ref.read(riderApiProvider).getOrder(id);
    double? fare = order.tripFare;
    double? earning = order.riderAmount;
    RiderEarningRow? earningRow;
    try {
      final List<RiderEarningRow> rows =
          await ref.read(walletApiProvider).earnings();
      for (final RiderEarningRow row in rows) {
        if (row.orderId.trim() == id) {
          fare ??= row.tripFare;
          earning ??= row.riderAmount;
          earningRow = row;
          break;
        }
      }
    } catch (_) {}
    String? paymentLabel;
    double? customerBill;
    try {
      final ApiOrderPaymentView? view =
          await ref.read(riderApiProvider).getOrderPayment(id);
      final ApiPaymentPlan? plan = view?.plan;
      final ApiPaymentResponsibility? responsibility = view?.responsibility;
      if (view != null && plan != null && view.hasAllocation) {
        paymentLabel = paymentMethodLabel(
          cash: plan.customerPlannedCash + plan.receiverPlannedCash,
          online: plan.customerPlannedOnline + plan.receiverPlannedOnline,
        );
      }
      if (responsibility != null && responsibility.applicableBillTotal > 0) {
        customerBill = responsibility.applicableBillTotal;
      }
    } catch (_) {}
    return _PastTrip(
      order: order,
      tripFare: fare,
      riderAmount: earning,
      paymentLabel: paymentLabel,
      customerBill: customerBill,
      earning: earningRow,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RiderScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        backgroundColor: RiderColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Order Details',
          style: RiderTextStyles.title.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder<_PastTrip>(
        future: _order,
        builder: (BuildContext context, AsyncSnapshot<_PastTrip> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            final Object? error = snapshot.error;
            final String message = error is ApiException
                ? error.message
                : 'This order could not be loaded.';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(RiderSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      style: RiderTextStyles.body,
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: () => setState(() => _order = _load()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          return _PastBody(trip: snapshot.data!);
        },
      ),
    );
  }
}

class _PastBody extends StatelessWidget {
  const _PastBody({required this.trip});

  final _PastTrip trip;

  @override
  Widget build(BuildContext context) {
    final ApiOrder order = trip.order;
    final String status = historyStatusLabel(order.canonicalStatus);
    final bool cancelled = order.canonicalStatus == 'CANCELLED';
    final bool finished = order.canonicalStatus == 'DELIVERED' ||
        order.canonicalStatus == 'RESEND_COMPLETED';
    final String display = order.displayId.trim().isEmpty
        ? order.orderId
        : order.displayId.trim();
    final ApiStop? pickup = _stop(order, 'PICKUP');
    final ApiStop? drop = _stop(order, 'DROP');
    final String pickupAddress = _text(order.pickupAddress, pickup?.addressText);
    final String dropAddress = _text(order.dropAddress, drop?.addressText);
    final RiderEarningRow? earning = trip.earning;
    final String vehicle = (order.vehicleCategoryName ?? '').trim();
    final Color tone = cancelled
        ? RiderColors.error
        : finished
            ? const Color(0xFF157A3A)
            : RiderColors.primary;
    final Color wash = cancelled
        ? const Color(0xFFFDECEC)
        : finished
            ? const Color(0xFFE7F8EE)
            : const Color(0xFFE7F4F7);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (status.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: wash,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tone.withValues(alpha: 0.28)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cancelled
                        ? Icons.cancel_rounded
                        : finished
                            ? Icons.check_circle_rounded
                            : Icons.info_rounded,
                    size: 16,
                    color: tone,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    status,
                    style: RiderTextStyles.caption.copyWith(
                      color: tone,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        RiderTripStatement(
          crn: order.crn,
          tripAt: order.createdAt,
          pickupAt: pickup?.arrivedAt ?? pickup?.completedAt,
          pickupAddress: pickupAddress,
          deliveredAt: cancelled
              ? null
              : drop?.completedAt ?? drop?.arrivedAt,
          dropAddress: dropAddress,
          cancelled: cancelled,
          completed: finished,
          cancelledAt: cancelled ? order.updatedAt : null,
          tripFare: earning?.tripFare ?? trip.tripFare,
          riderAmount: earning?.riderAmount ?? trip.riderAmount,
          companyAmount: earning?.companyAmount,
          hasSnapshot: earning != null,
          paymentLabel: trip.paymentLabel,
          customerBill: trip.customerBill,
          settlementStatus: earning?.settlementStatus,
          settlementState: earning?.settlementState,
          cashCollected: earning?.cashCollected,
          walletCredited: earning?.walletCredited,
          codApplied: earning?.codApplied,
          walletCompanyDebit: earning?.walletCompanyDebit,
          extras: [
            RiderStatementRow(
              icon: Icons.confirmation_number_outlined,
              label: 'Order ID',
              trailing: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      display,
                      textAlign: TextAlign.end,
                      style: RiderTextStyles.bodyMedium.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy order id',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: display));
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                  ),
                ],
              ),
            ),
            if (vehicle.isNotEmpty)
              RiderStatementRow(
                icon: Icons.two_wheeler_rounded,
                label: 'Vehicle',
                value: vehicle,
              ),
            if (order.distanceKm != null)
              RiderStatementRow(
                icon: Icons.route_rounded,
                label: 'Distance',
                value: '${order.distanceKm!.toStringAsFixed(1)} km',
              ),
            if (order.packageWeightKg != null)
              RiderStatementRow(
                icon: Icons.inventory_2_outlined,
                label: 'Package weight',
                value: '${order.packageWeightKg} kg',
              ),
            if (order.waitingAmount != null)
              RiderStatementRow(
                icon: Icons.hourglass_bottom_rounded,
                label: 'Waiting charge',
                value: formatInr(order.waitingAmount!),
              ),
            if (_text(pickup?.contactName, order.customerName).isNotEmpty)
              RiderStatementRow(
                icon: Icons.person_outline_rounded,
                label: 'Pickup contact',
                value: _text(pickup?.contactName, order.customerName),
              ),
            if (_text(pickup?.contactPhone, order.customerPhone).isNotEmpty)
              RiderStatementRow(
                icon: Icons.phone_outlined,
                label: 'Pickup phone',
                value: _text(pickup?.contactPhone, order.customerPhone),
              ),
            if (_text(drop?.contactName, null).isNotEmpty)
              RiderStatementRow(
                icon: Icons.person_outline_rounded,
                label: 'Delivery contact',
                value: _text(drop?.contactName, null),
              ),
            if (_text(drop?.contactPhone, null).isNotEmpty)
              RiderStatementRow(
                icon: Icons.phone_outlined,
                label: 'Delivery phone',
                value: _text(drop?.contactPhone, null),
              ),
          ],
        ),
      ],
    );
  }
}

ApiStop? _stop(ApiOrder order, String type) {
  for (final ApiStop stop in order.stops) {
    if (stop.stopType.toUpperCase() == type) {
      return stop;
    }
  }
  return null;
}

String _text(String? preferred, String? fallback) {
  final String first = (preferred ?? '').trim();
  if (first.isNotEmpty) {
    return first;
  }
  return (fallback ?? '').trim();
}
