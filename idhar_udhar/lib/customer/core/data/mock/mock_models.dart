/// Lightweight mock models for customer UI (no backend).

import 'package:idhar_udhar/shared/business/business.dart';

enum OrderStatus {
  searching,
  assigned,
  accepted,
  arriving,
  pickup,
  inTransit,
  nearDestination,
  delivered,
  cancelled,
  failed,
  atCompanyOffice,
  resendRequested,
}

enum VehicleType { bike, scooty, auto, car, truck, pickup }

enum TripPaymentMethod { online, cash }

/// Primary service family shown on Home (not a redesign — booking filter).
enum ServiceFamily { twoWheeler, threeWheeler, truck }

/// Saved-address labels for customer address book.
enum AddressLabel {
  home,
  office,
  friend,
  other;

  String get title {
    switch (this) {
      case AddressLabel.home:
        return 'Home';
      case AddressLabel.office:
        return 'Office';
      case AddressLabel.friend:
        return 'Friend';
      case AddressLabel.other:
        return 'Other';
    }
  }

  String get iconName {
    switch (this) {
      case AddressLabel.home:
        return 'home';
      case AddressLabel.office:
        return 'work';
      case AddressLabel.friend:
        return 'friend';
      case AddressLabel.other:
        return 'place';
    }
  }

  static AddressLabel fromTitle(String raw) {
    final String value = raw.trim().toLowerCase();
    for (final AddressLabel label in AddressLabel.values) {
      if (label.title.toLowerCase() == value || label.name == value) {
        return label;
      }
    }
    return AddressLabel.other;
  }
}

class MockUser {
  const MockUser({
    required this.id,
    required this.phone,
    this.name = '',
    this.email = '',
  });

  final String id;
  final String phone;
  final String name;

  /// Optional invoicing email (local/mock only).
  final String email;

  bool get hasName => name.trim().isNotEmpty;
  bool get hasEmail => email.trim().isNotEmpty;

  MockUser copyWith({
    String? id,
    String? phone,
    String? name,
    String? email,
  }) {
    return MockUser(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      email: email ?? this.email,
    );
  }
}

class MockLocation {
  const MockLocation({
    required this.id,
    required this.label,
    required this.address,
    this.city = '',
    this.isSaved = false,
    this.iconName = 'place',
    this.landmark = '',
    this.latitude,
    this.longitude,
    this.addressLabel,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String label;
  final String address;
  final String city;
  final bool isSaved;
  final String iconName;
  final String landmark;
  final double? latitude;
  final double? longitude;
  final AddressLabel? addressLabel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayLabel => addressLabel?.title ?? label;

  MockLocation copyWith({
    String? id,
    String? label,
    String? address,
    String? city,
    bool? isSaved,
    String? iconName,
    String? landmark,
    double? latitude,
    double? longitude,
    AddressLabel? addressLabel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MockLocation(
      id: id ?? this.id,
      label: label ?? this.label,
      address: address ?? this.address,
      city: city ?? this.city,
      isSaved: isSaved ?? this.isSaved,
      iconName: iconName ?? this.iconName,
      landmark: landmark ?? this.landmark,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      addressLabel: addressLabel ?? this.addressLabel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
        'address': address,
        'city': city,
        'isSaved': isSaved,
        'iconName': iconName,
        'landmark': landmark,
        'latitude': latitude,
        'longitude': longitude,
        'addressLabel': addressLabel?.name,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory MockLocation.fromJson(Map<String, dynamic> json) {
    final String? labelName = json['addressLabel'] as String?;
    return MockLocation(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      isSaved: json['isSaved'] as bool? ?? true,
      iconName: json['iconName'] as String? ?? 'place',
      landmark: json['landmark'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      addressLabel: labelName == null
          ? null
          : AddressLabel.values.firstWhere(
              (e) => e.name == labelName,
              orElse: () => AddressLabel.other,
            ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

class MockVehicle {
  const MockVehicle({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.capacity,
    required this.etaMinutes,
    required this.baseFare,
    required this.imagePath,
  });

  final String id;
  final VehicleType type;
  final String name;
  final String description;
  final String capacity;
  final int etaMinutes;
  final double baseFare;
  final String imagePath;

  String get fareLabel => '₹${baseFare.toStringAsFixed(0)}';
}

class MockRider {
  const MockRider({
    required this.id,
    required this.name,
    required this.vehicleLabel,
    required this.rating,
    required this.phone,
    this.trips = 120,
    this.imagePath,
  });

  final String id;
  final String name;
  final String vehicleLabel;
  final double rating;
  final String phone;
  final int trips;
  final String? imagePath;
}

/// Fare lines from the Admin-controlled engine. GST is always 0.
class FareBreakdown {
  const FareBreakdown({
    required this.baseFare,
    required this.distanceCharge,
    this.vehicleCharge = 0,
    this.platformFee = 0,
    this.tax = 0,
    this.discount = 0,
    this.waitingCharge = 0,
    this.surgeCharge = 0,
    this.tollCharge = 0,
    this.parkingCharge = 0,
    this.netTotal,
  });

  final double baseFare;
  final double distanceCharge;
  final double vehicleCharge;
  final double platformFee;
  final double tax;
  final double discount;
  final double waitingCharge;
  final double surgeCharge;
  final double tollCharge;
  final double parkingCharge;
  final double? netTotal;

  double get total =>
      netTotal ??
      (baseFare +
          distanceCharge +
          vehicleCharge +
          platformFee +
          waitingCharge +
          surgeCharge +
          tollCharge +
          parkingCharge -
          discount +
          tax);
}

class MockOrder {
  const MockOrder({
    required this.id,
    required this.status,
    required this.pickup,
    required this.drop,
    required this.vehicle,
    required this.fare,
    required this.createdAt,
    this.customerId,
    this.riderId,
    this.rider,
    this.packageLabel = 'Package',
    this.weightKg = 5,
    this.instructions = '',
    this.etaMinutes = 25,
    this.scheduledAt,
    this.invoiceSent = false,
    this.invoiceEmail = '',
    this.extraDrops = const [],
    this.fareConfigVersionId,
    this.parentOrderId,
    this.failedReason,
    this.officeCompensation = 0,
    this.resendCharge = 0,
    this.officeDistanceKm = 0,
    this.customerNotice,
    this.tripFare,
    this.discount = 0,
    this.additionalCharge = 0,
    this.paymentMethod = TripPaymentMethod.online,
    this.customerResponsibility,
    this.receiverResponsibility,
    this.customerOnline = 0,
    this.customerCash = 0,
    this.receiverOnline = 0,
    this.receiverCash = 0,
    this.paymentTransactions = const [],
    this.cancellationFee = 0,
    this.resendCaseLabel,
  });

  final String id;
  final OrderStatus status;
  final MockLocation pickup;
  final MockLocation drop;
  final MockVehicle vehicle;
  /// Customer payable (net). Historical — do not recompute from live rates.
  final double fare;
  final DateTime createdAt;
  final String? customerId;
  final String? riderId;
  final MockRider? rider;
  final String packageLabel;
  final double weightKg;
  final String instructions;
  final int etaMinutes;

  /// Optional future scheduled pickup (local draft only — no backend jobs).
  final DateTime? scheduledAt;

  /// Dummy invoice flag (no real email send).
  final bool invoiceSent;
  final String invoiceEmail;

  /// Additional drop stops after [drop], in sequence. Pickup is stop 0.
  final List<MockLocation> extraDrops;
  final String? fareConfigVersionId;
  final String? parentOrderId;
  final String? failedReason;
  final double officeCompensation;
  final double resendCharge;
  final double officeDistanceKm;
  final String? customerNotice;
  /// Confirmed trip fare used for 85/15. Falls back to [fare] for old mocks.
  final double? tripFare;
  final double discount;
  final double additionalCharge;
  /// Legacy single-method hint. [paymentPlan] is the source of truth.
  final TripPaymentMethod paymentMethod;
  final double? customerResponsibility;
  final double? receiverResponsibility;
  final double customerOnline;
  final double customerCash;
  final double receiverOnline;
  final double receiverCash;
  final List<PaymentTxn> paymentTransactions;
  final double cancellationFee;
  final String? resendCaseLabel;

  double get confirmedTripFare => tripFare ?? fare;

  PaymentPlan get paymentPlan {
    final double total = FareEngine.round2(fare);
    final PaymentResponsibility responsibility = PaymentResponsibility(
      totalAmount: total,
      customerAmount: FareEngine.round2(customerResponsibility ?? total),
      receiverAmount: FareEngine.round2(
        receiverResponsibility ?? (total - (customerResponsibility ?? total)),
      ),
    );
    final bool hasSplit =
        customerOnline + customerCash + receiverOnline + receiverCash > 0;
    final PaymentAllocation allocation = hasSplit
        ? PaymentAllocation(
            customerOnline: customerOnline,
            customerCash: customerCash,
            receiverOnline: receiverOnline,
            receiverCash: receiverCash,
          )
        : paymentMethod == TripPaymentMethod.cash
            ? PaymentAllocation(customerCash: total)
            : PaymentAllocation(customerOnline: total);
    return PaymentPlan(
      responsibility: responsibility,
      allocation: allocation,
      transactions: paymentTransactions.isNotEmpty
          ? paymentTransactions
          : PaymentEngine.plannedTransactions(
              orderId: id,
              allocation: allocation,
            ),
    );
  }

  String get paymentSummaryLabel {
    final PaymentAllocation a = paymentPlan.allocation;
    final List<String> parts = <String>[];
    if (a.customerOnline > 0) {
      parts.add('Customer Online ₹${a.customerOnline.toStringAsFixed(0)}');
    }
    if (a.customerCash > 0) {
      parts.add('Customer Cash ₹${a.customerCash.toStringAsFixed(0)}');
    }
    if (a.receiverOnline > 0) {
      parts.add('Receiver Online ₹${a.receiverOnline.toStringAsFixed(0)}');
    }
    if (a.receiverCash > 0) {
      parts.add('Receiver Cash ₹${a.receiverCash.toStringAsFixed(0)}');
    }
    if (parts.isEmpty) return 'UNPAID';
    return parts.join(' · ');
  }

  List<MockLocation> get allDrops => [drop, ...extraDrops];

  String get routeLabel {
    final List<String> parts = <String>[
      pickup.label,
      ...allDrops.map((d) => d.label),
    ];
    return parts.join(' → ');
  }

  /// Uses Admin cancellation config for this trip stage.
  bool get canCancel {
    final CancellationQuote quote = CancellationEngine.quote(
      actor: CancellationActor.customer,
      status: canonicalStatus,
      config: PlatformRules.current.cancellation,
    );
    return quote.allowed;
  }

  CancellationQuote get cancellationQuote => CancellationEngine.quote(
        actor: CancellationActor.customer,
        status: canonicalStatus,
        config: PlatformRules.current.cancellation,
      );

  bool get isActive =>
      status != OrderStatus.delivered && status != OrderStatus.cancelled;

  bool get canRequestResend =>
      status == OrderStatus.failed || status == OrderStatus.atCompanyOffice;

  String get statusLabel {
    switch (status) {
      case OrderStatus.searching:
        return 'Searching for rider';
      case OrderStatus.assigned:
        return 'Rider assigned';
      case OrderStatus.accepted:
        return 'Rider is on the way';
      case OrderStatus.arriving:
        return 'Rider arriving';
      case OrderStatus.pickup:
        return 'Parcel picked up';
      case OrderStatus.inTransit:
        return 'In transit';
      case OrderStatus.nearDestination:
        return 'Near destination';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.failed:
        return 'Receiver unavailable';
      case OrderStatus.atCompanyOffice:
        return 'Parcel at company office';
      case OrderStatus.resendRequested:
        return 'Resend requested';
    }
  }

  CanonicalOrderStatus get canonicalStatus {
    switch (status) {
      case OrderStatus.searching:
        return CanonicalOrderStatus.searching;
      case OrderStatus.assigned:
        return CanonicalOrderStatus.assigned;
      case OrderStatus.accepted:
        return CanonicalOrderStatus.assigned;
      case OrderStatus.arriving:
        return CanonicalOrderStatus.enRoutePickup;
      case OrderStatus.pickup:
        return CanonicalOrderStatus.pickedUp;
      case OrderStatus.inTransit:
        return CanonicalOrderStatus.inTransit;
      case OrderStatus.nearDestination:
        return CanonicalOrderStatus.nearDrop;
      case OrderStatus.delivered:
        return CanonicalOrderStatus.delivered;
      case OrderStatus.cancelled:
        return CanonicalOrderStatus.cancelled;
      case OrderStatus.failed:
        return CanonicalOrderStatus.failedDelivery;
      case OrderStatus.atCompanyOffice:
        return CanonicalOrderStatus.parcelAtCompanyOffice;
      case OrderStatus.resendRequested:
        return CanonicalOrderStatus.resendRequested;
    }
  }

  MockOrder copyWith({
    OrderStatus? status,
    MockRider? rider,
    String? riderId,
    int? etaMinutes,
    DateTime? scheduledAt,
    bool clearScheduledAt = false,
    bool? invoiceSent,
    String? invoiceEmail,
    List<MockLocation>? extraDrops,
    String? fareConfigVersionId,
    String? parentOrderId,
    String? failedReason,
    double? officeCompensation,
    double? resendCharge,
    double? officeDistanceKm,
    String? customerNotice,
    double? fare,
    double? tripFare,
    double? discount,
    double? additionalCharge,
    TripPaymentMethod? paymentMethod,
    double? customerResponsibility,
    double? receiverResponsibility,
    double? customerOnline,
    double? customerCash,
    double? receiverOnline,
    double? receiverCash,
    List<PaymentTxn>? paymentTransactions,
    double? cancellationFee,
    String? resendCaseLabel,
  }) {
    return MockOrder(
      id: id,
      status: status ?? this.status,
      pickup: pickup,
      drop: drop,
      vehicle: vehicle,
      fare: fare ?? this.fare,
      createdAt: createdAt,
      customerId: customerId,
      riderId: riderId ?? this.riderId,
      rider: rider ?? this.rider,
      packageLabel: packageLabel,
      weightKg: weightKg,
      instructions: instructions,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      scheduledAt:
          clearScheduledAt ? null : (scheduledAt ?? this.scheduledAt),
      invoiceSent: invoiceSent ?? this.invoiceSent,
      invoiceEmail: invoiceEmail ?? this.invoiceEmail,
      extraDrops: extraDrops ?? this.extraDrops,
      fareConfigVersionId: fareConfigVersionId ?? this.fareConfigVersionId,
      parentOrderId: parentOrderId ?? this.parentOrderId,
      failedReason: failedReason ?? this.failedReason,
      officeCompensation: officeCompensation ?? this.officeCompensation,
      resendCharge: resendCharge ?? this.resendCharge,
      officeDistanceKm: officeDistanceKm ?? this.officeDistanceKm,
      customerNotice: customerNotice ?? this.customerNotice,
      tripFare: tripFare ?? this.tripFare,
      discount: discount ?? this.discount,
      additionalCharge: additionalCharge ?? this.additionalCharge,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerResponsibility:
          customerResponsibility ?? this.customerResponsibility,
      receiverResponsibility:
          receiverResponsibility ?? this.receiverResponsibility,
      customerOnline: customerOnline ?? this.customerOnline,
      customerCash: customerCash ?? this.customerCash,
      receiverOnline: receiverOnline ?? this.receiverOnline,
      receiverCash: receiverCash ?? this.receiverCash,
      paymentTransactions: paymentTransactions ?? this.paymentTransactions,
      cancellationFee: cancellationFee ?? this.cancellationFee,
      resendCaseLabel: resendCaseLabel ?? this.resendCaseLabel,
    );
  }
}

/// Future payment-method structure for wallet top-up (UI/data only).
enum WalletPaymentMethodKind {
  googlePay,
  phonePe,
  paytm,
  netBanking,
  creditCard,
  debitCard,
}

class WalletPaymentOption {
  const WalletPaymentOption({
    required this.id,
    required this.kind,
    required this.label,
    required this.group,
  });

  final String id;
  final WalletPaymentMethodKind kind;
  final String label;
  final String group;
}

class MockParcelCategory {
  const MockParcelCategory({
    required this.id,
    required this.label,
    required this.imagePath,
    required this.icon,
  });

  final String id;
  final String label;
  final String imagePath;
  final String icon;
}

class MockParcelSize {
  const MockParcelSize({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.imagePath,
  });

  final String id;
  final String label;
  final String subtitle;
  final String imagePath;
}

class MockWalletTxn {
  const MockWalletTxn({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.isCredit,
  });

  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final bool isCredit;
}
