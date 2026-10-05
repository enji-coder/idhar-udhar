import 'package:idhar_udhar/shared/business/fare_engine.dart';

/// One ONLINE portion of a saved trip payment plan.
class TripOnlineLeg {
  const TripOnlineLeg({required this.payerType, required this.amount});

  final String payerType;
  final String amount;
}

enum TripOnlinePaymentTone { success, error, info }

class TripOnlinePaymentNotice {
  const TripOnlinePaymentNotice({required this.message, required this.tone});

  final String message;
  final TripOnlinePaymentTone tone;
}

class TripOnlinePaymentOutcome {
  const TripOnlinePaymentOutcome({
    required this.serverPaid,
    required this.sessionMissing,
    required this.checkoutCancelled,
    required this.checkoutEnded,
  });

  /// True only when every opened charge's stored status is PAID.
  final bool serverPaid;
  final bool sessionMissing;
  final bool checkoutCancelled;
  final bool checkoutEnded;
}

/// Stable across confirm retries so the backend replays one Cashfree session.
String tripOnlineIdempotencyKey({
  required String payerType,
  required String amount,
}) {
  return 'trip-online:$payerType:$amount';
}

/// Online amounts only, capped at each payer's responsibility.
/// Cash portions are omitted. A zero result means no checkout.
List<TripOnlineLeg> tripOnlineLegs({
  required double customerOnline,
  required double customerResponsibility,
  required double receiverOnline,
  required double receiverResponsibility,
}) {
  final List<TripOnlineLeg> legs = <TripOnlineLeg>[];
  final String? customer = _cappedAmount(customerOnline, customerResponsibility);
  if (customer != null) {
    legs.add(TripOnlineLeg(payerType: 'CUSTOMER', amount: customer));
  }
  final String? receiver = _cappedAmount(receiverOnline, receiverResponsibility);
  if (receiver != null) {
    legs.add(TripOnlineLeg(payerType: 'RECEIVER', amount: receiver));
  }
  return legs;
}

TripOnlinePaymentNotice? tripOnlinePaymentNotice(TripOnlinePaymentOutcome? outcome) {
  if (outcome == null) {
    return null;
  }
  if (outcome.serverPaid) {
    return const TripOnlinePaymentNotice(
      message: 'Payment confirmed.',
      tone: TripOnlinePaymentTone.success,
    );
  }
  if (outcome.sessionMissing &&
      !outcome.checkoutEnded &&
      !outcome.checkoutCancelled) {
    return const TripOnlinePaymentNotice(
      message: 'Online payment could not be started.',
      tone: TripOnlinePaymentTone.error,
    );
  }
  if (outcome.checkoutCancelled) {
    return const TripOnlinePaymentNotice(
      message: 'Online payment was not completed.',
      tone: TripOnlinePaymentTone.error,
    );
  }
  return const TripOnlinePaymentNotice(
    message: 'Payment submitted. It is confirmed when the payment is verified.',
    tone: TripOnlinePaymentTone.info,
  );
}

String? _cappedAmount(double planned, double responsibility) {
  if (planned <= 0 || responsibility <= 0) {
    return null;
  }
  final double capped =
      planned > responsibility ? responsibility : planned;
  final double rounded = FareEngine.round2(capped);
  if (rounded <= 0) {
    return null;
  }
  return rounded.toStringAsFixed(2);
}
