import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';
import 'package:idhar_udhar/shared/business/business.dart';
import 'package:idhar_udhar/shared/maps/maps.dart';
import 'package:intl/intl.dart';

import '../../data/dummy/dummy_rider_repository.dart';
import '../../data/local/rider_prefs.dart';
import '../../data/location/rider_location_publisher.dart';
import '../../data/models/rider_order.dart';
import '../../features/navigation/arrived_drop_view.dart';
import '../../features/navigation/drop_summary_view.dart';
import '../../features/navigation/pickup_wait_view.dart';
import '../../features/navigation/receiver_action_sheet.dart';
import '../../features/navigation/rider_order_details_sheet.dart';
import '../../features/navigation/waiting_clock.dart';
import '../../features/orders/external_navigation.dart';
import '../../features/orders/rider_nav_overlay.dart';
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

enum _TripChrome { pickupNav, waiting, dropNav, dropSummary, legacy }

enum _CashGate { collect, skip, blocked }

class _CashDue {
  const _CashDue._(this.gate, this.amount);

  const _CashDue.collect(double amount) : this._(_CashGate.collect, amount);

  static const _CashDue skip = _CashDue._(_CashGate.skip, 0);
  static const _CashDue blocked = _CashDue._(_CashGate.blocked, 0);

  final _CashGate gate;
  final double amount;
}

/// Planned cash still to collect. Uses the payment bill and allocation,
/// not the trip fare and not the payment-status label. Inconsistent or
/// missing amounts block completion.
_CashDue _cashDue(RiderOrder order) {
  final List<double> amounts = <double>[
    order.tripAmount,
    order.paymentBill,
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
  final double bill = FareEngine.round2(order.paymentBill);
  if (customerAllocated != customerDue || receiverAllocated != receiverDue) {
    return _CashDue.blocked;
  }
  if (FareEngine.round2(customerDue + receiverDue) != bill) {
    return _CashDue.blocked;
  }
  final double cash =
      FareEngine.round2(order.customerCash + order.receiverCash);
  final double online = FareEngine.round2(
    order.customerOnline + order.receiverOnline,
  );
  if (cash > 0) {
    return _CashDue.collect(cash);
  }
  if (online > 0 || bill == 0) {
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

class _ActiveDeliveryScreenState extends ConsumerState<ActiveDeliveryScreen>
    with WidgetsBindingObserver {
  final RiderStatusAdvance _statusAdvance = RiderStatusAdvance();
  bool _receiverBusy = false;
  bool _cashBusy = false;
  bool _actionBusy = false;
  bool _completionOpened = false;
  bool _dropSummaryOpen = false;
  RiderOrder? _summaryOrder;
  String? _canonical;
  Timer? _waitTimer;
  int _waitPollTick = 0;
  PickupWaitSnapshot? _wait;
  DateTime? _waitFetchedAt;
  String? _waitError;
  bool _waitLoading = false;
  String? _paymentCacheOrderId;
  ApiOrderPaymentView? _paymentCache;
  final NavLaunchGate _navLaunchGate = NavLaunchGate();
  bool _externalNavArmed = false;
  bool _overlayDismissed = false;
  bool _overlayPermissionExplained = false;
  String? _launchedNavKey;
  String? _pendingOverlayAction;
  bool _phaseRestoreBusy = false;

  /// Waiting-charge API stays on an ~8s cadence while the clock ticks each second.
  static const int _waitPollEveryTicks = 8;

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
    RiderNavOverlay.bind(_onOverlayAction);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _prepareTripChrome();
      if (RiderNavSession.consumeRestore()) {
        unawaited(_restorePhaseFromServer());
      }
      final RiderOrder? order = ref.read(activeOrderProvider);
      if (order != null) {
        unawaited(_syncOverlay(order, ref.read(deliveryStatusProvider)));
        final AppLifecycleState? lifecycle =
            WidgetsBinding.instance.lifecycleState;
        if (!_overlayDismissed &&
            (lifecycle == AppLifecycleState.paused ||
                lifecycle == AppLifecycleState.hidden)) {
          unawaited(RiderNavOverlay.noteBackground());
        }
        unawaited(_explainOverlayPermissionOnce());
      }
      if (!MapsRuntime.isFlutterTest) {
        _publisher = RiderLocationPublisher(
          location: ref.read(deviceLocationServiceProvider),
          api: ref.read(riderApiProvider),
          tokens: ref.read(tokenStoreProvider),
        );
        unawaited(_publisher!.start());
      }
    });
  }

  @override
  void dispose() {
    RiderNavOverlay.unbind();
    final AppLifecycleState? lifecycle = WidgetsBinding.instance.lifecycleState;
    final bool leavingWhileVisible =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;
    if (leavingWhileVisible) {
      unawaited(RiderNavOverlay.disarm());
    }
    WidgetsBinding.instance.removeObserver(this);
    _waitTimer?.cancel();
    _publisher?.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || state == AppLifecycleState.inactive) {
      return;
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(RiderNavOverlay.noteForeground());
      final String? pending = _pendingOverlayAction;
      _pendingOverlayAction = null;
      if (pending == 'order_details') {
        unawaited(_openOverlayOrderDetails());
      } else if (!MapsRuntime.isFlutterTest) {
        unawaited(_consumeNativeOverlayAction());
      } else {
        unawaited(_restorePhaseFromServer());
      }
      final RiderOrder? order = ref.read(activeOrderProvider);
      if (order == null) {
        return;
      }
      if (_chrome(ref.read(deliveryStatusProvider)) == _TripChrome.waiting) {
        unawaited(_loadWait(order));
      }
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_externalNavArmed && !_overlayDismissed) {
        unawaited(RiderNavOverlay.noteBackground());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RiderOrder?>(activeOrderProvider,
        (RiderOrder? previous, RiderOrder? next) {
      if (!_externalNavArmed) {
        return;
      }
      final String? previousId = previous?.backendOrderId ?? previous?.id;
      final String? nextId = next?.backendOrderId ?? next?.id;
      if (next == null || previousId != nextId) {
        RiderNavSession.clear();
        unawaited(_stopExternalOverlay());
      }
    });
    ref.listen<DeliveryLifecycleStatus>(
      deliveryStatusProvider,
      (DeliveryLifecycleStatus? previous, DeliveryLifecycleStatus next) {
        if (!_externalNavArmed) {
          return;
        }
        final RiderOrder? current = ref.read(activeOrderProvider);
        if (current == null || riderOverlayShouldStop(next)) {
          RiderNavSession.clear();
          unawaited(_stopExternalOverlay());
          return;
        }
        unawaited(_syncOverlay(current, next));
      },
    );
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
    final _TripChrome chrome = _chrome(status);
    if (chrome != _TripChrome.legacy) {
      return _tripScaffold(context, order, status, chrome);
    }
    final statuses = _happyPath.map((e) => e.label).toList();
    final int currentIndex =
        status == DeliveryLifecycleStatus.receiverUnavailable ||
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
          if (status == DeliveryLifecycleStatus.goingToDrop)
            Padding(
              padding: const EdgeInsets.only(bottom: RiderSpacing.sm),
              child: RiderSecondaryButton(
                label: 'Receiver not available?',
                onPressed: () => _openReceiverActionSheet(order),
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
                unawaited(rememberLiveOrderId(null));
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
                  if (status == DeliveryLifecycleStatus.receiverUnavailable ||
                      status == DeliveryLifecycleStatus.parcelAtCompanyOffice)
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

  Widget _tripScaffold(
    BuildContext context,
    RiderOrder order,
    DeliveryLifecycleStatus status,
    _TripChrome chrome,
  ) {
    if (chrome == _TripChrome.dropSummary) {
      return _dropSummaryScaffold(order);
    }
    if (chrome == _TripChrome.waiting) {
      final int? elapsed = _displayedElapsed();
      return Scaffold(
        backgroundColor: RiderColors.background,
        body: PickupWaitView(
          freeMinutes: _wait?.initialWaitingMinutes ?? 0,
          elapsedSeconds: elapsed,
          rulesLoaded: _wait?.hasWaitingRules ?? false,
          rateAvailable: _wait == null || _wait!.hasWaitingRate,
          perMinute: _wait?.perMinute ?? '',
          amount: _displayedAmount(),
          amountSource: _wait?.amountSource ?? 'preview',
          arrivalMissing: _wait == null || _wait!.arrivalMissing,
          error: _waitError,
          primaryEnabled: !_actionBusy,
          orderTitle: order.id,
          pickupAddress: order.pickup,
          dropAddress: order.drop,
          packageLabel: order.packageLabel,
          distanceLabel: order.distanceLabel,
          etaLabel: order.etaLabel,
          onBack: Navigator.canPop(context)
              ? () => Navigator.of(context).pop()
              : null,
          onMenu: () => _openOrderMenu(order, status),
          onStartTrip: () => unawaited(_startTrip(order)),
        ),
      );
    }
    final bool toDrop = chrome == _TripChrome.dropNav;
    final bool tripStarted = status == DeliveryLifecycleStatus.goingToDrop;
    final String primaryLabel = toDrop && tripStarted
        ? 'ARRIVED AT DROP LOCATION'
        : toDrop
            ? 'START TRIP'
            : 'ARRIVED AT PICKUP LOCATION';
    final bool primaryEnabled = !_actionBusy && !_cashBusy && !_receiverBusy;
    if (toDrop && tripStarted) {
      return Scaffold(
        backgroundColor: RiderColors.background,
        body: ArrivedDropView(
          orderTitle: order.id,
          pickup: order.pickup,
          drop: order.drop,
          packageLabel: order.packageLabel,
          distanceLabel: order.distanceLabel,
          etaLabel: order.etaLabel,
          primaryEnabled: primaryEnabled,
          onBack: Navigator.canPop(context)
              ? () => Navigator.of(context).pop()
              : null,
          onMenu: () => _openOrderMenu(order, status),
          onNavigate: () => unawaited(_openExternalNav(order, status)),
          onReceiverUnavailable: () => _openReceiverActionSheet(order),
          onArrived: () => unawaited(_arriveAtDrop(order)),
        ),
      );
    }
    return Scaffold(
      backgroundColor: RiderColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(RiderSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Order ${order.id}',
                      style: RiderTextStyles.title,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Order details',
                    onPressed: () => _openOrderMenu(order, status),
                    icon: const Icon(Icons.menu_rounded),
                    color: RiderColors.textPrimary,
                  ),
                ],
              ),
              Text(status.label, style: RiderTextStyles.caption),
              const SizedBox(height: RiderSpacing.md),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!toDrop) ...<Widget>[
                        _PickupDestinationCard(address: order.pickup),
                        const SizedBox(height: RiderSpacing.md),
                      ] else ...<Widget>[
                        Text('Pickup', style: RiderTextStyles.caption),
                        Text(order.pickup, style: RiderTextStyles.bodyMedium),
                        const SizedBox(height: RiderSpacing.sm),
                      ],
                      Text('Drop', style: RiderTextStyles.caption),
                      Text(order.drop, style: RiderTextStyles.bodyMedium),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: RiderSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: RiderSpacing.sm),
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => unawaited(_openExternalNav(order, status)),
                    child: Text(
                      toDrop
                          ? 'Start navigation to drop'
                          : 'Start navigation to pickup',
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: primaryEnabled
                      ? () {
                          if (toDrop && tripStarted) {
                            unawaited(_arriveAtDrop(order));
                          } else if (toDrop) {
                            unawaited(_startTrip(order));
                          } else {
                            unawaited(_markArrivedPickup(order));
                          }
                        }
                      : null,
                  child: Text(primaryLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _prepareTripChrome() {
    final RiderOrder? order = ref.read(activeOrderProvider);
    if (!mounted || order == null) {
      return;
    }
    final DeliveryLifecycleStatus status = ref.read(deliveryStatusProvider);
    final _TripChrome chrome = _chrome(status);
    if (chrome == _TripChrome.waiting) {
      unawaited(_loadWait(order));
      _ensureWaitTimer();
      return;
    }
    if (chrome == _TripChrome.dropSummary || chrome == _TripChrome.legacy) {
      return;
    }
  }

  void _ensureWaitTimer() {
    if (MapsRuntime.isFlutterTest) {
      return;
    }
    _waitTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted ||
          _chrome(ref.read(deliveryStatusProvider)) != _TripChrome.waiting) {
        return;
      }
      final RiderOrder? order = ref.read(activeOrderProvider);
      setState(() {});
      _waitPollTick++;
      if (order != null && _waitPollTick >= _waitPollEveryTicks) {
        _waitPollTick = 0;
        unawaited(_loadWait(order));
      }
    });
  }

  int? _displayedElapsed() {
    final PickupWaitSnapshot? wait = _wait;
    final DateTime? arrival = wait?.arrivalAt;
    final DateTime? serverNow = wait?.serverNow;
    final DateTime? fetchedAt = _waitFetchedAt;
    if (wait == null ||
        arrival == null ||
        serverNow == null ||
        fetchedAt == null) {
      return wait?.elapsedSeconds;
    }
    return waitingElapsedSeconds(
      arrivalAt: arrival,
      serverNow: serverNow,
      fetchedAt: fetchedAt,
      now: DateTime.now().toUtc(),
      pickedUpAt: wait.pickedUpAt,
    );
  }

  /// Preview uses the snapshot rate and floored minutes. A saved assessment wins.
  String _displayedAmount() {
    final PickupWaitSnapshot? wait = _wait;
    if (wait != null && wait.hasWaitingRules && !wait.hasWaitingRate) {
      return '';
    }
    if (wait == null || !wait.hasWaitingRules || wait.arrivalMissing) {
      return '0.00';
    }
    if (wait.amountSource == 'assessed') {
      return wait.amount;
    }
    final int? elapsed = _displayedElapsed();
    if (elapsed == null) {
      return wait.amount;
    }
    return previewWaitingAmount(
          elapsedSeconds: elapsed,
          freeMinutes: wait.initialWaitingMinutes,
          perMinute: wait.perMinute,
        ) ??
        wait.amount;
  }

  Future<void> _loadWait(RiderOrder order) async {
    final String id = (order.backendOrderId ?? '').trim();
    if (id.isEmpty) {
      if (mounted && (_waitError == null || _waitError!.isEmpty)) {
        setState(() {
          _waitError = 'This trip is not linked to the server.';
        });
      }
      return;
    }
    if (_waitLoading) {
      return;
    }
    _waitLoading = true;
    try {
      final PickupWaitSnapshot snapshot =
          await ref.read(riderApiProvider).getPickupWait(id);
      if (!mounted) {
        return;
      }
      setState(() {
        _wait = snapshot;
        _waitFetchedAt = DateTime.now().toUtc();
        _waitError = null;
        final String vehicle = snapshot.vehicleCategoryName.trim();
        if (order.vehicleName.trim().isEmpty && vehicle.isNotEmpty) {
          ref.read(activeOrderProvider.notifier).state = RiderOrder(
            id: order.id,
            offerId: order.offerId,
            backendOrderId: order.backendOrderId,
            crn: order.crn,
            pickup: order.pickup,
            drop: order.drop,
            distanceKm: order.distanceKm,
            estimatedEarnings: order.estimatedEarnings,
            estimatedMinutes: order.estimatedMinutes,
            paymentMethod: order.paymentMethod,
            customerMaskedName: order.customerMaskedName,
            customerMaskedPhone: order.customerMaskedPhone,
            senderName: order.senderName,
            senderPhone: order.senderPhone,
            receiverName: order.receiverName,
            receiverPhone: order.receiverPhone,
            decisionSeconds: order.decisionSeconds,
            expiresAt: order.expiresAt,
            vehicleName: vehicle,
            packageLabel: order.packageLabel,
            tripAmount: order.tripAmount,
            paymentBill: order.paymentBill,
            riderAmount: order.riderAmount,
            companyShare: order.companyShare,
            officeDistanceKm: order.officeDistanceKm,
            officeCompensation: order.officeCompensation,
            customerResponsibility: order.customerResponsibility,
            receiverResponsibility: order.receiverResponsibility,
            customerPaid: order.customerPaid,
            receiverPaid: order.receiverPaid,
            customerOnline: order.customerOnline,
            customerCash: order.customerCash,
            receiverOnline: order.receiverOnline,
            receiverCash: order.receiverCash,
            paymentStatusLabel: order.paymentStatusLabel,
            pickupLatitude: order.pickupLatitude,
            pickupLongitude: order.pickupLongitude,
            dropLatitude: order.dropLatitude,
            dropLongitude: order.dropLongitude,
          );
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _waitError = error is ApiException
            ? waitingFailureMessage(code: error.code, message: error.message)
            : waitingFailureMessage();
      });
    } finally {
      _waitLoading = false;
    }
  }

  void _syncOverlayIfArmed(RiderOrder order) {
    if (!_externalNavArmed || !mounted) {
      return;
    }
    unawaited(_syncOverlay(order, ref.read(deliveryStatusProvider)));
  }

  Future<void> _openExternalNav(
    RiderOrder order,
    DeliveryLifecycleStatus status,
  ) async {
    final RiderNavTarget? target = riderNavTargetFor(
      orderId: order.backendOrderId ?? order.id,
      status: status,
      pickupLatitude: order.pickupLatitude,
      pickupLongitude: order.pickupLongitude,
      dropLatitude: order.dropLatitude,
      dropLongitude: order.dropLongitude,
    );
    if (target == null) {
      _navMessage(externalNavigationCoordinatesMessage);
      return;
    }
    final String key =
        '${target.orderId}|${target.toDrop}|${target.latitude}|${target.longitude}';
    if (_launchedNavKey == key || !_navLaunchGate.tryBegin()) {
      return;
    }
    bool? opened;
    try {
      final RiderNavigationLaunch? maps = riderNavigationLaunch(
        destinationLatitude: target.latitude,
        destinationLongitude: target.longitude,
      );
      if (maps == null) {
        _navMessage(externalNavigationCoordinatesMessage);
        return;
      }
      opened = await launchPreparedNavigation(maps.navigation, maps.fallback);
    } finally {
      _navLaunchGate.end();
    }
    if (opened != true) {
      if (opened == false) {
        _navMessage(externalNavigationFailedMessage);
      }
      return;
    }
    _launchedNavKey = key;
    _overlayDismissed = false;
    _externalNavArmed = true;
    RiderNavSession.noteHandoff();
    await _syncOverlay(order, status);
  }

  Future<void> _explainOverlayPermission() async {
    final bool? allow = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: RiderColors.surface,
          title: Text(
            'Trip controls over Maps',
            style: RiderTextStyles.title,
          ),
          content: Text(
            'Allow IDHAR UDHAR to show its icon over Google Maps. Arrival and trip actions stay in the app. Navigation still opens if you skip this.',
            style: RiderTextStyles.body,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );
    if (allow == true) {
      await RiderNavOverlay.openOverlaySettings();
    }
  }

  void _navMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _explainOverlayPermissionOnce() async {
    if (MapsRuntime.isFlutterTest || _overlayPermissionExplained || !mounted) {
      return;
    }
    final bool allowed = await RiderNavOverlay.canDrawOverlays();
    if (allowed || !mounted) {
      return;
    }
    _overlayPermissionExplained = true;
    await _explainOverlayPermission();
  }

  Future<void> _syncOverlay(
    RiderOrder order,
    DeliveryLifecycleStatus status,
  ) async {
    if (!mounted) {
      return;
    }
    if (riderOverlayShouldStop(status)) {
      await _stopExternalOverlay();
      return;
    }
    if (_overlayDismissed) {
      return;
    }
    _externalNavArmed = true;
    await RiderNavOverlay.arm();
  }

  Future<void> _stopExternalOverlay() async {
    _externalNavArmed = false;
    _launchedNavKey = null;
    await RiderNavOverlay.disarm();
  }

  void _onOverlayAction(String action) {
    if (!mounted) {
      return;
    }
    if (action == 'return_to_app' || riderOverlayStatusAction(action)) {
      return;
    }
    if (action == 'dismiss') {
      _overlayDismissed = true;
      unawaited(_stopExternalOverlay());
      return;
    }
    if (action != 'order_details') {
      return;
    }
    final AppLifecycleState? lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.hidden ||
        lifecycle == AppLifecycleState.inactive) {
      _pendingOverlayAction ??= action;
      return;
    }
    _openOverlayOrderDetails();
  }

  Future<void> _consumeNativeOverlayAction() async {
    final String? action = await RiderNavOverlay.consumeAction();
    if (!mounted) {
      return;
    }
    if (action == 'dismiss') {
      _overlayDismissed = true;
      await _stopExternalOverlay();
      return;
    }
    if (action == 'order_details') {
      await _openOverlayOrderDetails();
      return;
    }
    if (action == null ||
        action == 'return_to_app' ||
        riderOverlayStatusAction(action)) {
      await _restorePhaseFromServer();
    }
  }

  Future<void> _openOverlayOrderDetails() async {
    final RiderOrder? order = ref.read(activeOrderProvider);
    if (order == null || !mounted) {
      return;
    }
    await _openOrderMenu(order, ref.read(deliveryStatusProvider));
  }

  Future<void> _openOrderMenu(
    RiderOrder order,
    DeliveryLifecycleStatus status,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RiderColors.surface,
      builder: (BuildContext sheetContext) {
        final double top = MediaQuery.paddingOf(sheetContext).top;
        return Padding(
          padding: EdgeInsets.only(top: top + 12),
          child: RiderOrderDetailsSheet(
            order: order,
            statusLabel: status.label,
            waiting: _wait,
          ),
        );
      },
    );
    if (mounted) {
      await _restorePhaseFromServer();
    }
  }

  /// Reads the server order and shows that phase. Does not transition status
  /// and does not launch navigation.
  Future<void> _restorePhaseFromServer() async {
    if (_phaseRestoreBusy || _actionBusy || _cashBusy || _receiverBusy) {
      return;
    }
    final RiderOrder? order = ref.read(activeOrderProvider);
    final String orderId = (order?.backendOrderId ?? '').trim();
    if (order == null || orderId.isEmpty || !mounted) {
      return;
    }
    _phaseRestoreBusy = true;
    try {
      final String canonical =
          (await ref.read(riderApiProvider).getOrder(orderId)).canonicalStatus;
      if (!mounted) {
        return;
      }
      final DeliveryLifecycleStatus local = ref.read(deliveryStatusProvider);
      final DeliveryLifecycleStatus? restored = restoredDeliveryPhase(
        local: local,
        canonicalStatus: canonical,
      );
      if (restored == null) {
        return;
      }
      setState(() {
        _canonical = canonical;
        if (riderServerDropArrival(canonical) &&
            restored == DeliveryLifecycleStatus.goingToDrop) {
          _dropSummaryOpen = true;
        }
      });
      if (restored != local) {
        ref.read(deliveryStatusProvider.notifier).state = restored;
      }
      if (_chrome(ref.read(deliveryStatusProvider)) == _TripChrome.waiting) {
        _ensureWaitTimer();
        await _loadWait(order);
      }
    } catch (_) {
      // Keep the phase already on screen.
    } finally {
      _phaseRestoreBusy = false;
    }
  }

  Future<void> _markArrivedPickup(RiderOrder order) async {
    if (_actionBusy) {
      return;
    }
    _actionBusy = true;
    _syncOverlayIfArmed(order);
    try {
      await _advanceTo(DeliveryLifecycleStatus.arrivedAtPickup, order);
      if (!mounted) {
        return;
      }
      if (ref.read(deliveryStatusProvider) ==
          DeliveryLifecycleStatus.arrivedAtPickup) {
        _ensureWaitTimer();
        await _loadWait(order);
      }
    } finally {
      _actionBusy = false;
      _syncOverlayIfArmed(order);
    }
  }

  Future<void> _startTrip(RiderOrder order) async {
    if (_actionBusy) {
      return;
    }
    _actionBusy = true;
    _syncOverlayIfArmed(order);
    try {
      await _advanceTo(DeliveryLifecycleStatus.goingToDrop, order);
      if (!mounted) {
        return;
      }
      if (ref.read(deliveryStatusProvider) ==
          DeliveryLifecycleStatus.goingToDrop) {
        await _openExternalNav(order, DeliveryLifecycleStatus.goingToDrop);
      }
    } finally {
      _actionBusy = false;
      _syncOverlayIfArmed(order);
    }
  }

  Widget _dropSummaryScaffold(RiderOrder order) {
    final RiderOrder shown = _summaryFor(order);
    return DropSummaryView(
      orderId: shown.id.trim().isEmpty ? '—' : shown.id.trim(),
      pickup: shown.pickup,
      drop: shown.drop,
      distanceLabel: shown.distanceLabel,
      rideTimeLabel: shown.etaLabel,
      orderValueLabel: shown.tripAmount > 0 ? _rupees(shown.tripAmount) : '—',
      paymentMode: shown.paymentLabel,
      customerName: _customerName(shown),
      busy: _cashBusy || _actionBusy,
      onBack: () {
        if (_cashBusy || _actionBusy) {
          return;
        }
        setState(() => _dropSummaryOpen = false);
        _syncOverlayIfArmed(order);
      },
      onMarkDelivered: () => unawaited(_confirmCashBeforeDelivery(order)),
    );
  }

  RiderOrder _summaryFor(RiderOrder order) {
    final RiderOrder? summary = _summaryOrder;
    if (summary == null || summary.backendOrderId != order.backendOrderId) {
      return order;
    }
    return summary;
  }

  String _customerName(RiderOrder order) {
    for (final String value in <String>[
      order.senderName,
      order.receiverName,
      order.customerMaskedName,
    ]) {
      final String text = value.trim();
      if (text.isNotEmpty && text != '—') {
        return text;
      }
    }
    return '—';
  }

  Future<void> _refreshSummaryOrder(RiderOrder order) async {
    final RiderOrder? priced;
    try {
      priced = await _orderWithPayment(order);
    } catch (_) {
      return;
    }
    if (!mounted || !_dropSummaryOpen || priced == null) {
      return;
    }
    if (_cashDue(priced).gate == _CashGate.blocked) {
      return;
    }
    setState(() => _summaryOrder = priced);
  }

  Future<void> _arriveAtDrop(RiderOrder order) async {
    if (_actionBusy || _cashBusy || _receiverBusy) {
      return;
    }
    _actionBusy = true;
    _syncOverlayIfArmed(order);
    try {
      final String? orderId = order.backendOrderId;
      if (orderId == null || orderId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This trip is not linked to the server.'),
            ),
          );
        }
        return;
      }
      final api = ref.read(riderApiProvider);
      final RiderStatusAdvanceOutcome? outcome =
          await _statusAdvance.runToStatus(
        targetStatus: 'NEAR_DROP',
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
      if (serverStatus != null) {
        setState(() => _canonical = serverStatus);
        final DeliveryLifecycleStatus? synced =
            OrderMapper.tryRiderLifecycle(serverStatus);
        if (synced != null) {
          ref.read(deliveryStatusProvider.notifier).state = synced;
        }
      }
      if (!outcome.completed || outcome.failure != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(riderStatusAdvanceMessage(outcome))),
        );
        return;
      }
      if (serverStatus == 'NEAR_DROP' || serverStatus == 'DELIVERY_ATTEMPT') {
        setState(() => _dropSummaryOpen = true);
        unawaited(_refreshSummaryOrder(order));
        _syncOverlayIfArmed(order);
      }
    } finally {
      _actionBusy = false;
      _syncOverlayIfArmed(order);
    }
  }

  _TripChrome _chrome(DeliveryLifecycleStatus status) {
    switch (status) {
      case DeliveryLifecycleStatus.accepted:
      case DeliveryLifecycleStatus.goingToPickup:
        return _TripChrome.pickupNav;
      case DeliveryLifecycleStatus.arrivedAtPickup:
        return _TripChrome.waiting;
      case DeliveryLifecycleStatus.packagePickedUp:
        return _TripChrome.dropNav;
      case DeliveryLifecycleStatus.goingToDrop:
        if (_canonical == 'NEAR_DROP' || _canonical == 'DELIVERY_ATTEMPT') {
          return _dropSummaryOpen
              ? _TripChrome.dropSummary
              : _TripChrome.dropNav;
        }
        return _TripChrome.dropNav;
      case DeliveryLifecycleStatus.delivered:
      case DeliveryLifecycleStatus.receiverUnavailable:
      case DeliveryLifecycleStatus.parcelAtCompanyOffice:
        return _TripChrome.legacy;
    }
  }

  Future<void> _confirmCashBeforeDelivery(RiderOrder order) async {
    if (_cashBusy || _receiverBusy) {
      return;
    }
    _cashBusy = true;
    if (mounted) {
      setState(() {});
    }
    try {
      final RiderOrder? priced;
      try {
        priced = await _orderWithPayment(order);
      } on ApiException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message)),
          );
        }
        return;
      }
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
      var dialogClosed = false;
      final bool? confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          void close(bool value) {
            if (dialogClosed) {
              return;
            }
            dialogClosed = true;
            Navigator.of(dialogContext).pop(value);
          }

          return AlertDialog(
            backgroundColor: RiderColors.surface,
            shape: RoundedRectangleBorder(borderRadius: RiderRadius.lgAll),
            title: Text(
              'Collect Cash Amount',
              style: RiderTextStyles.title,
            ),
            content: Text(
              'Collect ${_rupees(due.amount)} from the customer. '
              'This amount is the cash still due on the order. '
              'Confirm only after you have collected it.',
              style: RiderTextStyles.body,
            ),
            actions: [
              TextButton(
                onPressed: () => close(false),
                child: Text(
                  'Cancel',
                  style: RiderTextStyles.bodyMedium.copyWith(
                    color: RiderColors.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => close(true),
                child: Text(
                  'Collected',
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
      if (mounted) {
        setState(() {});
      }
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
    final ApiOrderPaymentView? view =
        await ref.read(riderApiProvider).getOrderPayment(id);
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

  void _openReceiverActionSheet(RiderOrder order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: RiderColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return ReceiverActionSheet(
          order: order,
          onMarkUnavailable: () {
            unawaited(_confirmReceiverUnavailable(order));
          },
        );
      },
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(riderStatusAdvanceMessage(outcome))),
      );
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

class _PickupDestinationCard extends StatelessWidget {
  const _PickupDestinationCard({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    final String shown = address.trim().isEmpty ? '—' : address.trim();
    return Semantics(
      label: 'Going to Pickup. Pickup Location. $shown',
      child: RiderGlassCard(
        elevation: 2,
        padding: const EdgeInsets.all(RiderSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.storefront_rounded,
                  color: RiderColors.primary,
                ),
                const SizedBox(width: RiderSpacing.sm),
                Expanded(
                  child: Text(
                    'Going to Pickup',
                    style: RiderTextStyles.title,
                  ),
                ),
              ],
            ),
            const SizedBox(height: RiderSpacing.sm),
            Text('Pickup Location', style: RiderTextStyles.caption),
            const SizedBox(height: RiderSpacing.xs),
            Text(shown, style: RiderTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }
}
