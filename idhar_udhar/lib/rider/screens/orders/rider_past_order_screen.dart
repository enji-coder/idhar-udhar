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
  });

  final ApiOrder order;
  final double? tripFare;
  final double? riderAmount;
  final String? paymentLabel;
  final double? customerBill;
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
    try {
      final List<RiderEarningRow> rows =
          await ref.read(walletApiProvider).earnings();
      for (final RiderEarningRow row in rows) {
        if (row.orderId.trim() == id) {
          fare ??= row.tripFare;
          earning ??= row.riderAmount;
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return RiderScaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        RiderSpacing.screenH,
        RiderSpacing.md,
        RiderSpacing.screenH,
        RiderSpacing.xl,
      ),
      children: [
        _Banner(label: status, cancelled: cancelled),
        const SizedBox(height: RiderSpacing.md),
        _Panel(
          children: [
            _CopyRow(label: 'Order ID', value: display),
            if ((order.crn ?? '').trim().isNotEmpty)
              _Line(label: 'CRN', value: order.crn!.trim()),
            _Line(label: 'Date & Time', value: stamp.format(order.createdAt.toLocal())),
            if (order.updatedAt != null)
              _Line(
                label: 'Last update',
                value: stamp.format(order.updatedAt!.toLocal()),
              ),
            if (trip.paymentLabel != null)
              _Line(label: 'Payment Type', value: trip.paymentLabel!),
            if (trip.tripFare != null)
              _Line(label: 'Trip fare', value: currency.format(trip.tripFare)),
            if (trip.riderAmount != null)
              _Line(label: 'Rider earning', value: currency.format(trip.riderAmount)),
            if (trip.customerBill != null)
              _Line(
                label: 'Customer bill',
                value: currency.format(trip.customerBill),
              ),
          ],
        ),
        const SizedBox(height: RiderSpacing.md),
        _PlacePanel(
          title: 'Pickup Details',
          icon: Icons.storefront_outlined,
          accent: const Color(0xFF157A3A),
          name: _text(pickup?.contactName, order.customerName),
          address: pickupAddress,
          phone: _text(pickup?.contactPhone, order.customerPhone),
          point: pickup,
        ),
        const SizedBox(height: RiderSpacing.md),
        _PlacePanel(
          title: 'Drop Details',
          icon: Icons.location_on_outlined,
          accent: RiderColors.error,
          name: _text(drop?.contactName, null),
          address: dropAddress,
          phone: _text(drop?.contactPhone, null),
          point: drop,
        ),
        if (order.distanceKm != null || order.packageWeightKg != null) ...[
          const SizedBox(height: RiderSpacing.md),
          _Panel(
            title: 'Delivery Summary',
            children: [
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
            ],
          ),
        ],
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.label, required this.cancelled});

  final String label;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    final String shown = label.isEmpty ? 'Order' : label;
    return Container(
      padding: const EdgeInsets.all(RiderSpacing.md),
      decoration: BoxDecoration(
        color: cancelled ? const Color(0xFFFDECEC) : const Color(0xFFE7F8EE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            cancelled ? Icons.cancel_rounded : Icons.check_circle_rounded,
            color: cancelled ? RiderColors.error : const Color(0xFF157A3A),
          ),
          const SizedBox(width: RiderSpacing.sm),
          Expanded(
            child: Text(
              shown,
              style: RiderTextStyles.title.copyWith(
                color: cancelled ? RiderColors.error : const Color(0xFF157A3A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(RiderSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EEEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(title!, style: RiderTextStyles.title),
            const SizedBox(height: RiderSpacing.sm),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _PlacePanel extends StatelessWidget {
  const _PlacePanel({
    required this.title,
    required this.icon,
    required this.accent,
    required this.name,
    required this.address,
    required this.phone,
    required this.point,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final String name;
  final String address;
  final String phone;
  final ApiStop? point;

  @override
  Widget build(BuildContext context) {
    final bool canMap = point != null &&
        (point!.latitude != 0 || point!.longitude != 0);
    return _Panel(
      children: [
        Row(
          children: [
            Icon(icon, color: accent, size: 20),
            const SizedBox(width: RiderSpacing.sm),
            Expanded(child: Text(title, style: RiderTextStyles.title)),
          ],
        ),
        if (name.isNotEmpty) ...[
          const SizedBox(height: RiderSpacing.sm),
          Text(name, style: RiderTextStyles.bodyMedium),
        ],
        if (address.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(address, style: RiderTextStyles.body),
        ],
        if (phone.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(phone, style: RiderTextStyles.caption),
        ],
        if (canMap)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _openMap(point!.latitude, point!.longitude),
              icon: const Icon(Icons.near_me_outlined, size: 16),
              label: const Text('View on Map'),
            ),
          ),
      ],
    );
  }

  Future<void> _openMap(double latitude, double longitude) async {
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RiderSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: RiderTextStyles.caption),
          ),
          Flexible(
            child: Text(
              value,
              style: RiderTextStyles.bodyMedium,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Copy order id',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
          ),
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
      padding: const EdgeInsets.only(bottom: RiderSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: RiderTextStyles.caption)),
          const SizedBox(width: RiderSpacing.sm),
          Flexible(
            child: Text(
              value,
              style: RiderTextStyles.bodyMedium,
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
