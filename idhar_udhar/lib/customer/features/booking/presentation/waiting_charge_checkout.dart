import 'dart:async';

import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:idhar_udhar/shared/api/api_exception.dart';
import 'package:idhar_udhar/shared/api/orders_api.dart';

/// Opens the existing Cashfree checkout for a server-created receivable session.
///
/// The SDK callback only means the customer left checkout. The receivable stays
/// outstanding until the Cashfree webhook credits it.
Future<void> openReceivableCheckout(ReceivableClearance session) {
  return openCashfreeWebCheckout(
    paymentSessionId: session.paymentSessionId,
    cashfreeOrderId: session.cashfreeOrderId,
    environment: session.environment,
    canOpen: session.canOpenCheckout,
    unavailableMessage: 'Waiting payment could not be started. Please try again.',
    rejectedFallback: 'Waiting payment was not completed.',
  );
}

/// Same Cashfree web checkout used for waiting charges.
///
/// Returning from the SDK does not mean the trip fare is paid. The webhook
/// remains the only writer of PAID.
Future<void> openTripFareCheckout({
  required String paymentSessionId,
  required String cashfreeOrderId,
  required String environment,
}) {
  final bool canOpen = paymentSessionId.isNotEmpty &&
      cashfreeOrderId.isNotEmpty &&
      (environment == 'sandbox' || environment == 'production');
  return openCashfreeWebCheckout(
    paymentSessionId: paymentSessionId,
    cashfreeOrderId: cashfreeOrderId,
    environment: environment,
    canOpen: canOpen,
    unavailableMessage: 'Online trip payment could not be started. Please try again.',
    rejectedFallback: 'Online trip payment was not completed.',
  );
}

Future<void> openCashfreeWebCheckout({
  required String paymentSessionId,
  required String cashfreeOrderId,
  required String environment,
  required bool canOpen,
  required String unavailableMessage,
  required String rejectedFallback,
}) {
  if (!canOpen) {
    throw ApiException(
      code: 'PAYMENT_PROVIDER_UNAVAILABLE',
      message: unavailableMessage,
    );
  }
  final CFEnvironment cfEnvironment = environment == 'production'
      ? CFEnvironment.PRODUCTION
      : CFEnvironment.SANDBOX;
  final CFSession cfSession = CFSessionBuilder()
      .setEnvironment(cfEnvironment)
      .setOrderId(cashfreeOrderId)
      .setPaymentSessionId(paymentSessionId)
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
            message: error.getMessage() ?? rejectedFallback,
          ),
        );
      }
    },
  );
  gateway.doPayment(payment);
  return done.future;
}
