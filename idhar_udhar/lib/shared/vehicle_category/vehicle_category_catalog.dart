import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_config.dart';
import 'vehicle_category.dart';

/// Active categories from NestJS. PostgreSQL UUIDs are the only ids.
abstract final class VehicleCategoryCatalog {
  static Future<List<VehicleCategory>> load() async {
    final response = await Dio().get<Map<String, dynamic>>(
      '${ApiConfig.baseUrl}/v1/vehicle-categories',
      options: Options(receiveTimeout: const Duration(seconds: 8)),
    );
    final rows = response.data?['vehicle_categories'];
    if (rows is! List) {
      return const <VehicleCategory>[];
    }
    return rows
        .whereType<Map<Object?, Object?>>()
        .map((row) => VehicleCategory.fromJson(Map<String, dynamic>.from(row)))
        .where((row) => row.isActive && row.id.isNotEmpty && row.name.trim().isNotEmpty)
        .toList(growable: false);
  }
}

final vehicleCategoryCatalogProvider =
    FutureProvider<List<VehicleCategory>>((ref) {
  return VehicleCategoryCatalog.load();
});
