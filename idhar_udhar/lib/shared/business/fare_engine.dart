import 'fare_config.dart';

/// Quote produced at booking confirmation. Copied onto the order as a snapshot.
/// GST is not applied (NO GST).
class FareQuote {
  const FareQuote({
    required this.configVersionId,
    required this.vehicleCategoryId,
    required this.distanceKm,
    required this.baseFare,
    required this.perKmCharge,
    required this.distanceCharge,
    required this.initialMinimum,
    required this.waitingCharge,
    required this.surgeCharge,
    required this.tollCharge,
    required this.parkingCharge,
    required this.tripFare,
    required this.discount,
    required this.subtotal,
    required this.rounding,
    required this.netTotal,
    required this.quotedAt,
    this.stopCount = 1,
  });

  final String configVersionId;
  final String vehicleCategoryId;
  final double distanceKm;
  final double baseFare;
  final double perKmCharge;
  final double distanceCharge;
  final double initialMinimum;
  final double waitingCharge;
  final double surgeCharge;
  final double tollCharge;
  final double parkingCharge;
  final double tripFare;
  final double discount;
  final double subtotal;
  final double rounding;
  final double netTotal;
  final DateTime quotedAt;
  final int stopCount;

  /// Always zero. Dummy 5% tax must not return.
  double get tax => 0;

  Map<String, double> get visibleLines {
    return <String, double>{
      'Base Fare': baseFare,
      if (distanceCharge > 0) 'Distance': distanceCharge,
      if (waitingCharge > 0) 'Waiting': waitingCharge,
      if (surgeCharge > 0) 'Surge': surgeCharge,
      if (tollCharge > 0) 'Toll': tollCharge,
      if (parkingCharge > 0) 'Parking': parkingCharge,
      if (discount > 0) 'Discount': -discount,
    };
  }
}

abstract final class FareEngine {
  static double round2(double value) =>
      (value * 100).roundToDouble() / 100;

  /// Multi-stop: [distanceKm] is the sum of ordered legs.
  /// No extra multi-stop fee is invented.
  static FareQuote quote({
    required FareConfig config,
    required double distanceKm,
    int stopCount = 1,
    double discount = 0,
    DateTime? quotedAt,
  }) {
    final double distanceCharge = round2(config.perKmCharge * distanceKm);
    final double raw = config.baseFare +
        distanceCharge +
        config.waitingCharge +
        config.surgeCharge +
        config.tollCharge +
        config.parkingCharge;
    final double tripFare =
        raw < config.initialMinimum ? config.initialMinimum : round2(raw);
    final double afterDiscount = (tripFare - discount).clamp(0, double.infinity);
    final double net = round2(afterDiscount);
    final double rounding = round2(net - afterDiscount);
    return FareQuote(
      configVersionId: config.versionId,
      vehicleCategoryId: config.vehicleCategoryId,
      distanceKm: distanceKm,
      baseFare: config.baseFare,
      perKmCharge: config.perKmCharge,
      distanceCharge: distanceCharge,
      initialMinimum: config.initialMinimum,
      waitingCharge: config.waitingCharge,
      surgeCharge: config.surgeCharge,
      tollCharge: config.tollCharge,
      parkingCharge: config.parkingCharge,
      tripFare: tripFare,
      discount: discount,
      subtotal: round2(afterDiscount),
      rounding: rounding,
      netTotal: net,
      quotedAt: quotedAt ?? DateTime.now(),
      stopCount: stopCount,
    );
  }
}
