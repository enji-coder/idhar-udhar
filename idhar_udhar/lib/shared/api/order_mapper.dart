import 'package:idhar_udhar/customer/core/data/mock/mock_data.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/rider/data/models/rider_order.dart';

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
            label: order.cityCode ?? 'Pickup',
            address: order.cityCode ?? 'Pickup',
          )
        : _stopToLocation(pickups.first);
    final MockLocation drop = drops.isEmpty
        ? MockLocation(
            id: 'drop',
            label: order.vehicleCategoryName ?? 'Drop',
            address: order.vehicleCategoryName ?? 'Drop',
          )
        : _stopToLocation(drops.first);
    final List<MockLocation> extra = drops.length > 1
        ? drops.skip(1).map(_stopToLocation).toList(growable: false)
        : const <MockLocation>[];
    final double fare = order.tripFare ?? 0;
    return MockOrder(
      id: order.orderId,
      displayId: order.displayId,
      backendOrderId: order.orderId,
      status: toUiStatus(order.canonicalStatus),
      pickup: pickup,
      drop: drop,
      extraDrops: extra,
      vehicle: vehicle ?? MockData.vehicles.first,
      fare: fare,
      tripFare: order.tripFare,
      createdAt: order.createdAt,
      riderId: order.riderProfileId,
    );
  }

  static RiderOrder toRiderOrder({
    required RiderOffer offer,
    ApiOrder? order,
  }) {
    final MockOrder? mapped =
        order == null ? null : toMockOrder(order);
    return RiderOrder(
      id: offer.displayId ?? mapped?.displayLabel ?? offer.orderId,
      offerId: offer.offerId,
      backendOrderId: offer.orderId,
      pickup: mapped?.pickup.address ?? 'Pickup',
      drop: mapped?.drop.address ?? 'Drop',
      distanceKm: order?.distanceKm ?? 0,
      estimatedEarnings: order?.tripFare ?? 0,
      estimatedMinutes: 25,
      customerMaskedName: 'Customer',
      customerMaskedPhone: '••••',
      tripAmount: order?.tripFare ?? 0,
    );
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
