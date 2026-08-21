enum RiderVehicleType {
  bike,
  auto,
  miniTruck,
}

extension RiderVehicleTypeX on RiderVehicleType {
  String get label {
    switch (this) {
      case RiderVehicleType.bike:
        return 'Bike';
      case RiderVehicleType.auto:
        return 'Auto';
      case RiderVehicleType.miniTruck:
        return 'Mini Truck';
    }
  }

  static RiderVehicleType fromLabel(String? name) {
    switch ((name ?? '').trim().toLowerCase()) {
      case 'auto':
      case 'three wheeler':
        return RiderVehicleType.auto;
      case 'mini truck':
      case 'tempo':
      case 'large tempo':
      case 'truck':
        return RiderVehicleType.miniTruck;
      default:
        return RiderVehicleType.bike;
    }
  }

  String get subtitle {
    switch (this) {
      case RiderVehicleType.bike:
        return 'Best for city parcels & food';
      case RiderVehicleType.auto:
        return 'Ideal for medium packages';
      case RiderVehicleType.miniTruck:
        return 'For bulk & heavy deliveries';
    }
  }

  bool get isRecommended => this == RiderVehicleType.bike;
}

class VehicleInfo {
  const VehicleInfo({
    required this.type,
    required this.number,
    required this.model,
    required this.color,
    required this.manufacturingYear,
    this.categoryName,
  });

  final RiderVehicleType type;
  final String number;
  final String model;
  final String color;
  final int manufacturingYear;
  final String? categoryName;

  String get displayType =>
      (categoryName != null && categoryName!.trim().isNotEmpty)
          ? categoryName!.trim()
          : type.label;

  VehicleInfo copyWith({
    RiderVehicleType? type,
    String? number,
    String? model,
    String? color,
    int? manufacturingYear,
    String? categoryName,
  }) {
    return VehicleInfo(
      type: type ?? this.type,
      number: number ?? this.number,
      model: model ?? this.model,
      color: color ?? this.color,
      manufacturingYear: manufacturingYear ?? this.manufacturingYear,
      categoryName: categoryName ?? this.categoryName,
    );
  }
}
