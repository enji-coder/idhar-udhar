import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idhar_udhar/shared/business/business.dart';

import '../data/mock/mock_data.dart';
import '../data/mock/mock_models.dart';

enum DeliveryMode { single, multiple }

class BookingDraft {
  const BookingDraft({
    this.pickup,
    this.drop,
    this.vehicle,
    this.serviceFamily,
    this.categoryId = 'c_pkg',
    this.sizeId = 's_md',
    this.weightKg = 5,
    this.instructions = '',
    this.fragile = false,
    this.cod = false,
    this.paymentMethod = TripPaymentMethod.online,
    this.whoPays = PaymentWhoPays.customer,
    this.customerAmount = 0,
    this.customerMethodMode = PayerMethodMode.online,
    this.receiverMethodMode = PayerMethodMode.cash,
    this.customerOnlineAmount = 0,
    this.receiverOnlineAmount = 0,
    this.activeOrder,
    this.scheduledAt,
    this.deliveryMode = DeliveryMode.single,
    this.dropCount = 1,
    this.extraDrops = const [],
    this.quotedNetPayable,
    this.pickupHouse = '',
    this.pickupSociety = '',
    this.confirmedPickupKey,
    this.confirmedDropKey,
    this.extraDropConfirmedKeys = const <String?>[],
    this.routeDistanceMeters,
    this.routeDurationSeconds,
  });

  final MockLocation? pickup;
  final MockLocation? drop;
  final MockVehicle? vehicle;
  final ServiceFamily? serviceFamily;
  final String categoryId;
  final String sizeId;
  final double weightKg;
  final String instructions;
  final bool fragile;
  final bool cod;
  /// Legacy hint. [paymentPlan] is the source of truth.
  final TripPaymentMethod paymentMethod;
  final PaymentWhoPays whoPays;
  final double customerAmount;
  final PayerMethodMode customerMethodMode;
  final PayerMethodMode receiverMethodMode;
  final double customerOnlineAmount;
  final double receiverOnlineAmount;
  final MockOrder? activeOrder;
  final DateTime? scheduledAt;
  final DeliveryMode deliveryMode;
  final int dropCount;
  final List<MockLocation> extraDrops;
  final double? quotedNetPayable;

  /// House / flat number for a two-wheeler pickup. Kept separate so a new
  /// map address does not wipe what the customer typed.
  final String pickupHouse;

  /// Society / building name for a two-wheeler pickup.
  final String pickupSociety;

  /// Identity of the pickup whose address was confirmed.
  /// Unit and premises are not part of this identity.
  final String? confirmedPickupKey;

  /// Identity of the primary drop pin whose address was confirmed.
  final String? confirmedDropKey;

  /// Confirmation identity for each extra drop, parallel to [extraDrops].
  final List<String?> extraDropConfirmedKeys;

  /// Road distance from Google Routes, when a route was returned.
  final int? routeDistanceMeters;

  /// Road duration from Google Routes, when a route was returned.
  final int? routeDurationSeconds;

  bool get usesResidentialPickup {
    final MockVehicle? selected = vehicle;
    if (selected != null) {
      return selected.type == VehicleType.bike ||
          selected.type == VehicleType.scooty;
    }
    return serviceFamily == ServiceFamily.twoWheeler;
  }

  /// Address sent with the booking. Residential fields are prefixed only
  /// for bike and scooty.
  String get pickupAddressText {
    final MockLocation? from = pickup;
    if (from == null) {
      return '';
    }
    return locationAddress(from);
  }

  /// Address shown for a stop. House and building are included when present,
  /// and segments already inside the full location are not repeated.
  String locationAddress(MockLocation loc) {
    final bool isPickup = pickup != null && loc.id == pickup!.id;
    final String house = isPickup && pickupHouse.trim().isNotEmpty
        ? pickupHouse.trim()
        : loc.unit;
    final String society = isPickup && pickupSociety.trim().isNotEmpty
        ? pickupSociety.trim()
        : loc.premises;
    final String composed = MockLocation.composeAddress(
      unit: house,
      premises: society,
      address: loc.address,
    );
    if (composed.isNotEmpty) {
      return composed;
    }
    return loc.label.trim();
  }

  String get categoryLabel {
    return MockData.parcelCategories
        .firstWhere(
          (c) => c.id == categoryId,
          orElse: () => MockData.parcelCategories[1],
        )
        .label;
  }

  String get sizeLabel {
    return MockData.parcelSizes
        .firstWhere(
          (s) => s.id == sizeId,
          orElse: () => MockData.parcelSizes[1],
        )
        .label;
  }

  int get requiredDropCount =>
      deliveryMode == DeliveryMode.multiple ? dropCount : 1;

  static bool isLocationSelected(MockLocation? loc) {
    if (loc == null) {
      return false;
    }
    if (loc.id.trim().isEmpty) {
      return false;
    }
    return loc.address.trim().isNotEmpty || loc.label.trim().isNotEmpty;
  }

  /// Pin identity. Unit and premises are excluded so confirming an address
  /// does not look like a new location. A different id, coordinate, or full
  /// location does.
  static String locationKey(MockLocation location) {
    final String lat = location.latitude?.toStringAsFixed(5) ?? '';
    final String lng = location.longitude?.toStringAsFixed(5) ?? '';
    return '${location.id}|$lat|$lng|${location.address.trim().toLowerCase()}';
  }

  static bool samePin(MockLocation? current, MockLocation next) {
    if (!isLocationSelected(current)) {
      return false;
    }
    return locationKey(current!) == locationKey(next);
  }

  bool get pickupAddressConfirmed {
    final MockLocation? loc = pickup;
    if (loc == null || confirmedPickupKey == null) {
      return false;
    }
    return confirmedPickupKey == locationKey(loc);
  }

  bool dropConfirmedAt(int index) {
    final MockLocation? loc = dropAt(index);
    if (loc == null) {
      return false;
    }
    final String? key = index <= 0
        ? confirmedDropKey
        : (index - 1 < extraDropConfirmedKeys.length
            ? extraDropConfirmedKeys[index - 1]
            : null);
    return key != null && key == locationKey(loc);
  }

  bool get dropsAddressConfirmed {
    for (int i = 0; i < requiredDropCount; i++) {
      if (!dropConfirmedAt(i)) {
        return false;
      }
    }
    return requiredDropCount > 0;
  }

  bool get readyForRoutePreview =>
      pickupAddressConfirmed && dropsAddressConfirmed;

  bool needsPickupConfirmationFor(MockLocation location) {
    return !pickupAddressConfirmed ||
        pickup == null ||
        locationKey(pickup!) != locationKey(location);
  }

  bool needsDropConfirmationFor(MockLocation location, int index) {
    final MockLocation? current = dropAt(index);
    return !dropConfirmedAt(index) ||
        current == null ||
        locationKey(current) != locationKey(location);
  }

  MockLocation? dropAt(int index) {
    if (index <= 0) {
      return isLocationSelected(drop) ? drop : null;
    }
    final int extraIndex = index - 1;
    if (extraIndex < 0 || extraIndex >= extraDrops.length) {
      return null;
    }
    final MockLocation loc = extraDrops[extraIndex];
    return isLocationSelected(loc) ? loc : null;
  }

  /// Selected drops for the current mode/count only — no empty placeholders.
  List<MockLocation> get allDrops {
    final List<MockLocation> drops = <MockLocation>[];
    for (int i = 0; i < requiredDropCount; i++) {
      final MockLocation? loc = dropAt(i);
      if (loc != null) {
        drops.add(loc);
      }
    }
    return drops;
  }

  String? get incompleteStopMessage {
    if (!isLocationSelected(pickup)) {
      return 'Select a pickup location';
    }
    for (int i = 0; i < requiredDropCount; i++) {
      if (dropAt(i) == null) {
        return requiredDropCount == 1
            ? 'Select a drop location'
            : 'Select Drop Location ${i + 1}';
      }
    }
    return null;
  }

  /// Pickup and drop pins that identify the route being priced.
  String? get fareRouteKey {
    final MockLocation? from = pickup;
    if (from?.latitude == null || from?.longitude == null) {
      return null;
    }
    if (allDrops.length != requiredDropCount) {
      return null;
    }
    final StringBuffer key = StringBuffer()
      ..write(from!.latitude!.toStringAsFixed(6))
      ..write(',')
      ..write(from.longitude!.toStringAsFixed(6));
    for (final MockLocation drop in allDrops) {
      if (drop.latitude == null || drop.longitude == null) {
        return null;
      }
      key
        ..write('|')
        ..write(drop.latitude!.toStringAsFixed(6))
        ..write(',')
        ..write(drop.longitude!.toStringAsFixed(6));
    }
    return key.toString();
  }

  double get payableTotal =>
      quotedNetPayable == null ? 0 : FareEngine.round2(quotedNetPayable!);

  double get customerResponsibility {
    switch (whoPays) {
      case PaymentWhoPays.customer:
        return payableTotal;
      case PaymentWhoPays.receiver:
        return 0;
      case PaymentWhoPays.split:
        final double amount = FareEngine.round2(customerAmount);
        if (amount < 0) return 0;
        if (amount > payableTotal) return payableTotal;
        return amount;
    }
  }

  double get receiverResponsibility =>
      FareEngine.round2(payableTotal - customerResponsibility);

  PaymentAllocation get paymentAllocation {
    double splitOnline(double due, double requested) {
      final double online = FareEngine.round2(requested);
      if (due <= 0) return 0;
      if (online < 0) return 0;
      if (online > due) return due;
      return online;
    }

    double customerOnline = 0;
    double customerCash = 0;
    switch (customerMethodMode) {
      case PayerMethodMode.online:
        customerOnline = customerResponsibility;
        break;
      case PayerMethodMode.cash:
        customerCash = customerResponsibility;
        break;
      case PayerMethodMode.split:
        customerOnline =
            splitOnline(customerResponsibility, customerOnlineAmount);
        customerCash =
            FareEngine.round2(customerResponsibility - customerOnline);
        break;
    }

    double receiverOnline = 0;
    double receiverCash = 0;
    switch (receiverMethodMode) {
      case PayerMethodMode.online:
        receiverOnline = receiverResponsibility;
        break;
      case PayerMethodMode.cash:
        receiverCash = receiverResponsibility;
        break;
      case PayerMethodMode.split:
        receiverOnline =
            splitOnline(receiverResponsibility, receiverOnlineAmount);
        receiverCash =
            FareEngine.round2(receiverResponsibility - receiverOnline);
        break;
    }

    return PaymentAllocation(
      customerOnline: customerOnline,
      customerCash: customerCash,
      receiverOnline: receiverOnline,
      receiverCash: receiverCash,
    );
  }

  PaymentResponsibility get paymentResponsibility => PaymentResponsibility(
        totalAmount: payableTotal,
        customerAmount: customerResponsibility,
        receiverAmount: receiverResponsibility,
      );

  String? get paymentValidationError => PaymentEngine.validate(
        responsibility: paymentResponsibility,
        allocation: paymentAllocation,
      );

  TripPaymentMethod get derivedPaymentMethod {
    final PaymentAllocation a = paymentAllocation;
    if (a.cashTotal > 0 && a.onlineTotal == 0) {
      return TripPaymentMethod.cash;
    }
    return TripPaymentMethod.online;
  }

  BookingDraft copyWith({
    MockLocation? pickup,
    MockLocation? drop,
    MockVehicle? vehicle,
    bool clearVehicle = false,
    ServiceFamily? serviceFamily,
    bool clearServiceFamily = false,
    String? categoryId,
    String? sizeId,
    double? weightKg,
    String? instructions,
    bool? fragile,
    bool? cod,
    TripPaymentMethod? paymentMethod,
    PaymentWhoPays? whoPays,
    double? customerAmount,
    PayerMethodMode? customerMethodMode,
    PayerMethodMode? receiverMethodMode,
    double? customerOnlineAmount,
    double? receiverOnlineAmount,
    MockOrder? activeOrder,
    bool clearActiveOrder = false,
    DateTime? scheduledAt,
    bool clearScheduledAt = false,
    DeliveryMode? deliveryMode,
    int? dropCount,
    List<MockLocation>? extraDrops,
    double? quotedNetPayable,
    bool clearQuotedNetPayable = false,
    String? pickupHouse,
    String? pickupSociety,
    String? confirmedPickupKey,
    bool clearPickupConfirmation = false,
    String? confirmedDropKey,
    bool clearDropConfirmation = false,
    List<String?>? extraDropConfirmedKeys,
    int? routeDistanceMeters,
    int? routeDurationSeconds,
    bool clearRoute = false,
  }) {
    return BookingDraft(
      pickup: pickup ?? this.pickup,
      drop: drop ?? this.drop,
      vehicle: clearVehicle ? null : (vehicle ?? this.vehicle),
      serviceFamily: clearServiceFamily
          ? null
          : (serviceFamily ?? this.serviceFamily),
      categoryId: categoryId ?? this.categoryId,
      sizeId: sizeId ?? this.sizeId,
      weightKg: weightKg ?? this.weightKg,
      instructions: instructions ?? this.instructions,
      fragile: fragile ?? this.fragile,
      cod: cod ?? this.cod,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      whoPays: whoPays ?? this.whoPays,
      customerAmount: customerAmount ?? this.customerAmount,
      customerMethodMode: customerMethodMode ?? this.customerMethodMode,
      receiverMethodMode: receiverMethodMode ?? this.receiverMethodMode,
      customerOnlineAmount: customerOnlineAmount ?? this.customerOnlineAmount,
      receiverOnlineAmount: receiverOnlineAmount ?? this.receiverOnlineAmount,
      activeOrder:
          clearActiveOrder ? null : (activeOrder ?? this.activeOrder),
      scheduledAt:
          clearScheduledAt ? null : (scheduledAt ?? this.scheduledAt),
      deliveryMode: deliveryMode ?? this.deliveryMode,
      dropCount: dropCount ?? this.dropCount,
      extraDrops: extraDrops ?? this.extraDrops,
      quotedNetPayable: clearQuotedNetPayable
          ? null
          : (quotedNetPayable ?? this.quotedNetPayable),
      pickupHouse: pickupHouse ?? this.pickupHouse,
      pickupSociety: pickupSociety ?? this.pickupSociety,
      confirmedPickupKey: clearPickupConfirmation
          ? null
          : (confirmedPickupKey ?? this.confirmedPickupKey),
      confirmedDropKey: clearDropConfirmation
          ? null
          : (confirmedDropKey ?? this.confirmedDropKey),
      extraDropConfirmedKeys:
          extraDropConfirmedKeys ?? this.extraDropConfirmedKeys,
      routeDistanceMeters:
          clearRoute ? null : (routeDistanceMeters ?? this.routeDistanceMeters),
      routeDurationSeconds: clearRoute
          ? null
          : (routeDurationSeconds ?? this.routeDurationSeconds),
    );
  }
}

class BookingDraftNotifier extends StateNotifier<BookingDraft> {
  BookingDraftNotifier()
      : super(BookingDraft(pickup: MockData.locations[4]));

  /// Set when the customer chooses a pickup. A later GPS result must not replace it.
  bool _manualPickup = false;

  void setPickup(MockLocation location) {
    _manualPickup = true;
    final bool same = BookingDraft.samePin(state.pickup, location);
    state = state.copyWith(
      pickup: location,
      clearQuotedNetPayable: true,
      clearRoute: !same,
      clearPickupConfirmation: !same,
    );
  }

  /// Startup GPS only. Ignored once the customer has chosen a pickup.
  /// Does not confirm the address and does not replace a chosen pickup.
  void applyDevicePickup(MockLocation location) {
    if (_manualPickup) {
      return;
    }
    state = state.copyWith(
      pickup: location,
      clearQuotedNetPayable: true,
      clearRoute: true,
      clearPickupConfirmation: true,
    );
  }

  void setPickupUnit({String? house, String? society}) {
    state = state.copyWith(pickupHouse: house, pickupSociety: society);
  }

  /// Stores the address captured for the current pickup pin.
  /// Coordinates on [location] are kept as given.
  void confirmPickupAddress(MockLocation location) {
    _manualPickup = true;
    state = state.copyWith(
      pickup: location,
      pickupHouse: location.unit,
      pickupSociety: location.premises,
      confirmedPickupKey: BookingDraft.locationKey(location),
      clearQuotedNetPayable: true,
      clearRoute: true,
    );
  }

  void setDrop(MockLocation location) {
    final bool same = BookingDraft.samePin(state.drop, location);
    state = state.copyWith(
      drop: location,
      clearQuotedNetPayable: true,
      clearRoute: !same,
      clearDropConfirmation: !same,
    );
  }

  /// Stores the address captured for the drop at [index].
  /// Coordinates on [location] are kept as given.
  void confirmDropAddress(MockLocation location, {int index = 0}) {
    if (index <= 0) {
      state = state.copyWith(
        drop: location,
        confirmedDropKey: BookingDraft.locationKey(location),
        clearQuotedNetPayable: true,
        clearRoute: true,
      );
      return;
    }
    final int extraSlots = state.dropCount - 1;
    if (index > extraSlots) {
      return;
    }
    final List<MockLocation> extra = List<MockLocation>.from(state.extraDrops);
    while (extra.length < extraSlots) {
      extra.add(const MockLocation(id: '', label: '', address: ''));
    }
    extra[index - 1] = location;
    final List<String?> keys = List<String?>.from(state.extraDropConfirmedKeys);
    while (keys.length < extraSlots) {
      keys.add(null);
    }
    keys[index - 1] = BookingDraft.locationKey(location);
    if (extra.length > extraSlots) {
      extra.removeRange(extraSlots, extra.length);
    }
    if (keys.length > extraSlots) {
      keys.removeRange(extraSlots, keys.length);
    }
    state = state.copyWith(
      extraDrops: extra,
      extraDropConfirmedKeys: keys,
      clearQuotedNetPayable: true,
      clearRoute: true,
    );
  }

  /// Records a Google Routes result. A missing result clears any previous
  /// distance so a straight-line figure cannot linger.
  void recordRoute({int? distanceMeters, int? durationSeconds}) {
    if (distanceMeters == null || distanceMeters <= 0) {
      state = state.copyWith(clearRoute: true);
      return;
    }
    state = state.copyWith(
      routeDistanceMeters: distanceMeters,
      routeDurationSeconds: durationSeconds ?? 0,
    );
  }

  void applyQuotedPayable(double amount) {
    state = state.copyWith(quotedNetPayable: amount);
  }

  void beginNewBooking() {
    state = BookingDraft(
      pickup: state.pickup ?? MockData.locations[4],
    );
  }

  void setDeliveryMode(DeliveryMode mode) {
    if (mode == DeliveryMode.single) {
      state = state.copyWith(
        deliveryMode: mode,
        dropCount: 1,
        extraDrops: const [],
        extraDropConfirmedKeys: const <String?>[],
      );
      return;
    }
    state = state.copyWith(deliveryMode: mode, dropCount: 2);
  }

  void setDropCount(int count) {
    final int clamped = count.clamp(2, BookingLimits.maxDeliveryStops);
    final List<MockLocation> extra = List<MockLocation>.from(state.extraDrops);
    while (extra.length < clamped - 1) {
      extra.add(const MockLocation(id: '', label: '', address: ''));
    }
    if (extra.length > clamped - 1) {
      extra.removeRange(clamped - 1, extra.length);
    }
    final List<String?> keys =
        List<String?>.from(state.extraDropConfirmedKeys);
    while (keys.length < clamped - 1) {
      keys.add(null);
    }
    if (keys.length > clamped - 1) {
      keys.removeRange(clamped - 1, keys.length);
    }
    state = state.copyWith(
      dropCount: clamped,
      extraDrops: extra,
      extraDropConfirmedKeys: keys,
    );
  }

  void setDropAt(int index, MockLocation location) {
    if (index <= 0) {
      final bool same = BookingDraft.samePin(state.drop, location);
      state = state.copyWith(
        drop: location,
        clearRoute: !same,
        clearDropConfirmation: !same,
      );
      return;
    }
    final int extraSlots = state.dropCount - 1;
    if (index > extraSlots) {
      return;
    }
    final List<MockLocation> extra = List<MockLocation>.from(state.extraDrops);
    while (extra.length < extraSlots) {
      extra.add(const MockLocation(id: '', label: '', address: ''));
    }
    final bool same = BookingDraft.samePin(extra[index - 1], location);
    extra[index - 1] = location;
    if (extra.length > extraSlots) {
      extra.removeRange(extraSlots, extra.length);
    }
    final List<String?> keys =
        List<String?>.from(state.extraDropConfirmedKeys);
    while (keys.length < extraSlots) {
      keys.add(null);
    }
    if (!same) {
      keys[index - 1] = null;
    }
    if (keys.length > extraSlots) {
      keys.removeRange(extraSlots, keys.length);
    }
    state = state.copyWith(
      extraDrops: extra,
      extraDropConfirmedKeys: keys,
      clearQuotedNetPayable: true,
      clearRoute: !same,
    );
  }

  void clearDropAt(int index) {
    setDropAt(index, const MockLocation(id: '', label: '', address: ''));
  }

  void setVehicle(MockVehicle vehicle) {
    state = state.copyWith(vehicle: vehicle, clearQuotedNetPayable: true);
  }

  void setServiceFamily(ServiceFamily family) {
    state = state.copyWith(
      serviceFamily: family,
      clearVehicle: true,
    );
  }

  void clearServiceFamily() {
    state = state.copyWith(clearServiceFamily: true);
  }

  void setCategory(String id) => state = state.copyWith(categoryId: id);

  void setSize(String id) => state = state.copyWith(sizeId: id);

  void setWeight(double kg) => state = state.copyWith(
        weightKg: kg.clamp(0.5, 1000),
        clearQuotedNetPayable: true,
      );

  void setInstructions(String value) =>
      state = state.copyWith(instructions: value);

  void setFragile(bool value) => state = state.copyWith(fragile: value);

  void setCod(bool value) => state = state.copyWith(
        cod: value,
        customerMethodMode:
            value ? PayerMethodMode.cash : PayerMethodMode.online,
        paymentMethod:
            value ? TripPaymentMethod.cash : TripPaymentMethod.online,
      );

  void setWhoPays(PaymentWhoPays value) {
    final double total = state.payableTotal;
    state = state.copyWith(
      whoPays: value,
      customerAmount: value == PaymentWhoPays.split
          ? FareEngine.round2(total / 2)
          : value == PaymentWhoPays.customer
              ? total
              : 0,
    );
  }

  void setCustomerAmount(double value) {
    final double total = state.payableTotal;
    final double amount = FareEngine.round2(value.clamp(0, total));
    state = state.copyWith(
      whoPays: PaymentWhoPays.split,
      customerAmount: amount,
    );
  }

  void setCustomerMethodMode(PayerMethodMode value) {
    final double due = state.customerResponsibility;
    state = state.copyWith(
      customerMethodMode: value,
      customerOnlineAmount:
          value == PayerMethodMode.split ? FareEngine.round2(due / 2) : due,
      paymentMethod: value == PayerMethodMode.cash
          ? TripPaymentMethod.cash
          : TripPaymentMethod.online,
      cod: value == PayerMethodMode.cash,
    );
  }

  void setReceiverMethodMode(PayerMethodMode value) {
    final double due = state.receiverResponsibility;
    state = state.copyWith(
      receiverMethodMode: value,
      receiverOnlineAmount:
          value == PayerMethodMode.split ? FareEngine.round2(due / 2) : due,
    );
  }

  void setCustomerOnlineAmount(double value) =>
      state = state.copyWith(customerOnlineAmount: value);

  void setReceiverOnlineAmount(double value) =>
      state = state.copyWith(receiverOnlineAmount: value);

  void setPaymentMethod(TripPaymentMethod value) =>
      setCustomerMethodMode(
        value == TripPaymentMethod.cash
            ? PayerMethodMode.cash
            : PayerMethodMode.online,
      );

  void setScheduledAt(DateTime? value) {
    if (value == null) {
      state = state.copyWith(clearScheduledAt: true);
    } else {
      state = state.copyWith(scheduledAt: value);
    }
  }

  void attachActive(MockOrder order) {
    state = state.copyWith(activeOrder: order);
  }

  MockOrder applyToOrder(
    MockOrder order,
    MockOrder Function(MockOrder current) transform,
  ) {
    final MockOrder next = transform(order);
    if (state.activeOrder?.id == order.id) {
      state = state.copyWith(activeOrder: next);
    }
    return next;
  }

  MockOrder? markReceiverUnavailable({double officeDistanceKm = 5}) {
    final MockOrder? current = state.activeOrder;
    if (current == null) {
      return null;
    }
    final FailedDeliveryRecord record = FailedDeliveryEngine.open(
      originalDropLabel: current.drop.label,
      officeDistanceKm: officeDistanceKm,
    );
    final MockOrder next = current.copyWith(
      status: OrderStatus.atCompanyOffice,
      etaMinutes: 0,
      failedReason: record.reasonLabel,
      officeCompensation: record.riderOfficeCompensation,
      officeDistanceKm: officeDistanceKm,
      customerNotice: FailedDeliveryEngine.customerNoticeBody,
    );
    state = state.copyWith(activeOrder: next);
    return next;
  }

  MockOrder? _pendingOriginalAfterResend;

  MockOrder? requestResend({double resendDistanceKm = 5}) {
    final MockOrder? current = state.activeOrder;
    if (current == null || !current.canRequestResend) {
      return null;
    }
    final CompanyOffice office = PlatformRules.current.office;
    final bool ended = OrderLifecycle.originalTripEnded(current.canonicalStatus);
    final ResendQuote quote = ResendEngine.quote(
      originalTripEnded: ended,
      distanceKm: resendDistanceKm,
      baseFare: ended ? current.confirmedTripFare : 0,
    );
    final String resendId = OrderIds.nextDisplayId();
    final PaymentAllocation resendAllocation =
        current.paymentPlan.allocation.onlineTotal > 0
            ? PaymentAllocation(customerOnline: quote.customerPays)
            : PaymentAllocation(customerCash: quote.customerPays);
    final MockOrder resend = MockOrder(
      id: resendId,
      status: OrderStatus.searching,
      pickup: MockLocation(
        id: office.id,
        label: office.name,
        address: office.address,
        city: office.city,
        latitude: office.latitude,
        longitude: office.longitude,
      ),
      drop: current.drop,
      vehicle: current.vehicle,
      fare: quote.customerPays,
      tripFare: ended ? quote.baseFare : quote.resendSurcharge,
      additionalCharge: quote.resendSurcharge,
      createdAt: DateTime.now(),
      packageLabel: current.packageLabel,
      weightKg: current.weightKg,
      parentOrderId: current.id,
      resendCharge: quote.resendSurcharge,
      paymentMethod: current.paymentMethod,
      customerResponsibility: quote.customerPays,
      receiverResponsibility: 0,
      customerOnline: resendAllocation.customerOnline,
      customerCash: resendAllocation.customerCash,
      paymentTransactions: PaymentEngine.plannedTransactions(
        orderId: resendId,
        allocation: resendAllocation,
      ),
      resendCaseLabel: ended
          ? 'Ride ended — base fare + ₹10/km'
          : 'Ride still active — ₹10/km (₹8 rider / ₹2 company)',
    );
    _pendingOriginalAfterResend = current.copyWith(
      status: OrderStatus.resendRequested,
      resendCharge: quote.customerPays,
      additionalCharge: quote.resendSurcharge,
      resendCaseLabel: resend.resendCaseLabel,
    );
    state = state.copyWith(activeOrder: resend);
    return resend;
  }

  MockOrder? takePendingOriginalAfterResend() {
    final MockOrder? original = _pendingOriginalAfterResend;
    _pendingOriginalAfterResend = null;
    return original;
  }

  void assignRider() {
    _patchActive(
      (o) => o.copyWith(
        status: OrderStatus.assigned,
        rider: MockData.demoRider,
        etaMinutes: 12,
      ),
    );
  }

  void acceptRider() {
    _patchActive(
      (o) => o.copyWith(
        status: OrderStatus.accepted,
        etaMinutes: 10,
      ),
    );
  }

  void markArriving() {
    _patchActive((o) => o.copyWith(status: OrderStatus.arriving, etaMinutes: 8));
  }

  void markPickedUp() {
    _patchActive((o) => o.copyWith(status: OrderStatus.pickup, etaMinutes: 22));
  }

  void markInTransit() {
    _patchActive(
      (o) => o.copyWith(status: OrderStatus.inTransit, etaMinutes: 18),
    );
  }

  void markNearDestination() {
    _patchActive(
      (o) => o.copyWith(status: OrderStatus.nearDestination, etaMinutes: 4),
    );
  }

  MockOrder? markDelivered({String invoiceEmail = '', MockOrder? order}) {
    final MockOrder? current = order ?? state.activeOrder;
    if (current == null) {
      return null;
    }
    return applyToOrder(
      current,
      (o) => o.copyWith(
        status: OrderStatus.delivered,
        etaMinutes: 0,
        invoiceSent: invoiceEmail.trim().isNotEmpty,
        invoiceEmail: invoiceEmail.trim(),
      ),
    );
  }

  /// Advances one demo status step; returns the updated order, or null.
  MockOrder? advanceDemoStatus({MockOrder? order}) {
    final MockOrder? current = order ?? state.activeOrder;
    if (current == null) {
      return null;
    }
    switch (current.status) {
      case OrderStatus.assigned:
        return applyToOrder(
          current,
          (o) => o.copyWith(status: OrderStatus.accepted, etaMinutes: 10),
        );
      case OrderStatus.accepted:
        return applyToOrder(
          current,
          (o) => o.copyWith(status: OrderStatus.arriving, etaMinutes: 8),
        );
      case OrderStatus.arriving:
        return applyToOrder(
          current,
          (o) => o.copyWith(status: OrderStatus.pickup, etaMinutes: 22),
        );
      case OrderStatus.pickup:
        return applyToOrder(
          current,
          (o) => o.copyWith(status: OrderStatus.inTransit, etaMinutes: 18),
        );
      case OrderStatus.inTransit:
        return applyToOrder(
          current,
          (o) => o.copyWith(status: OrderStatus.nearDestination, etaMinutes: 4),
        );
      case OrderStatus.nearDestination:
      case OrderStatus.searching:
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
      case OrderStatus.failed:
      case OrderStatus.atCompanyOffice:
      case OrderStatus.resendRequested:
        return null;
    }
  }

  MockOrder? cancelBooking({MockOrder? order}) {
    final MockOrder? current = order ?? state.activeOrder;
    if (current == null) {
      return null;
    }
    final CancellationQuote quote = current.cancellationQuote;
    if (!quote.allowed) {
      return null;
    }
    return applyToOrder(
      current,
      (o) => o.copyWith(
        status: OrderStatus.cancelled,
        etaMinutes: 0,
        cancellationFee: quote.fee,
      ),
    );
  }

  void reset() {
    _manualPickup = false;
    state = BookingDraft(pickup: MockData.locations[4]);
  }

  void _patchActive(MockOrder Function(MockOrder current) transform) {
    final MockOrder? current = state.activeOrder;
    if (current == null) {
      return;
    }
    state = state.copyWith(activeOrder: transform(current));
  }
}

final bookingDraftProvider =
    StateNotifierProvider<BookingDraftNotifier, BookingDraft>((ref) {
  return BookingDraftNotifier();
});
