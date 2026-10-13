import 'package:idhar_udhar/customer/core/data/mock/mock_data.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/rider/data/models/rider_order.dart';
import 'package:idhar_udhar/rider/push/rider_offer_rules.dart';

import 'orders_api.dart';
import 'rider_api.dart';

/// Result of one guarded delivery-status advance.
class RiderStatusAdvanceOutcome {
  const RiderStatusAdvanceOutcome({
    required this.supported,
    required this.completed,
    this.canonicalStatus,
    this.failure,
    this.hopsSent = const <String>[],
  });

  /// False when the server status is not on a legal path to the target.
  final bool supported;

  /// True only when every required hop succeeded, or none were required.
  final bool completed;

  /// Authoritative status when a fetch or hop returned one. Null if unknown.
  final String? canonicalStatus;

  final Object? failure;

  final List<String> hopsSent;
}

/// Sends only the hops still ahead of the server status.
///
/// A second call while one is running returns null and sends nothing.
class RiderStatusAdvance {
  bool _inFlight = false;

  Future<RiderStatusAdvanceOutcome?> run({
    required DeliveryLifecycleStatus target,
    required Future<String> Function() fetchStatus,
    required Future<String> Function(String hop) applyHop,
  }) async {
    if (_inFlight) {
      return null;
    }
    _inFlight = true;
    final List<String> sent = <String>[];
    try {
      final String serverStatus = await fetchStatus();
      final List<String>? hops = OrderMapper.remainingRiderHops(
        serverStatus: serverStatus,
        target: target,
      );
      if (hops == null) {
        return RiderStatusAdvanceOutcome(
          supported: false,
          completed: false,
          canonicalStatus: serverStatus,
        );
      }
      var status = serverStatus;
      for (final String hop in hops) {
        try {
          status = await applyHop(hop);
          sent.add(hop);
        } catch (error) {
          String? refreshed;
          try {
            refreshed = await fetchStatus();
          } catch (_) {
            refreshed = null;
          }
          return RiderStatusAdvanceOutcome(
            supported: true,
            completed: false,
            canonicalStatus: refreshed ?? status,
            failure: error,
            hopsSent: List<String>.unmodifiable(sent),
          );
        }
      }
      return RiderStatusAdvanceOutcome(
        supported: true,
        completed: true,
        canonicalStatus: status,
        hopsSent: List<String>.unmodifiable(sent),
      );
    } catch (error) {
      return RiderStatusAdvanceOutcome(
        supported: false,
        completed: false,
        failure: error,
      );
    } finally {
      _inFlight = false;
    }
  }
}

abstract final class OrderMapper {
  static OrderStatus toUiStatus(String canonical) {
    switch (canonical) {
      case 'CREATED':
      case 'SEARCHING':
      case 'OFFERED':
        return OrderStatus.searching;
      case 'ASSIGNED':
        return OrderStatus.assigned;
      case 'EN_ROUTE_PICKUP':
        return OrderStatus.arriving;
      case 'ARRIVED_PICKUP':
        return OrderStatus.arriving;
      case 'PICKED_UP':
        return OrderStatus.pickup;
      case 'IN_TRANSIT':
        return OrderStatus.inTransit;
      case 'NEAR_DROP':
      case 'DELIVERY_ATTEMPT':
        return OrderStatus.nearDestination;
      case 'DELIVERED':
      case 'RESEND_COMPLETED':
        return OrderStatus.delivered;
      case 'CANCELLED':
        return OrderStatus.cancelled;
      case 'RECEIVER_UNAVAILABLE':
      case 'FAILED_DELIVERY':
        return OrderStatus.failed;
      case 'PARCEL_AT_COMPANY_OFFICE':
        return OrderStatus.atCompanyOffice;
      case 'RESEND_REQUESTED':
      case 'RESEND_IN_PROGRESS':
        return OrderStatus.resendRequested;
      default:
        return OrderStatus.searching;
    }
  }

  static DeliveryLifecycleStatus toRiderLifecycle(String canonical) {
    switch (canonical) {
      case 'ASSIGNED':
        return DeliveryLifecycleStatus.accepted;
      case 'EN_ROUTE_PICKUP':
        return DeliveryLifecycleStatus.goingToPickup;
      case 'ARRIVED_PICKUP':
        return DeliveryLifecycleStatus.arrivedAtPickup;
      case 'PICKED_UP':
        return DeliveryLifecycleStatus.packagePickedUp;
      case 'IN_TRANSIT':
      case 'NEAR_DROP':
      case 'DELIVERY_ATTEMPT':
        return DeliveryLifecycleStatus.goingToDrop;
      case 'DELIVERED':
        return DeliveryLifecycleStatus.delivered;
      case 'RECEIVER_UNAVAILABLE':
      case 'FAILED_DELIVERY':
        return DeliveryLifecycleStatus.receiverUnavailable;
      case 'PARCEL_AT_COMPANY_OFFICE':
        return DeliveryLifecycleStatus.parcelAtCompanyOffice;
      default:
        return DeliveryLifecycleStatus.accepted;
    }
  }

  /// UI next-action → backend hop. Some UI taps chain more than one status.
  static List<String> riderStatusHops({
    required DeliveryLifecycleStatus from,
    required DeliveryLifecycleStatus to,
  }) {
    if (from == DeliveryLifecycleStatus.accepted &&
        to == DeliveryLifecycleStatus.goingToPickup) {
      return const <String>['EN_ROUTE_PICKUP'];
    }
    if (from == DeliveryLifecycleStatus.goingToPickup &&
        to == DeliveryLifecycleStatus.arrivedAtPickup) {
      return const <String>['ARRIVED_PICKUP'];
    }
    if (from == DeliveryLifecycleStatus.arrivedAtPickup &&
        to == DeliveryLifecycleStatus.packagePickedUp) {
      return const <String>['PICKED_UP'];
    }
    if (from == DeliveryLifecycleStatus.packagePickedUp &&
        to == DeliveryLifecycleStatus.goingToDrop) {
      return const <String>['IN_TRANSIT'];
    }
    if (from == DeliveryLifecycleStatus.goingToDrop &&
        to == DeliveryLifecycleStatus.delivered) {
      return const <String>['NEAR_DROP', 'DELIVERY_ATTEMPT', 'DELIVERED'];
    }
    if (from == DeliveryLifecycleStatus.goingToDrop &&
        to == DeliveryLifecycleStatus.receiverUnavailable) {
      return const <String>[
        'NEAR_DROP',
        'DELIVERY_ATTEMPT',
        'RECEIVER_UNAVAILABLE',
      ];
    }
    if (from == DeliveryLifecycleStatus.receiverUnavailable &&
        to == DeliveryLifecycleStatus.parcelAtCompanyOffice) {
      return const <String>['FAILED_DELIVERY', 'PARCEL_AT_COMPANY_OFFICE'];
    }
    return const <String>[];
  }

  static const List<String> _happyPathStatuses = <String>[
    'ASSIGNED',
    'EN_ROUTE_PICKUP',
    'ARRIVED_PICKUP',
    'PICKED_UP',
    'IN_TRANSIT',
    'NEAR_DROP',
    'DELIVERY_ATTEMPT',
    'DELIVERED',
  ];

  /// Drop-leg failure path. Does not include office handover.
  static const List<String> _receiverUnavailableStatuses = <String>[
    'PICKED_UP',
    'IN_TRANSIT',
    'NEAR_DROP',
    'DELIVERY_ATTEMPT',
    'RECEIVER_UNAVAILABLE',
  ];

  static const List<String> _officeHandoverStatuses = <String>[
    'RECEIVER_UNAVAILABLE',
    'FAILED_DELIVERY',
    'PARCEL_AT_COMPANY_OFFICE',
  ];

  /// Hops still required to reach [target] from the server status.
  ///
  /// An empty list means the server is already at or beyond [target] on that
  /// path. Null means [serverStatus] is not on a legal path to [target].
  static List<String>? remainingRiderHops({
    required String serverStatus,
    required DeliveryLifecycleStatus target,
  }) {
    switch (target) {
      case DeliveryLifecycleStatus.goingToPickup:
        return _remainingOn(_happyPathStatuses, serverStatus, 'EN_ROUTE_PICKUP');
      case DeliveryLifecycleStatus.arrivedAtPickup:
        return _remainingOn(_happyPathStatuses, serverStatus, 'ARRIVED_PICKUP');
      case DeliveryLifecycleStatus.packagePickedUp:
        return _remainingOn(_happyPathStatuses, serverStatus, 'PICKED_UP');
      case DeliveryLifecycleStatus.goingToDrop:
        return _remainingOn(_happyPathStatuses, serverStatus, 'IN_TRANSIT');
      case DeliveryLifecycleStatus.delivered:
        return _remainingOn(_happyPathStatuses, serverStatus, 'DELIVERED');
      case DeliveryLifecycleStatus.receiverUnavailable:
        return _remainingOn(
          _receiverUnavailableStatuses,
          serverStatus,
          'RECEIVER_UNAVAILABLE',
        );
      case DeliveryLifecycleStatus.parcelAtCompanyOffice:
        return _remainingOn(
          _officeHandoverStatuses,
          serverStatus,
          'PARCEL_AT_COMPANY_OFFICE',
        );
      case DeliveryLifecycleStatus.accepted:
        return null;
    }
  }

  static List<String>? _remainingOn(
    List<String> chain,
    String serverStatus,
    String targetStatus,
  ) {
    final int index = chain.indexOf(serverStatus);
    final int targetIndex = chain.indexOf(targetStatus);
    if (index < 0 || targetIndex < 0) {
      return null;
    }
    if (index >= targetIndex) {
      return const <String>[];
    }
    return List<String>.unmodifiable(chain.sublist(index + 1, targetIndex + 1));
  }

  /// Known rider lifecycle for a canonical status. Unknown statuses return null
  /// so the UI does not invent a step.
  static DeliveryLifecycleStatus? tryRiderLifecycle(String canonical) {
    switch (canonical) {
      case 'ASSIGNED':
        return DeliveryLifecycleStatus.accepted;
      case 'EN_ROUTE_PICKUP':
        return DeliveryLifecycleStatus.goingToPickup;
      case 'ARRIVED_PICKUP':
        return DeliveryLifecycleStatus.arrivedAtPickup;
      case 'PICKED_UP':
        return DeliveryLifecycleStatus.packagePickedUp;
      case 'IN_TRANSIT':
      case 'NEAR_DROP':
      case 'DELIVERY_ATTEMPT':
        return DeliveryLifecycleStatus.goingToDrop;
      case 'DELIVERED':
        return DeliveryLifecycleStatus.delivered;
      case 'RECEIVER_UNAVAILABLE':
      case 'FAILED_DELIVERY':
        return DeliveryLifecycleStatus.receiverUnavailable;
      case 'PARCEL_AT_COMPANY_OFFICE':
        return DeliveryLifecycleStatus.parcelAtCompanyOffice;
      default:
        return null;
    }
  }

  static MockOrder toMockOrder(
    ApiOrder order, {
    MockVehicle? vehicle,
  }) {
    final List<ApiStop> pickups = order.stops
        .where((ApiStop stop) => stop.stopType == 'PICKUP')
        .toList(growable: false);
    final List<ApiStop> drops = order.stops
        .where((ApiStop stop) => stop.stopType == 'DROP')
        .toList(growable: false);
    final MockLocation pickup = pickups.isEmpty
        ? MockLocation(
            id: 'pickup',
            label: order.pickupAddress ?? order.cityCode ?? 'Pickup',
            address: order.pickupAddress ?? order.cityCode ?? 'Pickup',
          )
        : _stopToLocation(pickups.first);
    final MockLocation drop = drops.isEmpty
        ? MockLocation(
            id: 'drop',
            label: order.dropAddress ?? 'Drop',
            address: order.dropAddress ?? 'Drop',
          )
        : _stopToLocation(drops.first);
    final List<MockLocation> extra = drops.length > 1
        ? drops.skip(1).map(_stopToLocation).toList(growable: false)
        : const <MockLocation>[];
    final bool cancelled = order.canonicalStatus == 'CANCELLED';
    final double storedPayable = order.netPayable ?? order.tripFare ?? 0;
    final double fare = cancelled ? 0 : storedPayable;
    final ApiFareSnapshot? snapshot = order.fareSnapshot;
    final ApiAssignedRider? assigned = order.assignedRider;
    final String? riderName = assigned?.name?.trim();
    final String vehicleLabel = <String?>[
      assigned?.vehicleCategoryName?.trim(),
      order.vehicleCategoryName?.trim(),
      assigned?.vehicleRegistration?.trim(),
    ].whereType<String>().where((String part) => part.isNotEmpty).join(' · ');
    final MockRider? rider = order.riderProfileId == null ||
            order.riderProfileId!.isEmpty
        ? null
        : MockRider(
            id: order.riderProfileId!,
            name: (riderName != null && riderName.isNotEmpty)
                ? riderName
                : 'Your rider',
            vehicleLabel: vehicleLabel,
            rating: 0,
            phone: assigned?.phone?.trim() ?? '',
            trips: 0,
            imagePath: _httpUrl(assigned?.profilePictureUrl),
          );
    return MockOrder(
      id: order.orderId,
      displayId: order.displayId,
      backendOrderId: order.orderId,
      status: toUiStatus(order.canonicalStatus),
      pickup: pickup,
      drop: drop,
      extraDrops: extra,
      vehicle: vehicle ??
          MockVehicle(
            id: order.vehicleCategoryId ?? 'vehicle',
            type: VehicleType.bike,
            name: order.vehicleCategoryName ?? 'Vehicle',
            description: '',
            capacity: '',
            etaMinutes: 0,
            baseFare: snapshot?.baseFare ?? 0,
            imagePath: MockData.artworkForCategoryName(order.vehicleCategoryName),
          ),
      fare: fare,
      tripFare: order.tripFare,
      weightKg: order.packageWeightKg ?? 0,
      crn: order.crn,
      ratingStars: order.customerRating?.stars,
      ratingComment: order.customerRating?.comment,
      discount: snapshot?.discount ?? 0,
      fareBase: snapshot?.baseFare ?? 0,
      fareDistance: snapshot?.distanceCharge ?? 0,
      fareWaiting: snapshot?.waiting ?? 0,
      fareSurge: snapshot?.surge ?? 0,
      fareToll: snapshot?.toll ?? 0,
      fareParking: snapshot?.parking ?? 0,
      createdAt: order.createdAt,
      riderId: order.riderProfileId,
      rider: rider,
    );
  }

  static RiderOrder toRiderOrder({
    required RiderOffer offer,
    ApiOrder? order,
  }) {
    final MockOrder? mapped =
        order == null ? null : toMockOrder(order);
    final ApiStop? dropStop = order?.stops
        .where((ApiStop stop) => stop.stopType == 'DROP')
        .fold<ApiStop?>(null, (ApiStop? first, ApiStop stop) {
      if (first == null) {
        return stop;
      }
      return stop.sequence < first.sequence ? stop : first;
    });
    final String receiverName = _optional(
      dropStop?.contactName,
      offer.receiverName,
    );
    final String receiverPhone = _optional(
      dropStop?.contactPhone,
      offer.receiverPhone,
    );
    final double? distanceKm = offer.distanceKm ?? order?.distanceKm;
    final int minutes = offer.estimatedDurationSeconds != null &&
            offer.estimatedDurationSeconds! > 0
        ? (offer.estimatedDurationSeconds! / 60).ceil()
        : 0;
    final DateTime? expiresAt = offer.expiresAt;
    final int? remaining = offerSecondsRemaining(expiresAt, DateTime.now());
    final double? packageKg = offer.packageWeightKg ?? order?.packageWeightKg;
    return RiderOrder(
      id: offer.displayId ?? mapped?.displayLabel ?? offer.orderId,
      offerId: offer.offerId,
      backendOrderId: offer.orderId,
      crn: order?.crn ?? offer.crn,
      pickup: _present(offer.pickupAddress, mapped?.pickup.address),
      drop: _present(offer.dropAddress, mapped?.drop.address),
      distanceKm: distanceKm ?? 0,
      estimatedEarnings: offer.riderAmount ?? order?.riderAmount ?? 0,
      estimatedMinutes: minutes,
      customerMaskedName: 'Customer',
      customerMaskedPhone: '••••',
      senderName: (order?.customerName ?? '').trim(),
      senderPhone: (order?.customerPhone ?? '').trim(),
      receiverName: receiverName,
      receiverPhone: receiverPhone,
      decisionSeconds: remaining ?? 0,
      expiresAt: expiresAt,
      vehicleName: _optional(
        offer.vehicleCategoryName,
        order?.vehicleCategoryName,
      ),
      packageLabel: packageKg == null || packageKg <= 0
          ? ''
          : '${_kg(packageKg)} kg',
      tripAmount: offer.tripFare ?? order?.tripFare ?? 0,
      riderAmount: offer.riderAmount ?? order?.riderAmount ?? 0,
      pickupLatitude: offer.pickupLatitude ?? mapped?.pickup.latitude,
      pickupLongitude: offer.pickupLongitude ?? mapped?.pickup.longitude,
      dropLatitude: offer.dropLatitude ?? mapped?.drop.latitude,
      dropLongitude: offer.dropLongitude ?? mapped?.drop.longitude,
    );
  }

  /// Copies a verified payment view onto [order]. Returns null when the view
  /// is missing, incomplete, or belongs to a different order.
  static RiderOrder? applyPaymentView({
    required RiderOrder order,
    required ApiOrderPaymentView payment,
  }) {
    final String id = (order.backendOrderId ?? '').trim();
    final ApiPaymentResponsibility? responsibility = payment.responsibility;
    final ApiPaymentPlan? plan = payment.plan;
    if (id.isEmpty ||
        payment.orderId != id ||
        responsibility == null ||
        plan == null ||
        responsibility.orderId != id ||
        plan.orderId != id) {
      return null;
    }
    return order.withPaymentAllocation(
      customerResponsibility: responsibility.customerResponsibility,
      receiverResponsibility: responsibility.receiverResponsibility,
      customerOnline: plan.customerPlannedOnline,
      customerCash: plan.customerPlannedCash,
      receiverOnline: plan.receiverPlannedOnline,
      receiverCash: plan.receiverPlannedCash,
    );
  }

  static String? _httpUrl(String? raw) {
    final String value = (raw ?? '').trim();
    if (value.startsWith('https://') || value.startsWith('http://')) {
      return value;
    }
    return null;
  }

  static String _optional(String? preferred, String? fallback) {
    final String first = (preferred ?? '').trim();
    if (first.isNotEmpty && first != '—') {
      return first;
    }
    final String second = (fallback ?? '').trim();
    if (second.isNotEmpty && second != '—') {
      return second;
    }
    return '';
  }

  static String _present(String? preferred, String? fallback) {
    final String first = (preferred ?? '').trim();
    if (first.isNotEmpty) {
      return first;
    }
    final String second = (fallback ?? '').trim();
    if (second.isNotEmpty) {
      return second;
    }
    return '—';
  }

  static String _kg(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  static MockLocation _stopToLocation(ApiStop stop) {
    return MockLocation(
      id: 'stop_${stop.sequence}',
      label: stop.stopType == 'PICKUP' ? 'Pickup' : 'Drop',
      address: stop.addressText,
      latitude: stop.latitude,
      longitude: stop.longitude,
    );
  }
}

extension MockOrderApiX on MockOrder {
  String get displayLabel =>
      (displayId != null && displayId!.isNotEmpty) ? displayId! : id;

  String get apiId =>
      (backendOrderId != null && backendOrderId!.isNotEmpty)
          ? backendOrderId!
          : id;
}
