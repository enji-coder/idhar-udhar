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
/// only after the Cashfree webhook is verified by the backend.
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
