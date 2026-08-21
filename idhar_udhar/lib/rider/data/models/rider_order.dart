enum RiderOrderPaymentMethod { cash, online }

enum DeliveryLifecycleStatus {
  accepted,
  goingToPickup,
  arrivedAtPickup,
  packagePickedUp,
  goingToDrop,
  delivered,
  receiverUnavailable,
  parcelAtCompanyOffice,
}

extension DeliveryLifecycleStatusX on DeliveryLifecycleStatus {
  String get label {
    switch (this) {
      case DeliveryLifecycleStatus.accepted:
        return 'Accepted';
      case DeliveryLifecycleStatus.goingToPickup:
        return 'Going to Pickup';
      case DeliveryLifecycleStatus.arrivedAtPickup:
        return 'Arrived at Pickup';
      case DeliveryLifecycleStatus.packagePickedUp:
        return 'Package Picked Up';
      case DeliveryLifecycleStatus.goingToDrop:
        return 'Going to Drop';
      case DeliveryLifecycleStatus.delivered:
        return 'Delivered';
      case DeliveryLifecycleStatus.receiverUnavailable:
        return 'Receiver Unavailable';
      case DeliveryLifecycleStatus.parcelAtCompanyOffice:
        return 'Parcel at Company Office';
    }
  }

  String get actionLabel {
    switch (this) {
      case DeliveryLifecycleStatus.accepted:
        return 'Start navigation to pickup';
      case DeliveryLifecycleStatus.goingToPickup:
        return 'Mark arrived at pickup';
      case DeliveryLifecycleStatus.arrivedAtPickup:
        return 'Confirm package picked up';
      case DeliveryLifecycleStatus.packagePickedUp:
        return 'Start navigation to drop';
      case DeliveryLifecycleStatus.goingToDrop:
        return 'Mark as delivered';
      case DeliveryLifecycleStatus.delivered:
        return 'Complete';
      case DeliveryLifecycleStatus.receiverUnavailable:
        return 'Parcel Dropped At Company Office';
      case DeliveryLifecycleStatus.parcelAtCompanyOffice:
        return 'Complete';
    }
  }

  DeliveryLifecycleStatus? get next {
    switch (this) {
      case DeliveryLifecycleStatus.accepted:
        return DeliveryLifecycleStatus.goingToPickup;
      case DeliveryLifecycleStatus.goingToPickup:
        return DeliveryLifecycleStatus.arrivedAtPickup;
      case DeliveryLifecycleStatus.arrivedAtPickup:
        return DeliveryLifecycleStatus.packagePickedUp;
      case DeliveryLifecycleStatus.packagePickedUp:
        return DeliveryLifecycleStatus.goingToDrop;
      case DeliveryLifecycleStatus.goingToDrop:
        return DeliveryLifecycleStatus.delivered;
      case DeliveryLifecycleStatus.receiverUnavailable:
        return DeliveryLifecycleStatus.parcelAtCompanyOffice;
      case DeliveryLifecycleStatus.delivered:
      case DeliveryLifecycleStatus.parcelAtCompanyOffice:
        return null;
    }
  }
}

class RiderOrder {
  const RiderOrder({
    required this.id,
    required this.pickup,
    required this.drop,
    required this.distanceKm,
    required this.estimatedEarnings,
    required this.estimatedMinutes,
    required this.customerMaskedName,
    required this.customerMaskedPhone,
    this.paymentMethod = RiderOrderPaymentMethod.online,
    this.decisionSeconds = 27,
    this.tripAmount = 0,
    this.riderAmount = 0,
    this.companyShare = 0,
    this.officeDistanceKm = 5,
    this.officeCompensation = 40,
    this.customerResponsibility = 0,
    this.receiverResponsibility = 0,
    this.customerPaid = 0,
    this.receiverPaid = 0,
    this.customerOnline = 0,
    this.customerCash = 0,
    this.receiverOnline = 0,
    this.receiverCash = 0,
    this.paymentStatusLabel = 'UNPAID',
  });

  final String id;
  final String pickup;
  final String drop;
  final double distanceKm;
  final double estimatedEarnings;
  final int estimatedMinutes;
  final RiderOrderPaymentMethod paymentMethod;
  final String customerMaskedName;
  final String customerMaskedPhone;
  final int decisionSeconds;
  final double tripAmount;
  final double riderAmount;
  final double companyShare;
  final double officeDistanceKm;
  final double officeCompensation;
  final double customerResponsibility;
  final double receiverResponsibility;
  final double customerPaid;
  final double receiverPaid;
  final double customerOnline;
  final double customerCash;
  final double receiverOnline;
  final double receiverCash;
  final String paymentStatusLabel;

  double get cashCollected => customerCash + receiverCash;

  String get paymentLabel {
    final List<String> parts = <String>[];
    if (customerOnline > 0) parts.add('Customer Online');
    if (customerCash > 0) parts.add('Customer Cash');
    if (receiverOnline > 0) parts.add('Receiver Online');
    if (receiverCash > 0) parts.add('Receiver Cash');
    if (parts.isNotEmpty) return parts.join(' · ');
    return paymentMethod == RiderOrderPaymentMethod.online ? 'Online' : 'Cash';
  }
}
