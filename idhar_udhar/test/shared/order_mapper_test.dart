import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/rider/data/models/rider_order.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/order_mapper.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';
import 'package:idhar_udhar/shared/api/rider_api.dart';

void main() {
  test('maps backend statuses onto existing customer UI statuses', () {
    expect(OrderMapper.toUiStatus('SEARCHING'), OrderStatus.searching);
    expect(OrderMapper.toUiStatus('ASSIGNED'), OrderStatus.assigned);
    expect(OrderMapper.toUiStatus('DELIVERED'), OrderStatus.delivered);
    expect(OrderMapper.toUiStatus('PARCEL_AT_COMPANY_OFFICE'),
        OrderStatus.atCompanyOffice,);
  });

  test('chains rider UI delivered tap onto legal backend hops', () {
    expect(
      OrderMapper.riderStatusHops(
        from: DeliveryLifecycleStatus.goingToDrop,
        to: DeliveryLifecycleStatus.delivered,
      ),
      <String>['NEAR_DROP', 'DELIVERY_ATTEMPT', 'DELIVERED'],
    );
  });

  test('IN_TRANSIT still needs the three delivered hops', () {
    expect(
      OrderMapper.remainingRiderHops(
        serverStatus: 'IN_TRANSIT',
        target: DeliveryLifecycleStatus.delivered,
      ),
      <String>['NEAR_DROP', 'DELIVERY_ATTEMPT', 'DELIVERED'],
    );
  });

  test('NEAR_DROP does not replay itself on the way to delivered', () {
    expect(
      OrderMapper.remainingRiderHops(
        serverStatus: 'NEAR_DROP',
        target: DeliveryLifecycleStatus.delivered,
      ),
      <String>['DELIVERY_ATTEMPT', 'DELIVERED'],
    );
  });

  test('DELIVERY_ATTEMPT only sends DELIVERED', () {
    expect(
      OrderMapper.remainingRiderHops(
        serverStatus: 'DELIVERY_ATTEMPT',
        target: DeliveryLifecycleStatus.delivered,
      ),
      <String>['DELIVERED'],
    );
  });

  test('DELIVERED sends no further hops', () {
    expect(
      OrderMapper.remainingRiderHops(
        serverStatus: 'DELIVERED',
        target: DeliveryLifecycleStatus.delivered,
      ),
      isEmpty,
    );
  });

  test('PICKED_UP includes IN_TRANSIT before the drop hops', () {
    expect(
      OrderMapper.remainingRiderHops(
        serverStatus: 'PICKED_UP',
        target: DeliveryLifecycleStatus.delivered,
      ),
      <String>['IN_TRANSIT', 'NEAR_DROP', 'DELIVERY_ATTEMPT', 'DELIVERED'],
    );
  });

  test('an unsupported server status is not turned into a guessed hop', () {
    expect(
      OrderMapper.remainingRiderHops(
        serverStatus: 'CANCELLED',
        target: DeliveryLifecycleStatus.delivered,
      ),
      isNull,
    );
    expect(
      OrderMapper.remainingRiderHops(
        serverStatus: 'NOT_A_STATUS',
        target: DeliveryLifecycleStatus.receiverUnavailable,
      ),
      isNull,
    );
    expect(OrderMapper.tryRiderLifecycle('CANCELLED'), isNull);
  });

  test('receiver unavailable continues from each earlier legal status', () {
    expect(
      OrderMapper.remainingRiderHops(
        serverStatus: 'PICKED_UP',
        target: DeliveryLifecycleStatus.receiverUnavailable,
      ),
      <String>[
        'IN_TRANSIT',
        'NEAR_DROP',
        'DELIVERY_ATTEMPT',
        'RECEIVER_UNAVAILABLE',
      ],
    );
    expect(
      OrderMapper.remainingRiderHops(
        serverStatus: 'IN_TRANSIT',
        target: DeliveryLifecycleStatus.receiverUnavailable,
      ),
      <String>['NEAR_DROP', 'DELIVERY_ATTEMPT', 'RECEIVER_UNAVAILABLE'],
    );
    expect(
      OrderMapper.remainingRiderHops(
        serverStatus: 'NEAR_DROP',
        target: DeliveryLifecycleStatus.receiverUnavailable,
      ),
      <String>['DELIVERY_ATTEMPT', 'RECEIVER_UNAVAILABLE'],
    );
    expect(
      OrderMapper.remainingRiderHops(
        serverStatus: 'DELIVERY_ATTEMPT',
        target: DeliveryLifecycleStatus.receiverUnavailable,
      ),
      <String>['RECEIVER_UNAVAILABLE'],
    );
    expect(
      OrderMapper.remainingRiderHops(
        serverStatus: 'RECEIVER_UNAVAILABLE',
        target: DeliveryLifecycleStatus.receiverUnavailable,
      ),
      isEmpty,
    );
  });

  test('a failed hop stops the sequence and does not invent the target', () async {
    final List<String> sent = <String>[];
    final RiderStatusAdvance advance = RiderStatusAdvance();
    final RiderStatusAdvanceOutcome? outcome = await advance.run(
      target: DeliveryLifecycleStatus.delivered,
      fetchStatus: () async => 'IN_TRANSIT',
      applyHop: (String hop) async {
        sent.add(hop);
        if (hop == 'DELIVERY_ATTEMPT') {
          throw const ApiException(
            code: 'INVALID_TRANSITION',
            message: 'That order update is not allowed yet.',
          );
        }
        return hop;
      },
    );
    expect(sent, <String>['NEAR_DROP', 'DELIVERY_ATTEMPT']);
    expect(sent, isNot(contains('DELIVERED')));
    expect(outcome, isNotNull);
    expect(outcome!.completed, isFalse);
    expect(outcome.hopsSent, <String>['NEAR_DROP']);
    expect(outcome.canonicalStatus, 'IN_TRANSIT');
    expect(outcome.canonicalStatus, isNot('DELIVERED'));
    expect(OrderMapper.tryRiderLifecycle(outcome.canonicalStatus!), isNot(
      DeliveryLifecycleStatus.delivered,
    ));
  });

  test('a failed refresh keeps the last known server status', () async {
    var fetches = 0;
    final RiderStatusAdvanceOutcome? outcome = await RiderStatusAdvance().run(
      target: DeliveryLifecycleStatus.delivered,
      fetchStatus: () async {
        fetches += 1;
        if (fetches == 1) {
          return 'NEAR_DROP';
        }
        throw const ApiException(
          code: 'DATABASE_UNAVAILABLE',
          message: 'Service is temporarily unavailable.',
        );
      },
      applyHop: (String hop) async {
        throw const ApiException(
          code: 'INVALID_TRANSITION',
          message: 'That order update is not allowed yet.',
        );
      },
    );
    expect(outcome!.completed, isFalse);
    expect(outcome.hopsSent, isEmpty);
    expect(outcome.canonicalStatus, 'NEAR_DROP');
    expect(
      OrderMapper.tryRiderLifecycle(outcome.canonicalStatus!),
      isNot(DeliveryLifecycleStatus.delivered),
    );
    expect(outcome.failure, isA<ApiException>());
  });

  test('a failed initial fetch does not invent a server status', () async {
    final RiderStatusAdvanceOutcome? outcome = await RiderStatusAdvance().run(
      target: DeliveryLifecycleStatus.delivered,
      fetchStatus: () async {
        throw const ApiException(
          code: 'DATABASE_UNAVAILABLE',
          message: 'Service is temporarily unavailable.',
        );
      },
      applyHop: (String hop) async => hop,
    );
    expect(outcome!.completed, isFalse);
    expect(outcome.canonicalStatus, isNull);
    expect(outcome.hopsSent, isEmpty);
    expect(outcome.failure, isA<ApiException>());
  });

  test('overlapping taps do not start a second sequence', () async {
    final Completer<void> gate = Completer<void>();
    final List<String> sent = <String>[];
    final RiderStatusAdvance advance = RiderStatusAdvance();
    final Future<RiderStatusAdvanceOutcome?> first = advance.run(
      target: DeliveryLifecycleStatus.delivered,
      fetchStatus: () async => 'DELIVERY_ATTEMPT',
      applyHop: (String hop) async {
        sent.add(hop);
        await gate.future;
        return 'DELIVERED';
      },
    );
    final RiderStatusAdvanceOutcome? second = await advance.run(
      target: DeliveryLifecycleStatus.delivered,
      fetchStatus: () async => 'DELIVERY_ATTEMPT',
      applyHop: (String hop) async {
        sent.add('duplicate-$hop');
        return 'DELIVERED';
      },
    );
    expect(second, isNull);
    gate.complete();
    final RiderStatusAdvanceOutcome? finished = await first;
    expect(finished!.completed, isTrue);
    expect(sent, <String>['DELIVERED']);
  });

  test('maps API order display id for existing list tiles', () {
    final MockOrder order = OrderMapper.toMockOrder(
      ApiOrder(
        orderId: '11111111-1111-1111-1111-111111111111',
        displayId: 'IU-AMD-0001',
        canonicalStatus: 'SEARCHING',
        createdAt: DateTime.utc(2026, 1, 1),
        tripFare: 79,
      ),
    );
    expect(order.displayLabel, 'IU-AMD-0001');
    expect(order.apiId, '11111111-1111-1111-1111-111111111111');
    expect(order.fare, 79);
  });

  test('maps assigned rider display fields without inventing rating', () {
    final MockOrder order = OrderMapper.toMockOrder(
      ApiOrder(
        orderId: '11111111-1111-1111-1111-111111111111',
        displayId: 'IU-AMD-0002',
        canonicalStatus: 'ASSIGNED',
        createdAt: DateTime.utc(2026, 1, 1),
        riderProfileId: '22222222-2222-4222-8222-222222222222',
        vehicleCategoryName: 'Bike',
        assignedRider: const ApiAssignedRider(
          name: 'Ravi',
          vehicleRegistration: 'GJ-01-AB-1234',
          vehicleCategoryName: 'Bike',
        ),
        tripFare: 120,
      ),
    );
    expect(order.status, OrderStatus.assigned);
    expect(order.rider, isNotNull);
    expect(order.rider!.name, 'Ravi');
    expect(order.rider!.vehicleLabel, contains('Bike'));
    expect(order.rider!.vehicleLabel, contains('GJ-01-AB-1234'));
    expect(order.rider!.rating, 0);
    expect(order.vehicle.name, 'Bike');
    expect(order.vehicle.imagePath, isNotEmpty);
  });

  test('cancelled history amount is zero and CRN is copied, not recomputed', () {
    final MockOrder order = OrderMapper.toMockOrder(
      ApiOrder(
        orderId: '11111111-1111-1111-1111-111111111111',
        displayId: 'IU-AMD-0000000003',
        crn: 'IU-CRN-AMD-0000000003',
        canonicalStatus: 'CANCELLED',
        createdAt: DateTime.utc(2026, 1, 1),
        tripFare: 250,
        netPayable: 250,
        vehicleCategoryName: 'Truck',
      ),
    );
    expect(order.fare, 0);
    expect(order.tripFare, 250);
    expect(order.crn, 'IU-CRN-AMD-0000000003');
    expect(order.vehicle.imagePath, contains('truck'));
  });

  test('rider offer shows full trip fare, earnings, stops, and server expiry', () {
    final DateTime expiresAt = DateTime.now().add(const Duration(seconds: 300));
    final RiderOrder order = OrderMapper.toRiderOrder(
      offer: RiderOffer(
        offerId: '66666666-6666-4666-8666-666666666666',
        orderId: '55555555-5555-4555-8555-555555555555',
        status: 'PENDING',
        createdAt: DateTime.utc(2026, 10, 8, 6),
        tripFare: 500,
        riderAmount: 425,
        distanceKm: 1.3,
        estimatedDurationSeconds: 156,
        expiresAt: expiresAt,
        pickupAddress: '12 CG Road, Ahmedabad',
        dropAddress: 'Navrangpura, Ahmedabad',
        pickupLatitude: 23.03,
        pickupLongitude: 72.57,
        dropLatitude: 23.036,
        dropLongitude: 72.561,
        vehicleCategoryName: 'Bike',
        packageWeightKg: 2,
      ),
    );

    expect(order.tripAmount, 500);
    expect(order.estimatedEarnings, 425);
    expect(order.riderAmount, 425);
    expect(order.pickup, '12 CG Road, Ahmedabad');
    expect(order.drop, 'Navrangpura, Ahmedabad');
    expect(order.pickup, isNot('Pickup'));
    expect(order.drop, isNot('Drop'));
    expect(order.distanceLabel, '1.3 km');
    expect(order.estimatedMinutes, 3);
    expect(order.etaLabel, '3 min');
    expect(order.decisionSeconds, inInclusiveRange(290, 300));
    expect(order.expiresAt, expiresAt);
    expect(order.vehicleName, 'Bike');
    expect(order.packageLabel, '2 kg');
    expect(order.pickupLatitude, 23.03);
    expect(order.dropLongitude, 72.561);
  });

  test('offer duration is not invented when the server omits it', () {
    final RiderOrder order = OrderMapper.toRiderOrder(
      offer: RiderOffer(
        offerId: '66666666-6666-4666-8666-666666666666',
        orderId: '55555555-5555-4555-8555-555555555555',
        status: 'PENDING',
        createdAt: DateTime.utc(2026, 10, 8, 6),
        tripFare: 500,
        distanceKm: 12.4,
        expiresAt: DateTime.utc(2026, 10, 8, 6, 0, 30),
      ),
    );
    expect(order.estimatedMinutes, 0);
    expect(order.etaLabel, '—');
    expect(order.distanceLabel, '12.4 km');
    expect(order.tripAmount, 500);
  });

  test('trip duration formats hours from the server seconds', () {
    final RiderOrder order = OrderMapper.toRiderOrder(
      offer: RiderOffer(
        offerId: '66666666-6666-4666-8666-666666666666',
        orderId: '55555555-5555-4555-8555-555555555555',
        status: 'PENDING',
        createdAt: DateTime.utc(2026, 10, 8, 6),
        estimatedDurationSeconds: 70 * 60,
        expiresAt: DateTime.utc(2026, 10, 8, 6, 0, 30),
      ),
    );
    expect(order.etaLabel, '1 hr 10 min');
  });

  test('payment view maps cash and online allocations onto the matching order', () {
    const String orderId = '11111111-1111-4111-8111-111111111111';
    final RiderOrder base = OrderMapper.toRiderOrder(
      offer: RiderOffer(
        offerId: '22222222-2222-4222-8222-222222222222',
        orderId: orderId,
        status: 'ACCEPTED',
        createdAt: DateTime.utc(2026, 10, 11),
        displayId: 'IU-1',
        tripFare: 100,
      ),
    );
    final ApiOrderPaymentView? cash = ApiOrderPaymentView.tryParse(<String, Object?>{
      'order_id': orderId,
      'responsibility': <String, Object?>{
        'order_id': orderId,
        'applicable_bill_total': '100.00',
        'customer_responsibility': '60.50',
        'receiver_responsibility': '39.50',
      },
      'plan': <String, Object?>{
        'order_id': orderId,
        'customer_planned_online': '0.00',
        'customer_planned_cash': '60.50',
        'receiver_planned_online': '10.00',
        'receiver_planned_cash': '29.50',
      },
    });
    final RiderOrder? applied = OrderMapper.applyPaymentView(
      order: base,
      payment: cash!,
    );

    expect(applied!.customerResponsibility, 60.5);
    expect(applied.receiverResponsibility, 39.5);
    expect(applied.customerOnline, 0);
    expect(applied.customerCash, 60.5);
    expect(applied.receiverOnline, 10);
    expect(applied.receiverCash, 29.5);
    expect(base.customerCash, 0);

    final ApiOrderPaymentView? online = ApiOrderPaymentView.tryParse(<String, Object?>{
      'order_id': orderId,
      'responsibility': <String, Object?>{
        'order_id': orderId,
        'applicable_bill_total': '100.00',
        'customer_responsibility': '100.00',
        'receiver_responsibility': '0.00',
      },
      'plan': <String, Object?>{
        'order_id': orderId,
        'customer_planned_online': '100.00',
        'customer_planned_cash': '0.00',
        'receiver_planned_online': '0.00',
        'receiver_planned_cash': '0.00',
      },
    });
    final RiderOrder? onlineOrder = OrderMapper.applyPaymentView(
      order: base,
      payment: online!,
    );
    expect(onlineOrder!.customerOnline, 100);
    expect(onlineOrder.customerCash, 0);
    expect(onlineOrder.receiverCash, 0);
  });

  test('missing or mismatched payment data is not applied as zero cash', () {
    const String orderId = '11111111-1111-4111-8111-111111111111';
    final RiderOrder base = OrderMapper.toRiderOrder(
      offer: RiderOffer(
        offerId: '22222222-2222-4222-8222-222222222222',
        orderId: orderId,
        status: 'ACCEPTED',
        createdAt: DateTime.utc(2026, 10, 11),
        tripFare: 100,
      ),
    );
    final ApiOrderPaymentView? missing = ApiOrderPaymentView.tryParse(<String, Object?>{
      'order_id': orderId,
      'responsibility': null,
      'plan': null,
    });
    expect(missing, isNotNull);
    expect(missing!.hasAllocation, isFalse);
    expect(
      OrderMapper.applyPaymentView(order: base, payment: missing),
      isNull,
    );

    expect(
      ApiOrderPaymentView.tryParse(<String, Object?>{
        'order_id': orderId,
        'responsibility': <String, Object?>{
          'order_id': orderId,
          'applicable_bill_total': '100.00',
          'customer_responsibility': 'not-money',
          'receiver_responsibility': '0.00',
        },
        'plan': <String, Object?>{
          'order_id': orderId,
          'customer_planned_online': '100.00',
          'customer_planned_cash': '0.00',
          'receiver_planned_online': '0.00',
          'receiver_planned_cash': '0.00',
        },
      }),
      isNull,
    );

    final ApiOrderPaymentView? otherOrder = ApiOrderPaymentView.tryParse(<String, Object?>{
      'order_id': '99999999-9999-4999-8999-999999999999',
      'responsibility': <String, Object?>{
        'order_id': '99999999-9999-4999-8999-999999999999',
        'applicable_bill_total': '100.00',
        'customer_responsibility': '0.00',
        'receiver_responsibility': '100.00',
      },
      'plan': <String, Object?>{
        'order_id': '99999999-9999-4999-8999-999999999999',
        'customer_planned_online': '0.00',
        'customer_planned_cash': '0.00',
        'receiver_planned_online': '0.00',
        'receiver_planned_cash': '100.00',
      },
    });
    expect(
      OrderMapper.applyPaymentView(order: base, payment: otherOrder!),
      isNull,
    );
    expect(base.receiverCash, 0);
  });
}
