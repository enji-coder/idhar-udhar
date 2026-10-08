import 'package:idhar_udhar/customer/core/data/mock/mock_data.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/rider/data/models/rider_order.dart';
import 'package:idhar_udhar/shared/format/trip_distance.dart';

import 'orders_api.dart';
import 'rider_api.dart';

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
    final String receiverName = (dropStop?.contactName ?? '').trim();
    final String receiverPhone = (dropStop?.contactPhone ?? '').trim();
    final double? distanceKm = offer.distanceKm ?? order?.distanceKm;
    final int minutes = offer.estimatedDurationSeconds != null &&
            offer.estimatedDurationSeconds! > 0
        ? (offer.estimatedDurationSeconds! / 60).ceil()
        : plannedTripMinutes(distanceKm ?? 0);
    final DateTime? expiresAt = offer.expiresAt;
    final int remaining = expiresAt == null
        ? 0
        : expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 86400);
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
      receiverName: receiverName,
      receiverPhone: receiverPhone,
      decisionSeconds: remaining,
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
