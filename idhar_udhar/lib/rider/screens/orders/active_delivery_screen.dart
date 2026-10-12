import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/business/business.dart';
import 'package:idhar_udhar/shared/maps/maps.dart';
import 'package:intl/intl.dart';

import '../../data/dummy/dummy_rider_repository.dart';
import '../../features/orders/external_navigation.dart';
import '../../data/location/rider_location_publisher.dart';
import '../../data/models/rider_order.dart';
import '../../routing/rider_routes.dart';
import '../../state/rider_session.dart';
import '../../theme/rider_colors.dart';
import '../../theme/rider_spacing.dart';
import '../../theme/rider_text_styles.dart';
import '../../widgets/rider_contact_call.dart';
import '../../widgets/rider_delivery_map.dart';
import '../../widgets/rider_glass_card.dart';
import '../../widgets/rider_primary_button.dart';
import '../../widgets/rider_scaffold.dart';
import '../../widgets/rider_secondary_button.dart';
import '../../widgets/rider_verification_timeline.dart';

enum _MapLeg { pickup, drop }

enum _CashGate { collect, skip, blocked }

class _CashDue {
  const _CashDue._(this.gate, this.amount);

  const _CashDue.collect(double amount) : this._(_CashGate.collect, amount);

  static const _CashDue skip = _CashDue._(_CashGate.skip, 0);
  static const _CashDue blocked = _CashDue._(_CashGate.blocked, 0);

  final _CashGate gate;
  final double amount;
}

/// Planned cash still to collect. Uses the allocation fields, not the
/// payment-status label. Inconsistent or missing amounts block completion.
_CashDue _cashDue(RiderOrder order) {
  final List<double> amounts = <double>[
    order.tripAmount,
    order.customerResponsibility,
    order.receiverResponsibility,
    order.customerPaid,
    order.receiverPaid,
    order.customerOnline,
    order.customerCash,
    order.receiverOnline,
    order.receiverCash,
  ];
  for (final double value in amounts) {
    if (!value.isFinite || value < 0) {
      return _CashDue.blocked;
    }
  }
  final double customerAllocated = FareEngine.round2(
    order.customerOnline + order.customerCash,
  );
  final double receiverAllocated = FareEngine.round2(
    order.receiverOnline + order.receiverCash,
  );
  final double customerDue = FareEngine.round2(order.customerResponsibility);
  final double receiverDue = FareEngine.round2(order.receiverResponsibility);
  final double trip = FareEngine.round2(order.tripAmount);
  if (customerAllocated != customerDue || receiverAllocated != receiverDue) {
    return _CashDue.blocked;
  }
  if (FareEngine.round2(customerDue + receiverDue) != trip) {
    return _CashDue.blocked;
  }
  final double cash = FareEngine.round2(order.customerCash + order.receiverCash);
  final double online = FareEngine.round2(
    order.customerOnline + order.receiverOnline,
  );
  if (cash > 0) {
    return _CashDue.collect(cash);
  }
  if (order.paymentMethod == RiderOrderPaymentMethod.online && online > 0) {
    return _CashDue.skip;
  }
  return _CashDue.blocked;
}

String _rupees(double amount) {
  final bool whole = amount == amount.roundToDouble();
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: whole ? 0 : 2,
  ).format(amount);
}

class ActiveDeliveryScreen extends ConsumerStatefulWidget {
  const ActiveDeliveryScreen({super.key});

  @override
  ConsumerState<ActiveDeliveryScreen> createState() =>
      _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends ConsumerState<ActiveDeliveryScreen> {
  final RiderStatusAdvance _statusAdvance = RiderStatusAdvance();
  bool _receiverBusy = false;
  bool _cashBusy = false;
  bool _completionOpened = false;
  String? _paymentCacheOrderId;
  ApiOrderPaymentView? _paymentCache;

  static const List<DeliveryLifecycleStatus> _happyPath = [
    DeliveryLifecycleStatus.accepted,
    DeliveryLifecycleStatus.goingToPickup,
    DeliveryLifecycleStatus.arrivedAtPickup,
    DeliveryLifecycleStatus.packagePickedUp,
    DeliveryLifecycleStatus.goingToDrop,
    DeliveryLifecycleStatus.delivered,
  ];

  RiderLocationPublisher? _publisher;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _publisher = RiderLocationPublisher(
        location: ref.read(deviceLocationServiceProvider),
        api: ref.read(riderApiProvider),
      )..start();
    });
  }

  @override
  void dispose() {
    _publisher?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final RiderOrder? order = ref.watch(activeOrderProvider);
    if (order == null) {
      return RiderScaffold(
        appBar: AppBar(
          title: const Text('Delivery'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go(RiderRoutes.dashboard),
          ),
        ),
        body: Center(
          child: Text(
            'No active order.',
            style: RiderTextStyles.caption,
          ),
        ),
      );
    }
    final status = ref.watch(deliveryStatusProvider);
    final statuses = _happyPath.map((e) => e.label).toList();
    final int currentIndex = status ==
                DeliveryLifecycleStatus.receiverUnavailable ||
            status == DeliveryLifecycleStatus.parcelAtCompanyOffice
        ? _happyPath.indexOf(DeliveryLifecycleStatus.goingToDrop)
        : _happyPath.indexOf(status);
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final bool done = status == DeliveryLifecycleStatus.delivered ||
        status == DeliveryLifecycleStatus.parcelAtCompanyOffice;
    final CompanyOffice office = PlatformRules.current.office;
    final CancellationQuote riderCancel = CancellationEngine.quote(
      actor: CancellationActor.rider,
      status: _canonicalFor(status),
      config: PlatformRules.current.cancellation,
    );

    return RiderScaffold(
      appBar: AppBar(
        title: Text(
          order.crn == null || order.crn!.isEmpty
              ? 'Order #${order.id}'
              : 'Order #${order.id}\nCRN ${order.crn}',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(RiderRoutes.dashboard),
        ),
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_mapLeg(status) != null)
            Padding(
              padding: const EdgeInsets.only(bottom: RiderSpacing.sm),
              child: RiderSecondaryButton(
                label: _mapLeg(status) == _MapLeg.pickup
                    ? 'Navigate to pickup'
                    : 'Navigate to drop',
                onPressed: () => _openMapNavigation(order, status),
              ),
            ),
          if (status == DeliveryLifecycleStatus.goingToDrop)
            Padding(
              padding: const EdgeInsets.only(bottom: RiderSpacing.sm),
              child: RiderSecondaryButton(
                label: 'Receiver Unavailable',
                destructive: true,
                onPressed: () => _confirmReceiverUnavailable(order),
              ),
            ),
          if (!done && riderCancel.allowed)
            Padding(
              padding: const EdgeInsets.only(bottom: RiderSpacing.sm),
              child: RiderSecondaryButton(
                label: riderCancel.fee == 0
                    ? 'Cancel trip (₹0)'
                    : 'Cancel trip (₹${riderCancel.fee.toStringAsFixed(0)})',
                destructive: true,
                onPressed: () async {
                  // Rider cancel of an assigned trip is not a customer cancel.
                  // Do not mutate local wallet; clear only after server work exists.
                  final String? orderId = order.backendOrderId;
                  if (orderId == null || orderId.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'This trip is not linked to the server and cannot be cancelled here.',
                          ),
                        ),
                      );
                    }
                    return;
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Rider trip cancellation must be handled by support or a server cancel API.',
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          if (!done && !riderCancel.allowed)
            Padding(
              padding: const EdgeInsets.only(bottom: RiderSpacing.sm),
              child: Text(
                riderCancel.message,
                textAlign: TextAlign.center,
                style: RiderTextStyles.caption,
              ),
            ),
          RiderPrimaryButton(
            label: done ? 'Back to Dashboard' : status.actionLabel,
            onPressed: () async {
              if (done) {
                ref.read(activeOrderProvider.notifier).state = null;
                ref.read(deliveryStatusProvider.notifier).state =
                    DeliveryLifecycleStatus.accepted;
                context.go(RiderRoutes.dashboard);
                return;
              }
              final next = status.next;
              if (next == null) {
                return;
              }
              if (next == DeliveryLifecycleStatus.delivered) {
                await _confirmCashBeforeDelivery(order);
                return;
              }
              await _advanceTo(next, order);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RiderDeliveryMap(order: order, status: status),
            const SizedBox(height: RiderSpacing.lg),
            RiderGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RiderContactCall(
                    label: 'Sender',
                    name: order.senderName.trim().isEmpty
                        ? order.customerMaskedName
                        : order.senderName,
                    phone: order.senderPhone,
                  ),
                  const SizedBox(height: RiderSpacing.lg),
                  RiderContactCall(
                    label: 'Receiver',
                    name: order.receiverName,
                    phone: order.receiverPhone,
                  ),
                ],
              ),
            ),
            const SizedBox(height: RiderSpacing.lg),
            RiderGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    done ? 'Delivery update' : 'Active delivery',
                    style: RiderTextStyles.title,
                  ),
                  const SizedBox(height: RiderSpacing.sm),
                  Text(
                    '${order.pickup} → ${order.drop}',
                    style: RiderTextStyles.caption,
                  ),
                  const SizedBox(height: RiderSpacing.md),
                  Text(
                    currency.format(order.estimatedEarnings),
                    style: RiderTextStyles.heading.copyWith(
                      color: RiderColors.primary,
                    ),
                  ),
                  const SizedBox(height: RiderSpacing.md),
                  _moneyRow('Trip Amount', order.tripAmount, currency),
                  _moneyRow(
                    'Customer',
                    order.customerResponsibility,
                    currency,
                  ),
                  _moneyRow(
                    'Receiver',
                    order.receiverResponsibility,
                    currency,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: RiderSpacing.sm),
                    child: Row(
                      children: [
                        Text(
                          'Payment status',
                          style: RiderTextStyles.caption,
                        ),
                        const Spacer(),
                        Text(
                          order.paymentStatusLabel,
                          style: RiderTextStyles.body,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RiderSpacing.lg),
            if (status == DeliveryLifecycleStatus.receiverUnavailable ||
                status == DeliveryLifecycleStatus.parcelAtCompanyOffice)
              RiderGlassCard(
                child: Text(
                  'Take the parcel to the IDHAR UDHAR company office:\n${office.address}',
                  style: RiderTextStyles.body,
                ),
              ),
            if (status == DeliveryLifecycleStatus.receiverUnavailable ||
                status == DeliveryLifecycleStatus.parcelAtCompanyOffice)
              const SizedBox(height: RiderSpacing.lg),
            RiderGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _moneyRow('Trip Amount', order.tripAmount, currency),
                  _moneyRow('Rider Amount', order.riderAmount, currency),
                  _moneyRow('IDHAR UDHAR', order.companyShare, currency),
                  if (status ==
                          DeliveryLifecycleStatus.receiverUnavailable ||
                      status ==
                          DeliveryLifecycleStatus.parcelAtCompanyOffice)
                    _moneyRow(
                      'Failed Delivery Office Compensation',
                      order.officeCompensation,
                      currency,
                    ),
                ],
              ),
            ),
            const SizedBox(height: RiderSpacing.lg),
            RiderDeliveryStepper(
              current: currentIndex < 0 ? 0 : currentIndex,
              statuses: statuses,
            ),
            const SizedBox(height: RiderSpacing.lg),
            if (!done)
              RiderGlassCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: RiderColors.primary,
                    ),
                    const SizedBox(width: RiderSpacing.md),
                    Expanded(
                      child: Text(
                        status == DeliveryLifecycleStatus.goingToDrop
                            ? 'Mark delivered, or Receiver Unavailable if nobody is at the drop.'
                            : 'Tap the action below to advance the delivery status.',
                        style: RiderTextStyles.caption,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openMapNavigation(RiderOrder order, DeliveryLifecycleStatus status) {
    final _MapLeg? leg = _mapLeg(status);
    if (leg == null) {
      return;
    }
    final bool pickup = leg == _MapLeg.pickup;
    openRiderExternalNavigation(
      context,
      latitude: pickup ? order.pickupLatitude : order.dropLatitude,
      longitude: pickup ? order.pickupLongitude : order.dropLongitude,
    );
  }

  Future<void> _confirmCashBeforeDelivery(RiderOrder order) async {
    if (_cashBusy || _receiverBusy) {
      return;
    }
    _cashBusy = true;
    try {
      final RiderOrder? priced = await _orderWithPayment(order);
      if (!mounted) {
        return;
      }
      if (priced == null) {
        _showPaymentBlocked();
        return;
      }
      final _CashDue due = _cashDue(priced);
      if (due.gate == _CashGate.blocked) {
        _showPaymentBlocked();
        return;
      }
      if (due.gate == _CashGate.skip) {
        await _advanceTo(DeliveryLifecycleStatus.delivered, priced);
        return;
      }
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: RiderColors.surface,
            shape: RoundedRectangleBorder(borderRadius: RiderRadius.lgAll),
            title: Text(
              'Collect cash',
              style: RiderTextStyles.title,
            ),
            content: Text(
              'Collect ${_rupees(due.amount)}. Confirm that this cash was physically collected.',
              style: RiderTextStyles.body,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  'Cancel',
                  style: RiderTextStyles.bodyMedium.copyWith(
                    color: RiderColors.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  'Confirm Cash Collected',
                  style: RiderTextStyles.bodyMedium.copyWith(
                    color: RiderColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) {
        return;
      }
      await _advanceTo(DeliveryLifecycleStatus.delivered, priced);
    } finally {
      _cashBusy = false;
    }
  }

  Future<RiderOrder?> _orderWithPayment(RiderOrder order) async {
    final String id = (order.backendOrderId ?? '').trim();
    if (id.isEmpty) {
      return null;
    }
    final ApiOrderPaymentView? cached = _paymentCache;
    if (_paymentCacheOrderId == id && cached != null) {
      return OrderMapper.applyPaymentView(order: order, payment: cached);
    }
    final ApiOrderPaymentView? view;
    try {
      view = await ref.read(riderApiProvider).getOrderPayment(id);
    } catch (_) {
      return null;
    }
    if (view == null || !view.hasAllocation || view.orderId != id) {
      return null;
    }
    final RiderOrder? priced = OrderMapper.applyPaymentView(
      order: order,
      payment: view,
    );
    if (priced == null || _cashDue(priced).gate == _CashGate.blocked) {
      return priced;
    }
    _paymentCacheOrderId = id;
    _paymentCache = view;
    return priced;
  }

  void _showPaymentBlocked() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Payment details for this order are incomplete or inconsistent, so it was not marked delivered.',
        ),
      ),
    );
  }

  Future<void> _confirmReceiverUnavailable(RiderOrder order) async {
    if (_receiverBusy || _cashBusy) {
      return;
    }
    _receiverBusy = true;
    try {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: RiderColors.surface,
            shape: RoundedRectangleBorder(borderRadius: RiderRadius.lgAll),
            title: Text(
              'Receiver unavailable',
              style: RiderTextStyles.title,
            ),
            content: Text(
              'Confirming this records a failed delivery attempt because the receiver is unavailable.',
              style: RiderTextStyles.body,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  'Cancel',
                  style: RiderTextStyles.bodyMedium.copyWith(
                    color: RiderColors.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  'Confirm',
                  style: RiderTextStyles.bodyMedium.copyWith(
                    color: RiderColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) {
        return;
      }
      await _advanceTo(DeliveryLifecycleStatus.receiverUnavailable, order);
    } finally {
      _receiverBusy = false;
    }
  }

  Future<void> _advanceTo(
    DeliveryLifecycleStatus target,
    RiderOrder order,
  ) async {
    final String? orderId = order.backendOrderId;
    if (orderId == null || orderId.isEmpty) {
      ref.read(deliveryStatusProvider.notifier).state = target;
      return;
    }
    final api = ref.read(riderApiProvider);
    final RiderStatusAdvanceOutcome? outcome = await _statusAdvance.run(
      target: target,
      fetchStatus: () async => (await api.getOrder(orderId)).canonicalStatus,
      applyHop: (String hop) async {
        final updated = await api.transitionStatus(
          orderId: orderId,
          toStatus: hop,
        );
        return updated.canonicalStatus;
      },
    );
    if (!mounted || outcome == null) {
      return;
    }
    final String? serverStatus = outcome.canonicalStatus;
    final DeliveryLifecycleStatus? synced = serverStatus == null
        ? null
        : OrderMapper.tryRiderLifecycle(serverStatus);
    if (synced != null) {
      ref.read(deliveryStatusProvider.notifier).state = synced;
    }
    if (target == DeliveryLifecycleStatus.delivered &&
        outcome.completed &&
        serverStatus == 'DELIVERED') {
      if (_completionOpened) {
        return;
      }
      _completionOpened = true;
      await ref.read(riderSessionProvider.notifier).refreshWallet();
      if (!mounted) {
        return;
      }
      context.go(RiderRoutes.deliveryComplete);
      return;
    }
    if (!mounted) {
      return;
    }
    if (outcome.failure != null || !outcome.supported) {
      final String message = outcome.failure is ApiException
          ? (outcome.failure! as ApiException).message
          : 'That order update is not allowed yet.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  static _MapLeg? _mapLeg(DeliveryLifecycleStatus status) {
    switch (status) {
      case DeliveryLifecycleStatus.accepted:
      case DeliveryLifecycleStatus.goingToPickup:
      case DeliveryLifecycleStatus.arrivedAtPickup:
        return _MapLeg.pickup;
      case DeliveryLifecycleStatus.packagePickedUp:
      case DeliveryLifecycleStatus.goingToDrop:
        return _MapLeg.drop;
      case DeliveryLifecycleStatus.delivered:
      case DeliveryLifecycleStatus.receiverUnavailable:
      case DeliveryLifecycleStatus.parcelAtCompanyOffice:
        return null;
    }
  }

  static CanonicalOrderStatus _canonicalFor(DeliveryLifecycleStatus status) {
    switch (status) {
      case DeliveryLifecycleStatus.accepted:
        return CanonicalOrderStatus.assigned;
      case DeliveryLifecycleStatus.goingToPickup:
        return CanonicalOrderStatus.enRoutePickup;
      case DeliveryLifecycleStatus.arrivedAtPickup:
        return CanonicalOrderStatus.arrivedPickup;
      case DeliveryLifecycleStatus.packagePickedUp:
        return CanonicalOrderStatus.pickedUp;
      case DeliveryLifecycleStatus.goingToDrop:
        return CanonicalOrderStatus.inTransit;
      case DeliveryLifecycleStatus.delivered:
        return CanonicalOrderStatus.delivered;
      case DeliveryLifecycleStatus.receiverUnavailable:
        return CanonicalOrderStatus.receiverUnavailable;
      case DeliveryLifecycleStatus.parcelAtCompanyOffice:
        return CanonicalOrderStatus.parcelAtCompanyOffice;
    }
  }

  Widget _moneyRow(String label, double amount, NumberFormat currency) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RiderSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: RiderTextStyles.caption)),
          Text(currency.format(amount), style: RiderTextStyles.bodyMedium),
        ],
      ),
    );
  }
}
