class VehicleCategory {
  const VehicleCategory({
    required this.id,
    required this.name,
    this.status = 'Active',
    this.available = true,
  });

  final String id;
  final String name;
  final String status;
  final bool available;

  bool get isActive => status.toLowerCase() != 'inactive';

  factory VehicleCategory.fromJson(Map<String, dynamic> json) {
    return VehicleCategory(
      id: json['id'] as String? ?? json['name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'Active',
      available: json['available'] as bool? ?? true,
    );
  }
}
