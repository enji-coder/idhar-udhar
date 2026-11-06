import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/rider/features/wallet/wallet_topup_checkout.dart';
import 'package:idhar_udhar/shared/api/wallet_api.dart';

WalletTopUpPaymentStatus _status(String transactionStatus) {
  return WalletTopUpPaymentStatus(
    paymentTransactionId: 'tx',
    transactionStatus: transactionStatus,
  );
}

void main() {
  test('a verified PAID top-up is the only confirmed wallet message', () {
    final RiderWalletTopUpFeedback feedback = riderWalletTopUpFeedback(
      _status('PAID'),
    );
    expect(feedback.message, contains('Payment confirmed'));
    expect(feedback.message, isNot(contains('submitted')));
    expect(feedback.refreshImmediately, isTrue);
    expect(feedback.delayedRefreshes, 0);
    expect(feedback.success, isTrue);
  });

  test('a failed or dropped payment never says the wallet was credited', () {
    for (final String status in <String>[
      'FAILED',
      'REFUNDED',
      'USER_DROPPED',
      'EXPIRED',
      'CANCELLED',
      'TERMINATED',
    ]) {
      final RiderWalletTopUpFeedback feedback =
          riderWalletTopUpFeedback(_status(status));
      expect(feedback.message, contains('not credited'));
      expect(feedback.message, isNot(contains('confirmed')));
      expect(feedback.message, isNot(contains('submitted')));
      expect(feedback.delayedRefreshes, 0);
      expect(feedback.success, isFalse);
    }
  });

  test('a pending payment stays pending and does not claim confirmation', () {
    final RiderWalletTopUpFeedback feedback = riderWalletTopUpFeedback(
      _status('PENDING'),
    );
    expect(feedback.message, contains('submitted'));
    expect(feedback.message, isNot(contains('confirmed')));
    expect(feedback.refreshImmediately, isFalse);
    expect(feedback.delayedRefreshes, 5);
  });

  test('a missing verify result does not claim the payment was submitted', () {
    final RiderWalletTopUpFeedback feedback = riderWalletTopUpFeedback(null);
    expect(feedback.message, contains('could not be confirmed'));
    expect(feedback.message, isNot(contains('Payment confirmed')));
    expect(feedback.message, isNot(contains('submitted')));
    expect(feedback.refreshImmediately, isTrue);
    expect(feedback.delayedRefreshes, 2);
  });
}
