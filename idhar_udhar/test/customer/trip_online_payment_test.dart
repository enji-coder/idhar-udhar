import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/state/trip_online_payment.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';

void main() {
  test('online legs use the planned online amount and skip cash', () {
    final List<TripOnlineLeg> legs = tripOnlineLegs(
      customerOnline: 40,
      customerResponsibility: 100,
      receiverOnline: 0,
      receiverResponsibility: 0,
    );
    expect(legs, hasLength(1));
    expect(legs.single.payerType, 'CUSTOMER');
    expect(legs.single.amount, '40.00');
  });

  test('an online amount cannot exceed that payer responsibility', () {
    final List<TripOnlineLeg> legs = tripOnlineLegs(
      customerOnline: 150,
      customerResponsibility: 100,
      receiverOnline: 25,
      receiverResponsibility: 20,
    );
    expect(legs.map((TripOnlineLeg leg) => leg.amount), <String>['100.00', '20.00']);
    expect(legs.map((TripOnlineLeg leg) => leg.payerType), <String>['CUSTOMER', 'RECEIVER']);
  });

  test('a cash-only plan creates no online charge', () {
    expect(
      tripOnlineLegs(
        customerOnline: 0,
        customerResponsibility: 80,
        receiverOnline: 0,
        receiverResponsibility: 20,
      ),
      isEmpty,
    );
  });

  test('confirm retry uses the same idempotency key', () {
    const String first = 'trip-online:CUSTOMER:40.00';
    expect(
      tripOnlineIdempotencyKey(payerType: 'CUSTOMER', amount: '40.00'),
      first,
    );
    expect(
      tripOnlineIdempotencyKey(payerType: 'CUSTOMER', amount: '40.00'),
      first,
    );
    expect(
      tripOnlineIdempotencyKey(payerType: 'RECEIVER', amount: '40.00'),
      isNot(first),
    );
  });

  test('checkout stays closed when the session fields are missing', () {
    final OnlineTripTransaction missing = OnlineTripTransaction.fromJson(
      <String, Object>{
        'payment_transaction_id': 'pay-1',
        'amount': '40.00',
        'transaction_status': 'PENDING',
      },
    );
    expect(missing.canOpenCheckout, isFalse);

    final OnlineTripTransaction ready = OnlineTripTransaction.fromJson(
      <String, Object>{
        'payment_transaction_id': 'pay-1',
        'amount': '40.00',
        'transaction_status': 'PENDING',
        'payment_session_id': 'session_1',
        'cashfree_order_id': 'iu-order-1',
        'cashfree_environment': 'sandbox',
      },
    );
    expect(ready.canOpenCheckout, isTrue);
  });

  test('verify status is paid only when the server status is PAID', () {
    final OnlineTripPaymentStatus pending = OnlineTripPaymentStatus.fromJson(
      <String, Object>{
        'payment_transaction_id': 'pay-1',
        'transaction_status': 'PENDING',
        'authoritative': false,
        'gateway_status': 'SUCCESS',
      },
    );
    expect(pending.transactionStatus, 'PENDING');
    expect(pending.authoritative, isFalse);

    expect(
      tripOnlinePaymentNotice(
        const TripOnlinePaymentOutcome(
          serverPaid: false,
          sessionMissing: false,
          checkoutCancelled: true,
          checkoutEnded: false,
        ),
      )?.message,
      'Online payment was not completed.',
    );
    expect(
      tripOnlinePaymentNotice(
        const TripOnlinePaymentOutcome(
          serverPaid: false,
          sessionMissing: false,
          checkoutCancelled: false,
          checkoutEnded: true,
        ),
      )?.tone,
      TripOnlinePaymentTone.info,
    );
    expect(
      tripOnlinePaymentNotice(
        const TripOnlinePaymentOutcome(
          serverPaid: true,
          sessionMissing: false,
          checkoutCancelled: false,
          checkoutEnded: true,
        ),
      )?.tone,
      TripOnlinePaymentTone.success,
    );
  });
}
