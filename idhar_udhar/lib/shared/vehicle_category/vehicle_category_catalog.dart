import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'vehicle_category.dart';

/// Single catalog used by Rider selection and Customer availability.
/// Admin CRUD is the source of truth; this client consumes the same API.
abstract final class VehicleCategoryCatalog {
  static const String endpoint =
      'https://idhar-udhar-admin.netlify.app/.netlify/functions/vehicle-categories';

  static const List<VehicleCategory> fallback = [
    VehicleCategory(id: 'VC-1001', name: 'Bike', available: true),
    VehicleCategory(id: 'VC-1002', name: 'Auto', available: true),
    VehicleCategory(id: 'VC-1003', name: 'Mini Truck', available: false),
    VehicleCategory(id: 'VC-1004', name: 'Tempo', available: false),
    VehicleCategory(id: 'VC-1005', name: 'Large Tempo', available: false),
    VehicleCategory(id: 'VC-1006', name: 'Truck', available: true),
  ];

  static List<VehicleCategory> _cache = List<VehicleCategory>.from(fallback);

  static List<VehicleCategory> get current =>
      List<VehicleCategory>.unmodifiable(_cache);

  static List<VehicleCategory> get active =>
      current.where((row) => row.isActive).toList();

  static List<VehicleCategory> get selectable =>
      active.where((row) => row.available).toList();

  static Future<List<VehicleCategory>> load() async {
    try {
      final response = await Dio().get<Map<String, dynamic>>(
        endpoint,
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );
      final rows = response.data?['categories'];
      if (rows is List && rows.isNotEmpty) {
        _cache = rows
            .whereType<Map>()
            .map((row) => VehicleCategory.fromJson(
                  Map<String, dynamic>.from(row),
                ))
            .where((row) => row.name.trim().isNotEmpty)
            .toList();
      }
    } catch (_) {
      /* keep last known / fallback seed */
    }
    return current;
  }
}

final vehicleCategoryCatalogProvider =
    FutureProvider<List<VehicleCategory>>((ref) {
  return VehicleCategoryCatalog.load();
});
