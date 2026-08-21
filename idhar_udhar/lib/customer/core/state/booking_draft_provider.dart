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

  bool get canSubmitStops => incompleteStopMessage == null;

  FareConfig get _fareConfig {
    final String name = (vehicle?.name ?? 'Bike').toLowerCase();
    if (name.contains('auto') || name.contains('three')) {
      return FareCatalog.currentFor('auto');
    }
    if (name.contains('truck') || name.contains('tempo')) {
      return FareCatalog.currentFor('truck');
    }
    return FareCatalog.currentFor('bike');
  }

  List<DeliveryStop> get orderedStops {
    final List<DeliveryStop> stops = <DeliveryStop>[];
    final MockLocation? from = pickup;
    if (from != null) {
      stops.add(
        DeliveryStop(
          id: from.id,
          sequence: 0,
          label: from.label,
          address: from.address,
          city: from.city,
          latitude: from.latitude,
          longitude: from.longitude,
          kind: DeliveryStopKind.pickup,
        ),
      );
    }
    for (int i = 0; i < allDrops.length; i++) {
      final MockLocation loc = allDrops[i];
      stops.add(
        DeliveryStop(
          id: loc.id,
          sequence: i + 1,
          label: loc.label,
          address: loc.address,
          city: loc.city,
          latitude: loc.latitude,
          longitude: loc.longitude,
        ),
      );
    }
    return stops;
  }

  FareQuote get fareQuote {
    final double km = GeoMath.routeKm(orderedStops);
    return FareEngine.quote(
      config: _fareConfig,
      distanceKm: km,
      stopCount: allDrops.length,
    );
  }

  /// Admin-controlled fare. GST is not applied.
  FareBreakdown get fareBreakdown {
    final FareQuote quote = fareQuote;
    return FareBreakdown(
      baseFare: quote.baseFare,
      distanceCharge: quote.distanceCharge,
      waitingCharge: quote.waitingCharge,
      surgeCharge: quote.surgeCharge,
      tollCharge: quote.tollCharge,
      parkingCharge: quote.parkingCharge,
      discount: quote.discount,
      tax: 0,
      netTotal: quote.netTotal,
    );
  }

  double get estimatedFare => fareBreakdown.total;

  double get payableTotal => FareEngine.round2(fareQuote.netTotal);

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
    );
  }
}

class BookingDraftNotifier extends StateNotifier<BookingDraft> {
  BookingDraftNotifier()
      : super(BookingDraft(pickup: MockData.locations[4]));

  final IdempotencyGuard _createGuard = IdempotencyGuard();
  String _draftToken = 'draft_0';

  String _nextDraftToken() =>
      'draft_${DateTime.now().microsecondsSinceEpoch}';

  void setPickup(MockLocation location) {
    state = state.copyWith(pickup: location);
  }

  void setDrop(MockLocation location) {
    state = state.copyWith(drop: location);
  }

  void beginNewBooking() {
    _draftToken = _nextDraftToken();
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
    state = state.copyWith(dropCount: clamped, extraDrops: extra);
  }

  void setDropAt(int index, MockLocation location) {
    if (index <= 0) {
      state = state.copyWith(drop: location);
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
    if (extra.length > extraSlots) {
      extra.removeRange(extraSlots, extra.length);
    }
    state = state.copyWith(extraDrops: extra);
  }

  void clearDropAt(int index) {
    setDropAt(index, const MockLocation(id: '', label: '', address: ''));
  }

  void setVehicle(MockVehicle vehicle) {
    state = state.copyWith(vehicle: vehicle);
  }

  void setServiceFamily(ServiceFamily family) {
    final List<MockVehicle> options = MockData.vehiclesForFamily(family);
    if (options.length == 1) {
      state = state.copyWith(
        serviceFamily: family,
        vehicle: options.first,
      );
    } else {
      state = state.copyWith(
        serviceFamily: family,
        clearVehicle: true,
      );
    }
  }

  void clearServiceFamily() {
    state = state.copyWith(clearServiceFamily: true);
  }

  void setCategory(String id) => state = state.copyWith(categoryId: id);

  void setSize(String id) => state = state.copyWith(sizeId: id);

  void setWeight(double kg) =>
      state = state.copyWith(weightKg: kg.clamp(0.5, 1000));

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

  MockOrder? confirmBooking() {
    if (!state.canSubmitStops) {
      return null;
    }
    if (state.paymentValidationError != null) {
      return null;
    }
    return _createGuard.run(_draftToken, _createConfirmedOrder);
  }

  MockOrder _createConfirmedOrder() {
    final MockLocation pickup = state.pickup!;
    final List<MockLocation> drops = state.allDrops;
    final MockVehicle vehicle = state.vehicle ?? MockData.vehicles.first;
    final FareQuote quote = state.fareQuote;
    final PaymentAllocation allocation = state.paymentAllocation;
    final PaymentResponsibility responsibility = state.paymentResponsibility;
    final String orderId = OrderIds.nextDisplayId();
    final MockOrder order = MockOrder(
      id: orderId,
      status: OrderStatus.searching,
      pickup: pickup,
      drop: drops.first,
      vehicle: vehicle,
      fare: quote.netTotal,
      tripFare: quote.tripFare,
      discount: quote.discount,
      createdAt: DateTime.now(),
      customerId: 'customer_session',
      packageLabel: state.categoryLabel,
      weightKg: state.weightKg,
      instructions: state.instructions,
      etaMinutes: vehicle.etaMinutes,
      scheduledAt: state.scheduledAt,
      extraDrops: drops.skip(1).toList(growable: false),
      fareConfigVersionId: quote.configVersionId,
      paymentMethod: state.derivedPaymentMethod,
      customerResponsibility: responsibility.customerAmount,
      receiverResponsibility: responsibility.receiverAmount,
      customerOnline: allocation.customerOnline,
      customerCash: allocation.customerCash,
      receiverOnline: allocation.receiverOnline,
      receiverCash: allocation.receiverCash,
      paymentTransactions: PaymentEngine.plannedTransactions(
        orderId: orderId,
        allocation: allocation,
      ),
    );
    state = state.copyWith(activeOrder: order);
    return order;
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
    _draftToken = _nextDraftToken();
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
