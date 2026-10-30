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

class RiderCategoryChoice {
  const RiderCategoryChoice({required this.id, required this.name});

  final String id;
  final String name;
}

/// Active catalog row for the selected id. A missing id is not replaced
/// with another category that happens to share a label.
String? riderCategoryIdForSave({
  required Iterable<({String id, String name, bool active})> rows,
  String? categoryId,
  String? categoryName,
}) {
  final String id = (categoryId ?? '').trim();
  if (id.isNotEmpty) {
    for (final row in rows) {
      if (row.active && row.id == id) {
        return row.id;
      }
    }
    return null;
  }
  final String name = (categoryName ?? '').trim().toLowerCase();
  if (name.isEmpty) {
    return null;
  }
  for (final row in rows) {
    if (row.active && row.name.trim().toLowerCase() == name) {
      return row.id;
    }
  }
  return null;
}

class VehicleInfo {
  const VehicleInfo({
    required this.type,
    required this.number,
    required this.model,
    required this.color,
    required this.manufacturingYear,
    this.categoryName,
    this.categoryId,
  });

  final RiderVehicleType type;
  final String number;
  final String model;
  final String color;
  final int manufacturingYear;
  final String? categoryName;
  final String? categoryId;

  static const VehicleInfo empty = VehicleInfo(
    type: RiderVehicleType.bike,
    number: '',
    model: '',
    color: '',
    manufacturingYear: 0,
  );

  bool get hasDetails => number.trim().isNotEmpty;

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
    String? categoryId,
  }) {
    return VehicleInfo(
      type: type ?? this.type,
      number: number ?? this.number,
      model: model ?? this.model,
      color: color ?? this.color,
      manufacturingYear: manufacturingYear ?? this.manufacturingYear,
      categoryName: categoryName ?? this.categoryName,
      categoryId: categoryId ?? this.categoryId,
    );
  }
}
