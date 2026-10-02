import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_config.dart';
import 'vehicle_category.dart';

/// Active categories from NestJS. PostgreSQL UUIDs are the only ids.
abstract final class VehicleCategoryCatalog {
  /// Launch city from the last successful [load]. Used when `IU_CITY_ID` is unset.
  static String? launchCityId;

  static Future<List<VehicleCategory>> load() async {
    final response = await Dio().get<Map<String, dynamic>>(
      '${ApiConfig.baseUrl}/v1/vehicle-categories',
      options: Options(receiveTimeout: const Duration(seconds: 8)),
    );
    return parsePayload(response.data);
  }

  /// Accepts the public `{ vehicle_categories: [...], launch_city_id? }` payload.
  ///
  /// JSON maps arrive as `Map<String, dynamic>`. `Map` is invariant, so a
  /// `whereType<Map<Object?, Object?>>()` check drops every real row.
  static List<VehicleCategory> parsePayload(Object? data) {
    if (data is Map) {
      final Object? city = data['launch_city_id'];
      if (city is String && city.trim().isNotEmpty) {
        launchCityId = city.trim();
      }
    }
    final Object? rows = data is Map ? data['vehicle_categories'] : null;
    if (rows is! List) {
      return const <VehicleCategory>[];
    }
    final List<VehicleCategory> parsed = <VehicleCategory>[];
    for (final Object? item in rows) {
      if (item is! Map) {
        continue;
      }
      final VehicleCategory row =
          VehicleCategory.fromJson(Map<String, dynamic>.from(item));
      if (row.isActive && row.id.isNotEmpty && row.name.trim().isNotEmpty) {
        parsed.add(row);
      }
    }
    return parsed;
  }
}

final vehicleCategoryCatalogProvider =
    FutureProvider<List<VehicleCategory>>((ref) {
  return VehicleCategoryCatalog.load();
});
