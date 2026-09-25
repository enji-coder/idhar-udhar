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
    );
  }

  bool get isActive => status.toLowerCase() != 'inactive' && available;

  static double _money(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
