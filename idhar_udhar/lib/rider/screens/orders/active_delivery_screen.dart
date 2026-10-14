import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/api_providers.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';
import 'package:idhar_udhar/shared/business/business.dart';
import 'package:idhar_udhar/shared/maps/maps.dart';
import 'package:intl/intl.dart';

import '../../data/dummy/dummy_rider_repository.dart';
import '../../data/location/rider_location_publisher.dart';
import '../../data/models/rider_order.dart';
import '../../features/navigation/navigation_speaker.dart';
import '../../features/navigation/pickup_wait_view.dart';
import '../../features/navigation/rider_order_details_sheet.dart';
import '../../features/navigation/route_guidance.dart';
import '../../features/navigation/trip_navigation_view.dart';
import '../../features/navigation/waiting_clock.dart';
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

enum _TripChrome { pickupNav, waiting, dropNav, legacy }

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

class _ActiveDeliveryScreenState extends ConsumerState<ActiveDeliveryScreen>
    with WidgetsBindingObserver {
  final RiderStatusAdvance _statusAdvance = RiderStatusAdvance();
  bool _receiverBusy = false;
  bool _cashBusy = false;
  bool _actionBusy = false;
  bool _completionOpened = false;
  String? _canonical;
  Timer? _waitTimer;
  Timer? _gpsTimer;
  PickupWaitSnapshot? _wait;
  DateTime? _waitFetchedAt;
  String? _waitError;
  bool _waitLoading = false;
  GuidedRoute? _guided;
  GeoPoint? _navHere;
  String? _navStatus;
  bool _routeRetry = false;
  String? _routeKey;
  int _routeToken = 0;
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
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _prepareTripChrome();
      if (!MapsRuntime.isFlutterTest) {
        _gpsTimer = Timer.periodic(const Duration(seconds: 8), (_) {
          final RiderOrder? order = ref.read(activeOrderProvider);
          final DeliveryLifecycleStatus status =
              ref.read(deliveryStatusProvider);
          if (order != null && _chrome(status) != _TripChrome.legacy) {
            if (_chrome(status) == _TripChrome.waiting) {
              unawaited(_loadWait(order));
            } else {
              unawaited(_refreshNavigation(order, status));
            }
          }
        });
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
    WidgetsBinding.instance.removeObserver(this);
    _waitTimer?.cancel();
    _gpsTimer?.cancel();
    _publisher?.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) {
      return;
    }
    final RiderOrder? order = ref.read(activeOrderProvider);
    if (order == null) {
      return;
    }
    final DeliveryLifecycleStatus status = ref.read(deliveryStatusProvider);
    if (_chrome(status) == _TripChrome.waiting) {
      unawaited(_loadWait(order));
      return;
    }
    if (_chrome(status) != _TripChrome.legacy) {
      unawaited(_refreshNavigation(order, status));
    }
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
    final _TripChrome chrome = _chrome(status);
    if (chrome != _TripChrome.legacy) {
      return _tripScaffold(context, order, status, chrome);
    }
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

  Widget _tripScaffold(
    BuildContext context,
    RiderOrder order,
    DeliveryLifecycleStatus status,
    _TripChrome chrome,
  ) {
    if (chrome == _TripChrome.waiting) {
      final int? elapsed = _displayedElapsed();
      return Scaffold(
        backgroundColor: RiderColors.background,
        body: PickupWaitView(
          clock: formatWaitingClock(elapsed),
          freeMinutes: _wait?.initialWaitingMinutes ?? 0,
          elapsedSeconds: elapsed,
          perMinute: _wait?.perMinute ?? '—',
          amount: _wait?.amount ?? '0.00',
          amountSource: _wait?.amountSource ?? 'preview',
          arrivalMissing: _wait == null || _wait!.arrivalMissing,
          error: _waitError,
          primaryEnabled: !_actionBusy,
          onMenu: () => _openOrderMenu(order, status),
          onStartTrip: () => unawaited(_startTrip(order)),
        ),
      );
    }
    final bool toDrop = chrome == _TripChrome.dropNav;
    final GuidanceBanner? banner = guidanceBanner(
      steps: _guided?.steps ?? const <RouteStep>[],
      position: _navHere,
    );
    final String remaining = _guided == null
        ? 'Route pending'
        : '${_guided!.route.distanceLabel} · ${_guided!.route.etaLabel}';
    final bool tripStarted = status == DeliveryLifecycleStatus.goingToDrop;
    return Scaffold(
      backgroundColor: RiderColors.background,
      body: TripNavigationView(
        map: EmbeddedGoogleMap(
          expanded: true,
          initial: _navHere ?? _stopPoint(order, toDrop) ?? MapsDefaults.cityCenter,
          markers: _navMarkers(order, toDrop),
          route: _guided?.route.points ?? const <GeoPoint>[],
          myLocationEnabled: true,
          follow: _navHere != null,
          accentColor: RiderColors.primary,
          borderColor: RiderColors.border,
          statusMessage: _navStatus,
        ),
        vehicleName: _vehicleName(order),
        instruction: banner?.instruction ??
            (toDrop ? 'Head to the drop location' : 'Head to the pickup location'),
        maneuverDistance: banner?.distanceLabel ?? '—',
        remainingLabel: remaining,
        primaryLabel: toDrop && tripStarted
            ? 'ARRIVED AT DROP LOCATION'
            : toDrop
                ? 'START TRIP'
                : 'ARRIVED AT PICKUP',
        primaryEnabled: !_actionBusy && !_cashBusy && !_receiverBusy,
        onPrimary: () {
          if (toDrop && tripStarted) {
            unawaited(_arriveAtDrop(order));
          } else if (toDrop) {
            unawaited(_startTrip(order));
          } else {
            unawaited(_markArrivedPickup(order));
          }
        },
        onMenu: () => _openOrderMenu(order, status),
        secondaryLabel: tripStarted ? 'Receiver Unavailable' : null,
        onSecondary: tripStarted
            ? () => unawaited(_confirmReceiverUnavailable(order))
            : null,
        statusMessage: _navStatus,
        onRetryRoute: _routeRetry ? () => unawaited(_retryRoute(order, status)) : null,
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
    if (chrome != _TripChrome.legacy) {
      unawaited(_refreshNavigation(order, status));
    }
  }

  void _ensureWaitTimer() {
    if (MapsRuntime.isFlutterTest) {
      return;
    }
    _waitTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          _chrome(ref.read(deliveryStatusProvider)) == _TripChrome.waiting) {
        setState(() {});
      }
    });
  }

  int? _displayedElapsed() {
    final PickupWaitSnapshot? wait = _wait;
    final DateTime? arrival = wait?.arrivalAt;
    final DateTime? serverNow = wait?.serverNow;
    final DateTime? fetchedAt = _waitFetchedAt;
    if (wait == null || arrival == null || serverNow == null || fetchedAt == null) {
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

  Future<void> _loadWait(RiderOrder order) async {
    final String id = (order.backendOrderId ?? '').trim();
    if (id.isEmpty || _waitLoading) {
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
            ? error.message
            : 'Waiting charges could not be loaded.';
      });
    } finally {
      _waitLoading = false;
    }
  }

  Future<void> _retryRoute(
    RiderOrder order,
    DeliveryLifecycleStatus status,
  ) async {
    _routeKey = null;
    await _refreshNavigation(order, status, force: true);
  }

  Future<void> _refreshNavigation(
    RiderOrder order,
    DeliveryLifecycleStatus status, {
    bool force = false,
  }) async {
    final int token = ++_routeToken;
    final bool toDrop = _chrome(status) == _TripChrome.dropNav;
    final GeoPoint? destination = _stopPoint(order, toDrop);
    final LocationResult result = await ref
        .read(deviceLocationServiceProvider)
        .currentLocation(requestPermission: true);
    if (!mounted || token != _routeToken) {
      return;
    }
    final GeoPoint? here = result.isOk && result.location != null
        ? GeoPoint(
            latitude: result.location!.latitude,
            longitude: result.location!.longitude,
          )
        : null;
    final String? problem = result.failure == null
        ? null
        : locationFailureMessage(result.failure!);
    if (destination == null || here == null) {
      setState(() {
        _navHere = here;
        _guided = destination == null ? null : _guided;
        _routeRetry = false;
        _navStatus = destination == null
            ? 'This stop does not have usable coordinates.'
            : (problem ?? 'Current location is unavailable.');
      });
      return;
    }
    final bool offRoute = _guided != null &&
        shouldRecalculateRoute(
          line: _guided!.route.points,
          position: here,
        );
    final String key =
        '${here.latitude.toStringAsFixed(3)},${here.longitude.toStringAsFixed(3)}>${destination.latitude.toStringAsFixed(3)},${destination.longitude.toStringAsFixed(3)}';
    if (!force && !offRoute && key == _routeKey && _guided != null) {
      setState(() => _navHere = here);
      final GuidanceBanner? banner = guidanceBanner(
        steps: _guided!.steps,
        position: here,
      );
      unawaited(_speakerCue(banner));
      return;
    }
    _routeKey = key;
    final RouteGuidanceResult guidance =
        await ref.read(routesServiceProvider).computeGuidance(
              origin: here,
              destination: destination,
            );
    if (!mounted || token != _routeToken) {
      return;
    }
    final GuidedRoute? guided = guidance.route;
    setState(() {
      _navHere = here;
      if (guided != null) {
        _guided = guided;
      }
      _routeRetry = guided == null;
      _navStatus = guided == null ? routeGuidanceMessage(guidance.kind) : problem;
    });
    unawaited(
      _speakerCue(
        guidanceBanner(
          steps: (guided ?? _guided)?.steps ?? const <RouteStep>[],
          position: here,
        ),
      ),
    );
  }

  Future<void> _speakerCue(GuidanceBanner? banner) async {
    if (MapsRuntime.isFlutterTest) {
      return;
    }
    // Speaker is created lazily so tests never touch the speech engine.
    _speaker ??= NavigationSpeaker();
    await _speaker!.cue(banner);
  }

  NavigationSpeaker? _speaker;

  String _vehicleName(RiderOrder order) {
    final String name = order.vehicleName.trim();
    if (name.isNotEmpty) {
      return name;
    }
    return _wait?.vehicleCategoryName.trim() ?? '';
  }

  GeoPoint? _stopPoint(RiderOrder order, bool toDrop) {
    final double? latitude = toDrop ? order.dropLatitude : order.pickupLatitude;
    final double? longitude =
        toDrop ? order.dropLongitude : order.pickupLongitude;
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return null;
    }
    return GeoPoint(latitude: latitude, longitude: longitude);
  }

  List<MapMarkerSpec> _navMarkers(RiderOrder order, bool toDrop) {
    final GeoPoint? stop = _stopPoint(order, toDrop);
    return <MapMarkerSpec>[
      if (_navHere != null)
        MapMarkerSpec(
          id: 'rider',
          point: _navHere!,
          hue: BitmapDescriptor.hueAzure,
          title: _vehicleName(order).isEmpty ? 'You' : _vehicleName(order),
        ),
      if (stop != null)
        MapMarkerSpec(
          id: toDrop ? 'drop' : 'pickup',
          point: stop,
          hue: toDrop ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange,
          title: toDrop ? 'Drop' : 'Pickup',
          snippet: toDrop ? order.drop : order.pickup,
        ),
    ];
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
        return RiderOrderDetailsSheet(
          order: order,
          statusLabel: status.label,
          waiting: _wait,
        );
      },
    );
  }

  Future<void> _markArrivedPickup(RiderOrder order) async {
    if (_actionBusy) {
      return;
    }
    _actionBusy = true;
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
    }
  }

  Future<void> _startTrip(RiderOrder order) async {
    if (_actionBusy) {
      return;
    }
    _actionBusy = true;
    try {
      await _advanceTo(DeliveryLifecycleStatus.goingToDrop, order);
      if (!mounted) {
        return;
      }
      if (_chrome(ref.read(deliveryStatusProvider)) == _TripChrome.dropNav) {
        _routeKey = null;
        await _refreshNavigation(order, DeliveryLifecycleStatus.goingToDrop);
      }
    } finally {
      _actionBusy = false;
    }
  }

  Future<void> _arriveAtDrop(RiderOrder order) async {
    if (_actionBusy || _cashBusy || _receiverBusy) {
      return;
    }
    _actionBusy = true;
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
      final RiderStatusAdvanceOutcome? outcome = await _statusAdvance.runToStatus(
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
      await _confirmCashBeforeDelivery(order);
    } finally {
      _actionBusy = false;
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
          return _TripChrome.legacy;
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
