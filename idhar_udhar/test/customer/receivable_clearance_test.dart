import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';

void main() {
  test('a clearance session can open checkout only with a Cashfree session', () {
    final ReceivableClearance ready = ReceivableClearance.fromJson(<String, Object>{
      'payment_transaction_id': 'pay-1',
      'amount': '5.00',
      'payment_session_id': 'session_1',
      'cashfree_order_id': 'order_1',
      'cashfree_environment': 'sandbox',
    });
    expect(ready.canOpenCheckout, isTrue);
    expect(ready.amount, '5.00');

    final ReceivableClearance missing = ReceivableClearance.fromJson(<String, Object>{
      'amount': '5.00',
    });
    expect(missing.canOpenCheckout, isFalse);
  });
}
