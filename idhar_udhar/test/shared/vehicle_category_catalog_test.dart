import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category_catalog.dart';

void main() {
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
}
