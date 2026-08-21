import 'company_office.dart';
import 'fare_engine.dart';

/// Failed delivery is NOT cancellation.
///
/// Office handover extra (rider taking parcel to office): ₹8/km, not 85/15.
/// Resend uses [ResendEngine] Case A (trip ended) or Case B (trip active).
abstract final class FailedDeliveryRates {
  static const double riderOfficePerKm = 8;
  static const double customerResendPerKm = 10;
  static const double caseBRiderPerKm = 8;
  static const double caseBCompanyPerKm = 2;
}

enum ResendCase { originalTripEnded, originalTripActive }

class ResendQuote {
  const ResendQuote({
    required this.resendCase,
    required this.distanceKm,
    required this.baseFare,
    required this.resendSurcharge,
    required this.customerPays,
    required this.riderAmount,
    required this.companyAmount,
  });

  final ResendCase resendCase;
  final double distanceKm;
  final double baseFare;
  final double resendSurcharge;
  final double customerPays;
  final double riderAmount;
  final double companyAmount;
}

/// Case A — original trip ended: rate-sheet base fare + ₹10/km, both 85/15.
/// Case B — original trip still active: customer ₹10/km; rider ₹8/km; company ₹2/km.
abstract final class ResendEngine {
  static ResendQuote quote({
    required bool originalTripEnded,
    required double distanceKm,
    double baseFare = 0,
    double riderPercent = 85,
  }) {
    final double km = distanceKm < 0 ? 0 : distanceKm;
    final double surcharge =
        FareEngine.round2(km * FailedDeliveryRates.customerResendPerKm);
    if (originalTripEnded) {
      final double base = FareEngine.round2(baseFare);
      final double riderFromBase =
          FareEngine.round2(base * riderPercent / 100);
      final double riderFromSurcharge =
          FareEngine.round2(surcharge * riderPercent / 100);
      return ResendQuote(
        resendCase: ResendCase.originalTripEnded,
        distanceKm: km,
        baseFare: base,
        resendSurcharge: surcharge,
        customerPays: FareEngine.round2(base + surcharge),
        riderAmount: FareEngine.round2(riderFromBase + riderFromSurcharge),
        companyAmount: FareEngine.round2(
          (base - riderFromBase) + (surcharge - riderFromSurcharge),
        ),
      );
    }
    final double riderAmount =
        FareEngine.round2(km * FailedDeliveryRates.caseBRiderPerKm);
    final double companyAmount =
        FareEngine.round2(km * FailedDeliveryRates.caseBCompanyPerKm);
    return ResendQuote(
      resendCase: ResendCase.originalTripActive,
      distanceKm: km,
      baseFare: 0,
      resendSurcharge: surcharge,
      customerPays: surcharge,
      riderAmount: riderAmount,
      companyAmount: companyAmount,
    );
  }
}

enum FailedDeliveryReason { receiverUnavailable }

enum ResendStatus {
  none,
  notDecided,
  resendRequested,
  resendInProgress,
  resendCompleted,
}

class FailedDeliveryRecord {
  const FailedDeliveryRecord({
    required this.reason,
    required this.originalDropLabel,
    required this.companyOffice,
    required this.officeDistanceKm,
    required this.riderOfficeCompensation,
    required this.recordedAt,
    this.resendStatus = ResendStatus.notDecided,
    this.resendCharge,
    this.resendDistanceKm,
    this.resendOrderId,
    this.customerNotified = false,
  });

  final FailedDeliveryReason reason;
  final String originalDropLabel;
  final CompanyOffice companyOffice;
  final double officeDistanceKm;
  final double riderOfficeCompensation;
  final DateTime recordedAt;
  final ResendStatus resendStatus;
  final double? resendCharge;
  final double? resendDistanceKm;
  final String? resendOrderId;
  final bool customerNotified;

  String get reasonLabel {
    switch (reason) {
      case FailedDeliveryReason.receiverUnavailable:
        return 'Receiver Unavailable';
    }
  }

  FailedDeliveryRecord copyWith({
    ResendStatus? resendStatus,
    double? resendCharge,
    double? resendDistanceKm,
    String? resendOrderId,
    bool? customerNotified,
  }) {
    return FailedDeliveryRecord(
      reason: reason,
      originalDropLabel: originalDropLabel,
      companyOffice: companyOffice,
      officeDistanceKm: officeDistanceKm,
      riderOfficeCompensation: riderOfficeCompensation,
      recordedAt: recordedAt,
      resendStatus: resendStatus ?? this.resendStatus,
      resendCharge: resendCharge ?? this.resendCharge,
      resendDistanceKm: resendDistanceKm ?? this.resendDistanceKm,
      resendOrderId: resendOrderId ?? this.resendOrderId,
      customerNotified: customerNotified ?? this.customerNotified,
    );
  }
}

abstract final class FailedDeliveryEngine {
  static const String customerNoticeTitle = 'Delivery not completed';

  static const String customerNoticeBody =
      'Your delivery could not be completed because the receiver was unavailable. '
      'Your parcel has been safely moved to the IDHAR UDHAR company office. '
      'You can request a resend to the original destination.';

  static double riderOfficeCompensation(double distanceKm) =>
      FareEngine.round2(distanceKm * FailedDeliveryRates.riderOfficePerKm);

  static double customerResendCharge(double distanceKm) =>
      FareEngine.round2(distanceKm * FailedDeliveryRates.customerResendPerKm);

  static FailedDeliveryRecord open({
    required String originalDropLabel,
    required double officeDistanceKm,
    CompanyOffice? office,
    DateTime? recordedAt,
  }) {
    return FailedDeliveryRecord(
      reason: FailedDeliveryReason.receiverUnavailable,
      originalDropLabel: originalDropLabel,
      companyOffice: office ?? CompanyOffice.current,
      officeDistanceKm: officeDistanceKm,
      riderOfficeCompensation: riderOfficeCompensation(officeDistanceKm),
      recordedAt: recordedAt ?? DateTime.now(),
      customerNotified: true,
    );
  }

  static FailedDeliveryRecord requestResend({
    required FailedDeliveryRecord current,
    required double resendDistanceKm,
    required String resendOrderId,
    bool originalTripEnded = true,
    double baseFare = 0,
  }) {
    final ResendQuote quote = ResendEngine.quote(
      originalTripEnded: originalTripEnded,
      distanceKm: resendDistanceKm,
      baseFare: baseFare,
    );
    return current.copyWith(
      resendStatus: ResendStatus.resendRequested,
      resendDistanceKm: resendDistanceKm,
      resendCharge: quote.customerPays,
      resendOrderId: resendOrderId,
    );
  }
}

/// Rider-facing money lines. Never includes profit or operational allocation.
class RiderPayoutView {
  const RiderPayoutView({
    required this.tripAmount,
    required this.riderAmount,
    required this.companyShare,
    this.failedDeliveryOfficeCompensation = 0,
  });

  final double tripAmount;
  final double riderAmount;
  final double companyShare;
  final double failedDeliveryOfficeCompensation;
}
