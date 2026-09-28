import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/shared/api/json_codec.dart';

class VehicleFareOption {
  const VehicleFareOption({
    required this.vehicleCategoryId,
    required this.name,
    required this.vehicleType,
    required this.vehicle,
    required this.tripFare,
    required this.netPayable,
    required this.baseFare,
    required this.distanceCharge,
    required this.waiting,
    required this.surge,
    required this.toll,
    required this.parking,
    required this.discount,
    required this.rounding,
    required this.tax,
    this.weightCapacity,
    this.weightCapacityKg,
    this.size,
  });

  final String vehicleCategoryId;
  final String name;
  final String vehicleType;
  final String vehicle;
  final String? weightCapacity;
  final double? weightCapacityKg;
  final String? size;
  final double tripFare;
  final double netPayable;
  final double baseFare;
  final double distanceCharge;
  final double waiting;
  final double surge;
  final double toll;
  final double parking;
  final double discount;
  final double rounding;
  final double tax;

  String get capacityLabel {
    final String text = (weightCapacity ?? '').trim();
    if (text.isNotEmpty) {
      return text;
    }
    if (weightCapacityKg != null) {
      return '${_kg(weightCapacityKg!)} kg';
    }
    return 'Capacity set by admin';
  }

  bool matchesFamily(ServiceFamily? family) {
    if (family == null) {
      return true;
    }
    switch (family) {
      case ServiceFamily.twoWheeler:
        return vehicleType == 'two_wheeler';
      case ServiceFamily.threeWheeler:
        return vehicleType == 'three_wheeler';
      case ServiceFamily.truck:
        return vehicleType == 'truck';
    }
  }
}

class VehicleFarePreview {
  const VehicleFarePreview({
    required this.distanceKm,
    required this.vehicles,
  });

  factory VehicleFarePreview.parse(Object? data) {
    final Map<String, Object?> json = jsonObject(data);
    final List<VehicleFareOption> vehicles = <VehicleFareOption>[];
    for (final Object? item in jsonList(json['vehicles'])) {
      final Map<String, Object?> row = jsonObject(item);
      if (row['active'] == false) {
        continue;
      }
      final String id = jsonString(row['vehicle_category_id']) ?? '';
      final String vehicle = jsonString(row['vehicle']) ?? '';
      final String vehicleType = jsonString(row['vehicle_type']) ?? '';
      if (id.isEmpty || vehicle.isEmpty || vehicleType.isEmpty) {
        continue;
      }
      final Map<String, Object?> fare = jsonObject(row['fare']);
      final double tax = jsonDouble(fare['tax']);
      if (tax != 0) {
        continue;
      }
      vehicles.add(
        VehicleFareOption(
          vehicleCategoryId: id,
          name: jsonString(row['name']) ?? vehicle,
          vehicleType: vehicleType,
          vehicle: vehicle,
          weightCapacity: jsonString(row['weight_capacity']),
          weightCapacityKg: _optionalKg(row['weight_capacity_kg']),
          size: jsonString(row['size']),
          tripFare: jsonDouble(fare['trip_fare']),
          netPayable: jsonDouble(fare['net_payable']),
          baseFare: jsonDouble(fare['base_fare']),
          distanceCharge: jsonDouble(fare['distance_charge']),
          waiting: jsonDouble(fare['waiting']),
          surge: jsonDouble(fare['surge']),
          toll: jsonDouble(fare['toll']),
          parking: jsonDouble(fare['parking']),
          discount: jsonDouble(fare['discount']),
          rounding: jsonDouble(fare['rounding']),
          tax: tax,
        ),
      );
    }
    return VehicleFarePreview(
      distanceKm: jsonDouble(json['distance_km']),
      vehicles: vehicles,
    );
  }

  final double distanceKm;
  final List<VehicleFareOption> vehicles;

  String get distanceLabel => '${distanceKm.toStringAsFixed(1)} km';

  VehicleFareOption? byId(String? id) {
    if (id == null || id.isEmpty) {
      return null;
    }
    for (final VehicleFareOption option in vehicles) {
      if (option.vehicleCategoryId == id) {
        return option;
      }
    }
    return null;
  }
}

class FareLine {
  const FareLine(this.label, this.amount);

  final String label;
  final double amount;
}

/// Customer breakdown. GST is never a line. Zero components are omitted.
List<FareLine> customerFareLines({
  required double baseFare,
  required double distanceCharge,
  required double waiting,
  required double surge,
  required double toll,
  required double parking,
  required double discount,
  required double rounding,
}) {
  return <FareLine>[
    if (baseFare > 0) FareLine('Base Fare', baseFare),
    if (distanceCharge > 0) FareLine('Distance Charge', distanceCharge),
    if (waiting > 0) FareLine('Waiting Charge', waiting),
    if (surge > 0) FareLine('Surge Charge', surge),
    if (toll > 0) FareLine('Toll Charge', toll),
    if (parking > 0) FareLine('Parking Charge', parking),
    if (discount > 0) FareLine('Discount', discount),
    if (rounding.abs() >= 0.005) FareLine('Rounding', rounding),
  ];
}

class VehicleFareSelection {
  const VehicleFareSelection({
    required this.calculating,
    required this.options,
    required this.selectedId,
    required this.packageWeightKg,
    this.family,
  });

  final bool calculating;
  final List<VehicleFareOption> options;
  final String? selectedId;
  final ServiceFamily? family;
  final double packageWeightKg;

  List<VehicleFareOption> get visible {
    if (calculating) {
      return const <VehicleFareOption>[];
    }
    return options
        .where((VehicleFareOption option) => option.matchesFamily(family))
        .toList(growable: false);
  }

  VehicleFareOption? get selected {
    if (calculating) {
      return null;
    }
    for (final VehicleFareOption option in visible) {
      if (option.vehicleCategoryId == selectedId) {
        return option;
      }
    }
    return null;
  }

  String fareLabelFor(String vehicleCategoryId) {
    if (calculating) {
      return 'Calculating';
    }
    for (final VehicleFareOption option in visible) {
      if (option.vehicleCategoryId == vehicleCategoryId) {
        return '₹${option.tripFare.toStringAsFixed(0)}';
      }
    }
    return '—';
  }

  String? get packageError {
    final VehicleFareOption? option = selected;
    final double? capacity = option?.weightCapacityKg;
    if (option == null || capacity == null) {
      return null;
    }
    final int weight = (packageWeightKg * 1000).round();
    final int limit = (capacity * 1000).round();
    if (weight > limit) {
      return 'Package weight exceeds this vehicle capacity of ${_kg(capacity)} kg.';
    }
    return null;
  }

  bool get canContinueSelection => selected != null;

  bool get canContinuePackage => selected != null && packageError == null;
}

String _kg(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

double? _optionalKg(Object? value) {
  if (value == null) {
    return null;
  }
  final double parsed = jsonDouble(value, fallback: -1);
  if (parsed <= 0) {
    return null;
  }
  return parsed;
}
