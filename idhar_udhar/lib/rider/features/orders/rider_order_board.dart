import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/json_codec.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';
import 'package:idhar_udhar/shared/api/wallet_api.dart';

import '../../data/models/rider_order.dart';
import '../../routing/rider_routes.dart';

/// Newest earnings rows to read while looking for another live delivery.
///
/// `GET /v1/rider/earnings` is an ORIGINAL finance snapshot, frozen when the
/// order is delivered. Trip History uses `GET /v1/rider/orders` instead.
/// Earnings only fill fare and rider amount, and a missing snapshot does not
/// drop the trip. A remembered order id and accepted live offers are confirmed
/// with `GET /v1/rider/orders/:id`. The in-memory order is always checked.
const int riderRunningScanLimit = 8;

const int riderHistoryPageSize = 20;

enum RiderHistoryFilter { all, running, completed, cancelled }

class RiderWalletLedgerEntry {
  const RiderWalletLedgerEntry({
    required this.id,
    required this.direction,
    required this.amount,
    required this.entryType,
    required this.createdAt,
    this.relatedOrderId,
    this.relatedPaymentTransactionId,
  });

  final String id;
  final String direction;
  final double amount;
  final String entryType;
  final DateTime? createdAt;
  final String? relatedOrderId;

  /// Present when the ledger row points at a payment transaction.
  /// The ledger payload has no Success/Failed status.
  final String? relatedPaymentTransactionId;

  bool get isCredit => direction == 'CREDIT';
}

class RiderHistoryRecord {
  const RiderHistoryRecord({
    required this.orderId,
    required this.displayId,
    required this.when,
    required this.detailsLoaded,
    this.crn,
    this.pickup,
    this.drop,
    this.canonicalStatus,
    this.tripFare,
    this.riderAmount,
    this.paymentLabel,
  });

  final String orderId;
  final String displayId;
  final DateTime? when;
  final bool detailsLoaded;
  final String? crn;
  final String? pickup;
  final String? drop;
  final String? canonicalStatus;
  final double? tripFare;
  final double? riderAmount;
  final String? paymentLabel;
}

class RiderHistorySnapshot {
  const RiderHistorySnapshot({
    required this.records,
    required this.total,
    required this.failedDetails,
  });

  final List<RiderHistoryRecord> records;
  final int total;
  final int failedDetails;

  bool get hasMore => records.length < total;
}

class RiderTrackedDelivery {
  const RiderTrackedDelivery({
    required this.order,
    required this.canonicalStatus,
    this.fromLocalOnly = false,
  });

  final RiderOrder order;
  final String canonicalStatus;
  final bool fromLocalOnly;
}

class RiderRunningBoard {
  const RiderRunningBoard({
    required this.running,
    required this.clearLocalOrder,
    this.clearRemembered = false,
    this.errorMessage,
  });

  final List<RiderTrackedDelivery> running;
  final bool clearLocalOrder;
  final bool clearRemembered;
  final String? errorMessage;

  static const RiderRunningBoard empty = RiderRunningBoard(
    running: <RiderTrackedDelivery>[],
    clearLocalOrder: false,
  );
}

/// Cash, online, or both from a payment plan. Null when the plan does not say.
String? paymentMethodLabel({
  required double cash,
  required double online,
}) {
  final bool hasCash = cash > 0;
  final bool hasOnline = online > 0;
  if (hasCash && hasOnline) {
    return 'Cash + Online';
  }
  if (hasCash) {
    return 'Cash';
  }
  if (hasOnline) {
    return 'Online';
  }
  return null;
}

class RunningDeliveryOpenPlan {
  const RunningDeliveryOpenPlan({
    required this.route,
    required this.adopt,
    required this.readOnly,
  });

  final String route;
  final bool adopt;
  final bool readOnly;
}

String ledgerEntryTitle(String entryType) {
  switch (entryType) {
    case 'EARNING':
      return 'Earning';
    case 'RECHARGE':
      return 'Recharge';
    case 'PAYOUT':
      return 'Payout';
    case 'ADJUSTMENT':
      return 'Adjustment';
    case 'COD_SETTLEMENT':
      return 'COD settlement';
    case 'CANCELLATION_SHARE':
      return 'Cancellation share';
    case 'RESEND_EARNING':
      return 'Resend earning';
    default:
      final String raw = entryType.trim();
      return raw.isEmpty ? 'Ledger entry' : raw;
  }
}

String historyStatusLabel(String? canonicalStatus) {
  final String canonical = (canonicalStatus ?? '').trim();
  if (canonical.isEmpty) {
    return '';
  }
  if (canonical == 'CANCELLED') {
    return 'Cancelled';
  }
  if (canonical == 'RESEND_REQUESTED') {
    return 'Resend requested';
  }
  if (canonical == 'RESEND_IN_PROGRESS') {
    return 'Resend in progress';
  }
  if (canonical == 'RESEND_COMPLETED') {
    return 'Resend completed';
  }
  return OrderMapper.tryRiderLifecycle(canonical)?.label ?? canonical;
}

/// Terminal for the rider board. Matches backend `TERMINAL_STATUSES`.
/// `PARCEL_AT_COMPANY_OFFICE` stays live: the rider still holds the parcel
/// and cannot accept another order.
bool riderCanonicalIsFinished(String canonicalStatus) {
  switch (canonicalStatus.trim()) {
    case 'DELIVERED':
    case 'CANCELLED':
    case 'RESEND_COMPLETED':
      return true;
    default:
      return false;
  }
}

bool riderCanonicalHasDeliveryPhase(String canonicalStatus) {
  return OrderMapper.tryRiderLifecycle(canonicalStatus.trim()) != null;
}

bool riderCanonicalIsRunning(String canonicalStatus) {
  final String canonical = canonicalStatus.trim();
  if (canonical.isEmpty || riderCanonicalIsFinished(canonical)) {
    return false;
  }
  if (canonical == 'RESEND_REQUESTED' || canonical == 'RESEND_IN_PROGRESS') {
    return true;
  }
  return riderCanonicalHasDeliveryPhase(canonical);
}

bool localDeliveryStillRunning(DeliveryLifecycleStatus status) {
  switch (status) {
    case DeliveryLifecycleStatus.delivered:
      return false;
    case DeliveryLifecycleStatus.accepted:
    case DeliveryLifecycleStatus.goingToPickup:
    case DeliveryLifecycleStatus.arrivedAtPickup:
    case DeliveryLifecycleStatus.packagePickedUp:
    case DeliveryLifecycleStatus.goingToDrop:
    case DeliveryLifecycleStatus.receiverUnavailable:
    case DeliveryLifecycleStatus.parcelAtCompanyOffice:
      return true;
  }
}

bool historyRecordMatches(
  RiderHistoryRecord record,
  RiderHistoryFilter filter,
) {
  switch (filter) {
    case RiderHistoryFilter.all:
      return true;
    case RiderHistoryFilter.running:
    case RiderHistoryFilter.completed:
    case RiderHistoryFilter.cancelled:
      final String? canonical = record.canonicalStatus;
      if (!record.detailsLoaded || canonical == null) {
        return false;
      }
      switch (filter) {
        case RiderHistoryFilter.running:
          return riderCanonicalIsRunning(canonical);
        case RiderHistoryFilter.completed:
          return canonical == 'DELIVERED' || canonical == 'RESEND_COMPLETED';
        case RiderHistoryFilter.cancelled:
          return canonical == 'CANCELLED';
        case RiderHistoryFilter.all:
          return true;
      }
  }
}

RiderWalletLedgerEntry? tryParseWalletLedgerEntry(Map<String, Object?> json) {
  final String id = (jsonString(json['wallet_ledger_id']) ?? '').trim();
  final String direction =
      (jsonString(json['direction']) ?? '').trim().toUpperCase();
  if (id.isEmpty || (direction != 'CREDIT' && direction != 'DEBIT')) {
    return null;
  }
  final double? amount = _ledgerAmount(json['amount']);
  if (amount == null) {
    return null;
  }
  final String? related = _blankToNull(jsonString(json['related_order_id']));
  final String? paymentId =
      _blankToNull(jsonString(json['related_payment_transaction_id']));
  return RiderWalletLedgerEntry(
    id: id,
    direction: direction,
    amount: amount,
    entryType: (jsonString(json['entry_type']) ?? '').trim(),
    createdAt: jsonDate(json['created_at']),
    relatedOrderId: related,
    relatedPaymentTransactionId: paymentId,
  );
}

double? _ledgerAmount(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}

List<RiderWalletLedgerEntry> parseWalletLedger(
  List<Map<String, Object?>> rows,
) {
  final List<RiderWalletLedgerEntry> entries = <RiderWalletLedgerEntry>[
    for (final Map<String, Object?> row in rows)
      if (tryParseWalletLedgerEntry(row)
          case final RiderWalletLedgerEntry entry)
        entry,
  ];
  entries.sort((RiderWalletLedgerEntry a, RiderWalletLedgerEntry b) {
    final DateTime? left = a.createdAt;
    final DateTime? right = b.createdAt;
    if (left == null && right == null) {
      return 0;
    }
    if (left == null) {
      return 1;
    }
    if (right == null) {
      return -1;
    }
    return right.compareTo(left);
  });
  return entries;
}

RiderOrder riderOrderFromApi(ApiOrder order) {
  ApiStop? pickup;
  ApiStop? drop;
  for (final ApiStop stop in order.stops) {
    if (stop.stopType == 'PICKUP' &&
        (pickup == null || stop.sequence < pickup.sequence)) {
      pickup = stop;
    }
    if (stop.stopType == 'DROP' &&
        (drop == null || stop.sequence < drop.sequence)) {
      drop = stop;
    }
  }
  final String pickupText = _address(pickup?.addressText, order.pickupAddress);
  final String dropText = _address(drop?.addressText, order.dropAddress);
  final String display =
      order.displayId.trim().isEmpty ? order.orderId : order.displayId.trim();
  return RiderOrder(
    id: display,
    backendOrderId: order.orderId,
    crn: order.crn,
    pickup: pickupText,
    drop: dropText,
    distanceKm: order.distanceKm ?? 0,
    estimatedEarnings: order.riderAmount ?? 0,
    estimatedMinutes: 0,
    customerMaskedName: _presentName(order.customerName),
    customerMaskedPhone: order.customerPhone?.trim() ?? '',
    senderName: order.customerName?.trim() ?? '',
    senderPhone: order.customerPhone?.trim() ?? '',
    receiverName: drop?.contactName?.trim() ?? '',
    receiverPhone: drop?.contactPhone?.trim() ?? '',
    vehicleName: order.vehicleCategoryName?.trim() ?? '',
    tripAmount: order.tripFare ?? 0,
    riderAmount: order.riderAmount ?? 0,
    pickupLatitude: pickup?.latitude,
    pickupLongitude: pickup?.longitude,
    dropLatitude: drop?.latitude,
    dropLongitude: drop?.longitude,
  );
}

RunningDeliveryOpenPlan planRunningDeliveryOpen({
  required String tappedOrderId,
  required String? localOrderId,
  required bool localStillRunning,
  required bool hasRiderPhase,
}) {
  final String tapped = tappedOrderId.trim();
  final String? local = localOrderId?.trim();
  final bool same = local != null && local.isNotEmpty && local == tapped;
  if (!hasRiderPhase) {
    return RunningDeliveryOpenPlan(
      route: '${RiderRoutes.pastOrder}?id=$tapped',
      adopt: false,
      readOnly: true,
    );
  }
  if (same || !localStillRunning) {
    return RunningDeliveryOpenPlan(
      route: RiderRoutes.activeDelivery,
      adopt: !same,
      readOnly: false,
    );
  }
  return RunningDeliveryOpenPlan(
    route: '${RiderRoutes.pastOrder}?id=$tapped',
    adopt: false,
    readOnly: true,
  );
}

Future<RiderHistorySnapshot> loadRiderOrderHistory({
  required Future<RiderHistoryPage> Function(String? cursor) orders,
  required Future<List<RiderEarningRow>> Function() earnings,
  required Future<ApiOrder> Function(String orderId) order,
  required int limit,
  Future<String?> Function(String orderId)? paymentLabel,
}) async {
  if (limit <= 0) {
    return const RiderHistorySnapshot(
      records: <RiderHistoryRecord>[],
      total: 0,
      failedDetails: 0,
    );
  }
  final List<RiderHistoryOrder> listed = <RiderHistoryOrder>[];
  String? cursor;
  var hasMore = false;
  while (listed.length < limit) {
    final RiderHistoryPage page = await orders(cursor);
    if (page.orders.isEmpty) {
      hasMore = false;
      break;
    }
    listed.addAll(page.orders);
    if (page.nextCursor == null) {
      hasMore = listed.length > limit;
      break;
    }
    if (listed.length >= limit) {
      hasMore = true;
      break;
    }
    cursor = page.nextCursor;
  }
  final List<RiderHistoryOrder> slice =
      listed.take(limit).toList(growable: false);
  final Map<String, RiderEarningRow> earned = <String, RiderEarningRow>{};
  if (slice.isNotEmpty) {
    try {
      for (final RiderEarningRow row in await earnings()) {
        final String id = row.orderId.trim();
        if (id.isNotEmpty) {
          earned[id] = row;
        }
      }
    } catch (_) {
      earned.clear();
    }
  }
  final List<RiderHistoryRecord> records = <RiderHistoryRecord>[];
  var failed = 0;
  for (final RiderHistoryOrder listedOrder in slice) {
    ApiOrder? detail;
    try {
      detail = await order(listedOrder.orderId);
    } catch (_) {
      failed += 1;
    }
    final RiderEarningRow? earning = earned[listedOrder.orderId];
    String? paidWith;
    if (paymentLabel != null) {
      try {
        final String? label = (await paymentLabel(listedOrder.orderId))?.trim();
        if (label != null && label.isNotEmpty) {
          paidWith = label;
        }
      } catch (_) {
        paidWith = null;
      }
    }
    records.add(
      RiderHistoryRecord(
        orderId: listedOrder.orderId,
        displayId: detail != null && detail.displayId.trim().isNotEmpty
            ? detail.displayId.trim()
            : listedOrder.displayId.trim(),
        crn: _blankToNull(detail?.crn) ?? listedOrder.crn,
        pickup: _optionalAddress(
          _optionalAddress(
            detail?.pickupAddress,
            _stopAddress(detail, 'PICKUP'),
          ),
          listedOrder.pickupAddress,
        ),
        drop: _optionalAddress(
          _optionalAddress(
            detail?.dropAddress,
            _stopAddress(detail, 'DROP'),
          ),
          listedOrder.dropAddress,
        ),
        canonicalStatus:
            _blankToNull(detail?.canonicalStatus) ?? listedOrder.canonicalStatus,
        when: earning?.frozenAt ?? listedOrder.createdAt ?? detail?.createdAt,
        tripFare: earning?.tripFare,
        riderAmount: earning?.riderAmount,
        paymentLabel: paidWith,
        detailsLoaded: detail != null,
      ),
    );
  }
  return RiderHistorySnapshot(
    records: records,
    total: hasMore ? records.length + 1 : records.length,
    failedDetails: failed,
  );
}

Future<RiderRunningBoard> loadRunningDeliveries({
  required RiderOrder? local,
  required DeliveryLifecycleStatus localStatus,
  required Future<List<RiderEarningRow>> Function() earnings,
  required Future<ApiOrder> Function(String orderId) order,
  String? rememberedOrderId,
  List<String> extraOrderIds = const <String>[],
  int scanLimit = riderRunningScanLimit,
}) async {
  final Map<String, ApiOrder> fetched = <String, ApiOrder>{};
  Future<ApiOrder?> read(String orderId) async {
    final String id = orderId.trim();
    if (id.isEmpty) {
      return null;
    }
    final ApiOrder? cached = fetched[id];
    if (cached != null) {
      return cached;
    }
    try {
      final ApiOrder loaded = await order(id);
      fetched[id] = loaded;
      return loaded;
    } catch (_) {
      return null;
    }
  }

  final List<RiderTrackedDelivery> running = <RiderTrackedDelivery>[];
  final String localId = (local?.backendOrderId ?? '').trim();
  var clearLocal = false;
  var clearRemembered = false;
  var rememberedFailed = false;
  var sawLocal = false;
  if (local != null && localId.isNotEmpty) {
    sawLocal = true;
    final ApiOrder? remote = await read(localId);
    if (remote == null) {
      if (localDeliveryStillRunning(localStatus)) {
        running.add(
          RiderTrackedDelivery(
            order: local,
            canonicalStatus: '',
            fromLocalOnly: true,
          ),
        );
      }
    } else if (riderCanonicalIsFinished(remote.canonicalStatus)) {
      clearLocal = true;
    } else if (riderCanonicalIsRunning(remote.canonicalStatus)) {
      running.add(
        RiderTrackedDelivery(
          order: riderOrderFromApi(remote),
          canonicalStatus: remote.canonicalStatus,
        ),
      );
    }
  }

  final String remembered = (rememberedOrderId ?? '').trim();
  if (remembered.isNotEmpty && remembered != localId) {
    final ApiOrder? remote = await read(remembered);
    if (remote == null) {
      rememberedFailed = true;
    } else if (riderCanonicalIsRunning(remote.canonicalStatus)) {
      running.add(
        RiderTrackedDelivery(
          order: riderOrderFromApi(remote),
          canonicalStatus: remote.canonicalStatus,
        ),
      );
    } else {
      clearRemembered = true;
    }
  }

  var hintFailed = false;
  for (final String raw in extraOrderIds) {
    final String id = raw.trim();
    if (id.isEmpty || id == localId || fetched.containsKey(id)) {
      continue;
    }
    final ApiOrder? remote = await read(id);
    if (remote == null) {
      hintFailed = true;
    } else if (riderCanonicalIsRunning(remote.canonicalStatus)) {
      running.add(
        RiderTrackedDelivery(
          order: riderOrderFromApi(remote),
          canonicalStatus: remote.canonicalStatus,
        ),
      );
    }
  }

  List<RiderEarningRow> rows = const <RiderEarningRow>[];
  Object? earningsError;
  try {
    rows = await earnings();
  } catch (error) {
    earningsError = error;
  }
  final int bounded = scanLimit < 0 ? 0 : scanLimit;
  for (final RiderEarningRow row in rows.reversed.take(bounded)) {
    final String id = row.orderId.trim();
    if (id.isEmpty || id == localId || fetched.containsKey(id)) {
      final ApiOrder? already = fetched[id];
      if (already != null &&
          id != localId &&
          riderCanonicalIsRunning(already.canonicalStatus)) {
        running.add(
          RiderTrackedDelivery(
            order: riderOrderFromApi(already),
            canonicalStatus: already.canonicalStatus,
          ),
        );
      }
      continue;
    }
    final ApiOrder? remote = await read(id);
    if (remote != null && riderCanonicalIsRunning(remote.canonicalStatus)) {
      running.add(
        RiderTrackedDelivery(
          order: riderOrderFromApi(remote),
          canonicalStatus: remote.canonicalStatus,
        ),
      );
    }
  }

  final Set<String> seen = <String>{};
  final List<RiderTrackedDelivery> unique = <RiderTrackedDelivery>[
    for (final RiderTrackedDelivery item in running)
      if (seen.add((item.order.backendOrderId ?? item.order.id).trim())) item,
  ];
  if (unique.isEmpty && !sawLocal && (rememberedFailed || hintFailed)) {
    return RiderRunningBoard(
      running: const <RiderTrackedDelivery>[],
      clearLocalOrder: clearLocal,
      clearRemembered: clearRemembered,
      errorMessage: 'The saved delivery could not be checked.',
    );
  }
  if (earningsError != null && unique.isEmpty && !sawLocal) {
    final String message = earningsError is ApiException
        ? earningsError.message
        : 'Active deliveries could not be loaded.';
    return RiderRunningBoard(
      running: const <RiderTrackedDelivery>[],
      clearLocalOrder: false,
      clearRemembered: clearRemembered,
      errorMessage: message,
    );
  }
  return RiderRunningBoard(
    running: unique,
    clearLocalOrder: clearLocal,
    clearRemembered: clearRemembered,
  );
}

String _address(String? stop, String? order) {
  final String fromStop = (stop ?? '').trim();
  if (fromStop.isNotEmpty) {
    return fromStop;
  }
  final String fromOrder = (order ?? '').trim();
  return fromOrder.isEmpty ? '—' : fromOrder;
}

String? _optionalAddress(String? primary, String? fallback) {
  final String first = (primary ?? '').trim();
  if (first.isNotEmpty) {
    return first;
  }
  final String second = (fallback ?? '').trim();
  return second.isEmpty ? null : second;
}

String? _stopAddress(ApiOrder? order, String type) {
  if (order == null) {
    return null;
  }
  ApiStop? match;
  for (final ApiStop stop in order.stops) {
    if (stop.stopType == type &&
        (match == null || stop.sequence < match.sequence)) {
      match = stop;
    }
  }
  return match?.addressText;
}

String? _blankToNull(String? value) {
  final String text = (value ?? '').trim();
  return text.isEmpty ? null : text;
}

String _presentName(String? value) {
  final String text = (value ?? '').trim();
  return text.isEmpty ? 'Customer' : text;
}
