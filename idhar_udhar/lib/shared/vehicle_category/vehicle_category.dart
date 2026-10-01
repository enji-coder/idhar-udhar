class VehicleCategory {
  const VehicleCategory({
    required this.id,
    required this.name,
    this.code,
    this.status = 'Active',
    this.available = true,
    this.weightCapacity,
    this.size,
    this.baseFare = 0,
    this.perKm = 0,
    this.initialMinimum,
    this.waiting = 0,
    this.initialWaitingMinutes = 0,
    this.waitingPerMinute = 0,
    this.surge = 0,
    this.toll = 0,
    this.parking = 0,
    this.vehicleTypeCode,
    this.vehicleCode,
  });

  final String id;
  final String name;
  final String? code;
  final String status;
  final bool available;
  final String? weightCapacity;
  final String? size;
  final double baseFare;
  final double perKm;

  /// Admin minimum for this category. Null when the payload omits it.
  final double? initialMinimum;

  /// Legacy flat waiting amount. Not minutes and not added to the booking fare.
  final double waiting;

  /// Free pickup minutes before the per-minute waiting rate applies.
  final int initialWaitingMinutes;

  /// Rupees per minute after the free pickup wait. Informational before pickup.
  final double waitingPerMinute;
  final double surge;
  final double toll;
  final double parking;

  /// Backend `vehicle_type`: two_wheeler, three_wheeler, or truck.
  final String? vehicleTypeCode;

  /// Backend `vehicle`: bike, scooty, loader_riksha, truck, and so on.
  final String? vehicleCode;

  factory VehicleCategory.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rates =
        json['rates'] is Map ? Map<String, dynamic>.from(json['rates'] as Map) : const {};
    final bool active = json['active'] is bool
        ? json['active'] as bool
        : (json['status'] as String? ?? 'Active').toLowerCase() != 'inactive';
    return VehicleCategory(
      id: json['vehicle_category_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String?,
      status: active ? 'Active' : 'Inactive',
      available: active,
      weightCapacity: json['weight_capacity'] as String?,
      size: json['size'] as String?,
      baseFare: _money(rates['base_fare']),
      perKm: _money(rates['per_km']),
      initialMinimum: rates.containsKey('initial_minimum')
          ? _money(rates['initial_minimum'])
          : null,
      waiting: _money(rates['waiting']),
      initialWaitingMinutes: _minutes(rates['initial_waiting_minutes']),
      waitingPerMinute: _money(rates['waiting_charge_per_minute']),
      surge: _money(rates['surge']),
      toll: _money(rates['toll']),
      parking: _money(rates['parking']),
      vehicleTypeCode: json['vehicle_type'] as String?,
      vehicleCode: json['vehicle'] as String?,
    );
  }

  bool get isActive => status.toLowerCase() != 'inactive' && available;

  static int _minutes(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _money(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
