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
  if (!session.canOpenCheckout) {
    throw const ApiException(
      code: 'PAYMENT_PROVIDER_UNAVAILABLE',
      message: 'Waiting payment could not be started. Please try again.',
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
            message: error.getMessage() ?? 'Waiting payment was not completed.',
          ),
        );
      }
    },
  );
  gateway.doPayment(payment);
  return done.future;
}
