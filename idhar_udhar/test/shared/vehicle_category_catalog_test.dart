import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category_catalog.dart';

void main() {
  tearDown(() {
    VehicleCategoryCatalog.launchCityId = null;
  });

  test('active admin categories are kept and inactive ones are dropped', () {
    final parsed = VehicleCategoryCatalog.parsePayload(<String, dynamic>{
      'vehicle_categories': <Map<String, dynamic>>[
        <String, dynamic>{
          'vehicle_category_id': 'truck-1',
          'name': 'Truck',
          'active': true,
          'weight_capacity': '1000 kg',
        },
        <String, dynamic>{
          'vehicle_category_id': 'bike-1',
          'name': 'Bike',
          'active': false,
        },
        <String, dynamic>{
          'vehicle_category_id': 'scooty-1',
          'name': 'Scooty',
          'active': true,
        },
      ],
    });

    expect(parsed.map((row) => row.name), <String>['Truck', 'Scooty']);
    expect(parsed.first.id, 'truck-1');
  });

  test('launch_city_id is captured for booking quote and fare preview', () {
    VehicleCategoryCatalog.parsePayload(<String, dynamic>{
      'launch_city_id': '01a0aaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
      'vehicle_categories': <Map<String, dynamic>>[
        <String, dynamic>{
          'vehicle_category_id': 'bike-1',
          'name': 'Bike',
          'active': true,
          'rates': <String, Object>{
            'base_fare': '40.00',
            'per_km': '8.00',
          },
        },
      ],
    });
    expect(
      VehicleCategoryCatalog.launchCityId,
      '01a0aaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
    );
  });
}
