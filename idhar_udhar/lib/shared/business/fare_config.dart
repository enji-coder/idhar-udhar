/// Admin-controlled vehicle fare table. Not hardcoded in widgets.
///
/// Per-km for the *original trip* is a fare-config field.
/// Failed-delivery ₹8/km and resend ₹10/km are separate operational rates
/// (see failed_delivery.dart) and must not be mixed into this table.
class FareConfig {
  const FareConfig({
    required this.versionId,
    required this.vehicleCategoryId,
    required this.vehicleCategoryName,
    required this.baseFare,
    required this.perKmCharge,
    required this.initialMinimum,
    this.waitingCharge = 0,
    this.surgeCharge = 0,
    this.tollCharge = 0,
    this.parkingCharge = 0,
    this.weightCapacityKg,
    this.size,
    required this.effectiveFrom,
  });

  final String versionId;
  final String vehicleCategoryId;
  final String vehicleCategoryName;
  final double baseFare;
  final double perKmCharge;
  final double initialMinimum;
  final double waitingCharge;
  final double surgeCharge;
  final double tollCharge;
  final double parkingCharge;
  final double? weightCapacityKg;
  final String? size;
  final DateTime effectiveFrom;

  FareConfig copyWith({
    String? versionId,
    double? baseFare,
    double? perKmCharge,
    double? initialMinimum,
    double? waitingCharge,
    double? surgeCharge,
    double? tollCharge,
    double? parkingCharge,
    DateTime? effectiveFrom,
  }) {
    return FareConfig(
      versionId: versionId ?? this.versionId,
      vehicleCategoryId: vehicleCategoryId,
      vehicleCategoryName: vehicleCategoryName,
      baseFare: baseFare ?? this.baseFare,
      perKmCharge: perKmCharge ?? this.perKmCharge,
      initialMinimum: initialMinimum ?? this.initialMinimum,
      waitingCharge: waitingCharge ?? this.waitingCharge,
      surgeCharge: surgeCharge ?? this.surgeCharge,
      tollCharge: tollCharge ?? this.tollCharge,
      parkingCharge: parkingCharge ?? this.parkingCharge,
      weightCapacityKg: weightCapacityKg,
      size: size,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
    );
  }
}

/// Demo catalog. Production reads the latest Admin version via API.
class FareCatalog {
  FareCatalog._();

  static final Map<String, FareConfig> _current = <String, FareConfig>{
    'bike': FareConfig(
      versionId: 'fare_bike_v1',
      vehicleCategoryId: 'VC-1001',
      vehicleCategoryName: 'Bike',
      baseFare: 79,
      perKmCharge: 0,
      initialMinimum: 79,
      weightCapacityKg: 20,
      size: '36cm',
      effectiveFrom: DateTime.utc(2026, 1, 12),
    ),
    'auto': FareConfig(
      versionId: 'fare_auto_v1',
      vehicleCategoryId: 'VC-1002',
      vehicleCategoryName: 'Auto',
      baseFare: 149,
      perKmCharge: 0,
      initialMinimum: 149,
      weightCapacityKg: 100,
      effectiveFrom: DateTime.utc(2026, 1, 12),
    ),
    'truck': FareConfig(
      versionId: 'fare_truck_v1',
      vehicleCategoryId: 'VC-1006',
      vehicleCategoryName: 'Truck',
      baseFare: 699,
      perKmCharge: 0,
      initialMinimum: 699,
      weightCapacityKg: 1000,
      effectiveFrom: DateTime.utc(2026, 1, 12),
    ),
  };

  static FareConfig currentFor(String categoryKey) {
    final String key = categoryKey.toLowerCase();
    return _current[key] ?? _current['bike']!;
  }

  /// Admin publishes a new version. Old snapshots keep the previous config.
  static void publish(String categoryKey, FareConfig config) {
    _current[categoryKey.toLowerCase()] = config;
  }

  static void resetDemo() {
    _current['bike'] = FareConfig(
      versionId: 'fare_bike_v1',
      vehicleCategoryId: 'VC-1001',
      vehicleCategoryName: 'Bike',
      baseFare: 79,
      perKmCharge: 0,
      initialMinimum: 79,
      weightCapacityKg: 20,
      size: '36cm',
      effectiveFrom: DateTime.utc(2026, 1, 12),
    );
  }
}

/// Confirmed V1 maximum: 2 or 3 delivery locations (not including pickup).
abstract final class BookingLimits {
  static const int maxDeliveryStops = 3;
  static const int minMultiDeliveryStops = 2;
  static const bool maxStopsPendingBusinessDecision = false;
}
