import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/api/wallet_api.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/orders/rider_order_board.dart';
import 'rider_trip_statement.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_scaffold.dart';

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
        backgroundColor: RiderColors.background,
        foregroundColor: RiderColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Order Details',
          style: RiderTextStyles.title.copyWith(fontWeight: FontWeight.w700),
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
    final NumberFormat currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final DateFormat stamp = DateFormat('d MMM yyyy · h:mm a');
    final String status = historyStatusLabel(order.canonicalStatus);
    final bool cancelled = order.canonicalStatus == 'CANCELLED';
    final String display = order.displayId.trim().isEmpty
        ? order.orderId
        : order.displayId.trim();
    final ApiStop? pickup = _stop(order, 'PICKUP');
    final ApiStop? drop = _stop(order, 'DROP');
    final String pickupAddress = _text(order.pickupAddress, pickup?.addressText);
    final String dropAddress = _text(order.dropAddress, drop?.addressText);
    final bool finished = order.canonicalStatus == 'DELIVERED' ||
        order.canonicalStatus == 'RESEND_COMPLETED';
    final String vehicle = (order.vehicleCategoryName ?? '').trim();
    final bool hasTripFacts = order.distanceKm != null ||
        order.packageWeightKg != null ||
        vehicle.isNotEmpty ||
        order.waitingAmount != null ||
        ((order.crn ?? '').trim().isNotEmpty);
    final bool hasPayment = trip.paymentLabel != null ||
        trip.riderAmount != null ||
        trip.customerBill != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _HeaderCard(
          display: display,
          status: status,
          cancelled: cancelled,
          finished: finished,
          when: stamp.format(order.createdAt.toLocal()),
          updated: order.updatedAt == null
              ? null
              : stamp.format(order.updatedAt!.toLocal()),
          fare: trip.tripFare == null ? null : currency.format(trip.tripFare),
        ),
        const SizedBox(height: 8),
        _RouteCard(
          pickupName: _text(pickup?.contactName, order.customerName),
          pickupAddress: pickupAddress,
          pickupPhone: _text(pickup?.contactPhone, order.customerPhone),
          pickupPoint: pickup,
          dropName: _text(drop?.contactName, null),
          dropAddress: dropAddress,
          dropPhone: _text(drop?.contactPhone, null),
          dropPoint: drop,
        ),
        if (hasTripFacts) ...[
          const SizedBox(height: 8),
          _Panel(
            title: 'Trip',
            children: [
              if ((order.crn ?? '').trim().isNotEmpty)
                _Line(label: 'CRN', value: order.crn!.trim()),
              if (vehicle.isNotEmpty) _Line(label: 'Vehicle', value: vehicle),
              if (order.distanceKm != null)
                _Line(
                  label: 'Distance',
                  value: '${order.distanceKm!.toStringAsFixed(1)} km',
                ),
              if (order.packageWeightKg != null)
                _Line(
                  label: 'Package weight',
                  value: '${order.packageWeightKg} kg',
                ),
              if (order.waitingAmount != null)
                _Line(
                  label: 'Waiting charge',
                  value: currency.format(order.waitingAmount),
                ),
            ],
          ),
        ],
        if (trip.earning != null) ...[
          const SizedBox(height: 8),
          _Panel(
            title: 'Trip statement',
            children: [
              RiderTripStatement(
                crn: order.crn,
                tripAt: order.createdAt,
                pickupAt: pickup?.arrivedAt ?? pickup?.completedAt,
                pickupAddress: pickupAddress,
                deliveredAt: drop?.completedAt ?? drop?.arrivedAt,
                dropAddress: dropAddress,
                tripFare: trip.earning!.tripFare,
                riderAmount: trip.earning!.riderAmount,
                companyAmount: trip.earning!.companyAmount,
                settlementStatus: trip.earning!.settlementStatus,
                settlementState: trip.earning!.settlementState,
                cashCollected: trip.earning!.cashCollected,
                walletCredited: trip.earning!.walletCredited,
                codApplied: trip.earning!.codApplied,
                walletCompanyDebit: trip.earning!.walletCompanyDebit,
              ),
            ],
          ),
        ] else if (hasPayment) ...[
          const SizedBox(height: 8),
          _Panel(
            title: 'Payment',
            children: [
              if (trip.paymentLabel != null)
                _Line(label: 'Payment Type', value: trip.paymentLabel!),
              if (trip.riderAmount != null)
                _Line(
                  label: 'Rider earning',
                  value: currency.format(trip.riderAmount),
                ),
              if (trip.customerBill != null)
                _Line(
                  label: 'Customer bill',
                  value: currency.format(trip.customerBill),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.display,
    required this.status,
    required this.cancelled,
    required this.finished,
    required this.when,
    required this.updated,
    required this.fare,
  });

  final String display;
  final String status;
  final bool cancelled;
  final bool finished;
  final String when;
  final String? updated;
  final String? fare;

  @override
  Widget build(BuildContext context) {
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
    return _Panel(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order ID', style: RiderTextStyles.caption),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          display,
                          style: RiderTextStyles.title.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                ],
              ),
            ),
            if (status.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: wash,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: RiderTextStyles.caption.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(when, style: RiderTextStyles.caption),
                  if (updated != null)
                    Text(
                      'Last update $updated',
                      style: RiderTextStyles.caption,
                    ),
                ],
              ),
            ),
            if (fare != null)
              Text(
                fare!,
                style: RiderTextStyles.heading.copyWith(
                  fontSize: 20,
                  color: RiderColors.primary,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.pickupName,
    required this.pickupAddress,
    required this.pickupPhone,
    required this.pickupPoint,
    required this.dropName,
    required this.dropAddress,
    required this.dropPhone,
    required this.dropPoint,
  });

  final String pickupName;
  final String pickupAddress;
  final String pickupPhone;
  final ApiStop? pickupPoint;
  final String dropName;
  final String dropAddress;
  final String dropPhone;
  final ApiStop? dropPoint;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Route',
      children: [
        _StopBlock(
          label: 'Pickup',
          color: RiderColors.primary,
          name: pickupName,
          address: pickupAddress,
          phone: pickupPhone,
          point: pickupPoint,
          drawTail: true,
        ),
        _StopBlock(
          label: 'Drop',
          color: const Color(0xFFE08A12),
          name: dropName,
          address: dropAddress,
          phone: dropPhone,
          point: dropPoint,
          drawTail: false,
        ),
      ],
    );
  }
}

class _StopBlock extends StatelessWidget {
  const _StopBlock({
    required this.label,
    required this.color,
    required this.name,
    required this.address,
    required this.phone,
    required this.point,
    required this.drawTail,
  });

  final String label;
  final Color color;
  final String name;
  final String address;
  final String phone;
  final ApiStop? point;
  final bool drawTail;

  @override
  Widget build(BuildContext context) {
    final bool canMap =
        point != null && (point!.latitude != 0 || point!.longitude != 0);
    return IntrinsicHeight(
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 16,
          child: Column(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              if (drawTail)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.only(top: 2, bottom: 2),
                    color: const Color(0xFFD5E4E2),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: drawTail ? 8 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: RiderTextStyles.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (name.isNotEmpty)
                  Text(
                    name,
                    style: RiderTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (address.isNotEmpty)
                  Text(
                    address,
                    style: RiderTextStyles.body.copyWith(fontSize: 13, height: 1.35),
                  ),
                if (phone.isNotEmpty)
                  Text(phone, style: RiderTextStyles.caption),
                if (canMap)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _openMap(
                      point!.latitude,
                      point!.longitude,
                    ),
                    icon: const Icon(Icons.near_me_outlined, size: 14),
                    label: const Text('View on Map'),
                  ),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }

  Future<void> _openMap(double latitude, double longitude) async {
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3EEEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: RiderTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: RiderTextStyles.caption)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: RiderTextStyles.bodyMedium.copyWith(fontSize: 13),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
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
