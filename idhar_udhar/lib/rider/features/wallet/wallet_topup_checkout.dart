import 'dart:async';

import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/wallet_api.dart';

/// Opens Cashfree checkout for a server-created rider wallet top-up.
///
/// The SDK callback only means the rider left checkout. The wallet is credited
/// only after server-side settlement (rider verify and/or Cashfree webhook).
Future<void> openRiderWalletTopUpCheckout(WalletTopUpSession session) {
  if (!session.canOpenCheckout) {
    throw const ApiException(
      code: 'PAYMENT_PROVIDER_UNAVAILABLE',
      message: 'Wallet payment could not be started yet.',
    );
  }
  final CFEnvironment environment = session.environment == 'production'
      ? CFEnvironment.PRODUCTION
      : CFEnvironment.SANDBOX;
  final CFSession cfSession = CFSessionBuilder()
      .setEnvironment(environment)
      .setOrderId(session.cashfreeOrderId)
      .setPaymentSessionId(session.paymentSessionId)
      .build();
  final CFWebCheckoutPayment payment =
      CFWebCheckoutPaymentBuilder().setSession(cfSession).build();
  final Completer<void> done = Completer<void>();
  final CFPaymentGatewayService gateway = CFPaymentGatewayService();
  gateway.setCallback(
    (String _) {
      if (!done.isCompleted) {
        done.complete();
      }
    },
    (CFErrorResponse error, String _) {
      if (!done.isCompleted) {
        done.completeError(
          ApiException(
            code: 'PAYMENT_GATEWAY_REJECTED',
            message: error.getMessage() ?? 'Wallet payment was not completed.',
          ),
        );
      }
    },
  );
  gateway.doPayment(payment);
  return done.future;
}

/// Asks the backend to retrieve Cashfree and settle. SDK success is ignored.
Future<WalletTopUpPaymentStatus?> verifyRiderWalletTopUpAfterCheckout({
  required WalletApi walletApi,
  required String paymentTransactionId,
}) async {
  try {
    return await walletApi.verifyTopUp(paymentTransactionId);
  } on ApiException {
    return null;
  }
}

/// Server status after checkout. The SDK callback is not a wallet credit.
class RiderWalletTopUpFeedback {
  const RiderWalletTopUpFeedback({
    required this.message,
    required this.refreshImmediately,
    required this.delayedRefreshes,
    this.success = false,
  });

  final String message;
  final bool refreshImmediately;
  final int delayedRefreshes;
  final bool success;
}

const Set<String> _failedTopUpStatuses = <String>{
  'FAILED',
  'REFUNDED',
  'USER_DROPPED',
  'EXPIRED',
  'CANCELLED',
  'TERMINATED',
};

RiderWalletTopUpFeedback riderWalletTopUpFeedback(
  WalletTopUpPaymentStatus? status,
) {
  final String raw = status?.transactionStatus.trim().toUpperCase() ?? '';
  if (raw == 'PAID') {
    return const RiderWalletTopUpFeedback(
      message: 'Payment confirmed. Your wallet balance has been updated.',
      refreshImmediately: true,
      delayedRefreshes: 0,
      success: true,
    );
  }
  if (_failedTopUpStatuses.contains(raw)) {
    return const RiderWalletTopUpFeedback(
      message: 'Payment was not completed. Your wallet was not credited.',
      refreshImmediately: true,
      delayedRefreshes: 0,
    );
  }
  if (status == null) {
    return const RiderWalletTopUpFeedback(
      message:
          'Payment status could not be confirmed. Your wallet updates only after the server verifies it.',
      refreshImmediately: true,
      delayedRefreshes: 2,
    );
  }
  return const RiderWalletTopUpFeedback(
    message: 'Payment submitted. Balance updates after confirmation.',
    refreshImmediately: false,
    delayedRefreshes: 5,
  );
}

/// Later wallet reads after checkout has already been verified.
///
/// The previous screens awaited this loop before closing the amount sheet.
/// Pending status waited 10 seconds (5 × 2s). A verify failure waited 4 seconds.
/// Those waits are not payment checks. The server verify still runs first.
Future<void> refreshWalletAfterTopUp({
  required int times,
  required Future<void> Function() refresh,
}) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(const Duration(seconds: 2));
    await refresh();
  }
}

/// Checkout return is not settlement. A gateway error still asks the server.
Future<RiderWalletTopUpFeedback> finishRiderWalletTopUpCheckout({
  required WalletApi walletApi,
  required WalletTopUpSession session,
}) async {
  try {
    await openRiderWalletTopUpCheckout(session);
  } on ApiException {
    // The SDK error is not a payment result.
  }
  final WalletTopUpPaymentStatus? status =
      await verifyRiderWalletTopUpAfterCheckout(
    walletApi: walletApi,
    paymentTransactionId: session.paymentTransactionId,
  );
  return riderWalletTopUpFeedback(status);
}
