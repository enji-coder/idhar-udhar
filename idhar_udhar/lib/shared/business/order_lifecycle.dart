/// Canonical order machine shared by Customer, Rider, and Admin.
/// Apps may display local labels; they must not invent a different machine.
enum CanonicalOrderStatus {
  created,
  searching,
  offered,
  assigned,
  enRoutePickup,
  arrivedPickup,
  pickedUp,
  inTransit,
  nearDrop,
  deliveryAttempt,
  delivered,
  cancelled,
  receiverUnavailable,
  failedDelivery,
  parcelAtCompanyOffice,
  resendRequested,
  resendInProgress,
  resendCompleted,
}

abstract final class OrderLifecycle {
  static const Set<CanonicalOrderStatus> terminal = {
    CanonicalOrderStatus.delivered,
    CanonicalOrderStatus.cancelled,
    CanonicalOrderStatus.resendCompleted,
  };

  static const Set<CanonicalOrderStatus> customerCancellable = {
    CanonicalOrderStatus.created,
    CanonicalOrderStatus.searching,
    CanonicalOrderStatus.offered,
    CanonicalOrderStatus.assigned,
  };

  /// Default fee is ₹0 until Admin enables a charge. Not a permanent lock.
  static const double defaultCancellationFee = 0;

  @Deprecated('Use CancellationEngine.quote instead of a hardcoded fee.')
  static const double cancellationFee = defaultCancellationFee;

  static bool canCustomerCancel(CanonicalOrderStatus status) =>
      customerCancellable.contains(status);

  static String customerLabel(CanonicalOrderStatus status) {
    switch (status) {
      case CanonicalOrderStatus.created:
      case CanonicalOrderStatus.searching:
        return 'Searching for rider';
      case CanonicalOrderStatus.offered:
      case CanonicalOrderStatus.assigned:
        return 'Rider assigned';
      case CanonicalOrderStatus.enRoutePickup:
        return 'Rider is on the way';
      case CanonicalOrderStatus.arrivedPickup:
        return 'Rider arriving';
      case CanonicalOrderStatus.pickedUp:
        return 'Parcel picked up';
      case CanonicalOrderStatus.inTransit:
        return 'In transit';
      case CanonicalOrderStatus.nearDrop:
        return 'Near destination';
      case CanonicalOrderStatus.deliveryAttempt:
        return 'Delivery attempt';
      case CanonicalOrderStatus.delivered:
        return 'Delivered';
      case CanonicalOrderStatus.cancelled:
        return 'Cancelled';
      case CanonicalOrderStatus.receiverUnavailable:
      case CanonicalOrderStatus.failedDelivery:
        return 'Receiver unavailable';
      case CanonicalOrderStatus.parcelAtCompanyOffice:
        return 'Parcel at company office';
      case CanonicalOrderStatus.resendRequested:
        return 'Resend requested';
      case CanonicalOrderStatus.resendInProgress:
        return 'Resend in progress';
      case CanonicalOrderStatus.resendCompleted:
        return 'Resend completed';
    }
  }

  static String riderLabel(CanonicalOrderStatus status) {
    switch (status) {
      case CanonicalOrderStatus.assigned:
        return 'Trip accepted';
      case CanonicalOrderStatus.enRoutePickup:
        return 'Going to pickup';
      case CanonicalOrderStatus.arrivedPickup:
        return 'Arrived at pickup';
      case CanonicalOrderStatus.pickedUp:
        return 'Package picked up';
      case CanonicalOrderStatus.inTransit:
        return 'Going to drop';
      case CanonicalOrderStatus.delivered:
        return 'Delivered';
      default:
        return customerLabel(status);
    }
  }

  static String adminLabel(CanonicalOrderStatus status) {
    switch (status) {
      case CanonicalOrderStatus.created:
      case CanonicalOrderStatus.searching:
        return 'Pending';
      case CanonicalOrderStatus.offered:
      case CanonicalOrderStatus.assigned:
        return 'Assigned';
      case CanonicalOrderStatus.enRoutePickup:
        return 'Rider Arriving';
      case CanonicalOrderStatus.arrivedPickup:
        return 'Out for Delivery';
      case CanonicalOrderStatus.pickedUp:
        return 'Picked Up';
      case CanonicalOrderStatus.inTransit:
        return 'In Transit';
      case CanonicalOrderStatus.nearDrop:
        return 'Out for Delivery';
      case CanonicalOrderStatus.deliveryAttempt:
        return 'Out for Delivery';
      case CanonicalOrderStatus.delivered:
        return 'Delivered';
      case CanonicalOrderStatus.cancelled:
        return 'Cancelled';
      case CanonicalOrderStatus.receiverUnavailable:
      case CanonicalOrderStatus.failedDelivery:
        return 'Failed';
      case CanonicalOrderStatus.parcelAtCompanyOffice:
        return 'Parcel At Company Office';
      case CanonicalOrderStatus.resendRequested:
        return 'Resend Requested';
      case CanonicalOrderStatus.resendInProgress:
        return 'Resend Requested';
      case CanonicalOrderStatus.resendCompleted:
        return 'Delivered';
    }
  }

  static bool originalTripEnded(CanonicalOrderStatus status) {
    return status == CanonicalOrderStatus.delivered ||
        status == CanonicalOrderStatus.cancelled ||
        status == CanonicalOrderStatus.failedDelivery ||
        status == CanonicalOrderStatus.parcelAtCompanyOffice ||
        status == CanonicalOrderStatus.resendCompleted;
  }

  static bool isActive(CanonicalOrderStatus status) =>
      status != CanonicalOrderStatus.delivered &&
      status != CanonicalOrderStatus.cancelled;

  static bool riderMayAcceptAnother(CanonicalOrderStatus? active) {
    if (active == null) return true;
    return terminal.contains(active) ||
        active == CanonicalOrderStatus.cancelled;
  }
}

class OrderStatusEvent {
  const OrderStatusEvent({
    required this.from,
    required this.to,
    required this.at,
    required this.actor,
  });

  final CanonicalOrderStatus? from;
  final CanonicalOrderStatus to;
  final DateTime at;
  final String actor;
}
