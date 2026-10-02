import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/state/booking_api.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category_catalog.dart';

void main() {
  tearDown(() {
    VehicleCategoryCatalog.launchCityId = null;
  });

  test('resolveBookingCityId uses launch_city_id when IU_CITY_ID is unset', () async {
    const String launchCity = '01a0fc52-fafe-72d5-b4cc-ed34ebb3b9cc';
    final String cityId = await resolveBookingCityId(() async {
      VehicleCategoryCatalog.parsePayload(<String, dynamic>{
        'launch_city_id': launchCity,
        'vehicle_categories': <Map<String, dynamic>>[
          <String, dynamic>{
            'vehicle_category_id': 'bike-1',
            'name': 'Bike',
            'active': true,
          },
        ],
      });
      return const <VehicleCategory>[];
    });
    expect(cityId, launchCity);
  });

  test('resolveBookingCityId keeps cached launch city if catalog reload fails', () async {
    VehicleCategoryCatalog.launchCityId = '01a0fc52-fafe-72d5-b4cc-ed34ebb3b9cc';
    final String cityId = await resolveBookingCityId(() async {
      throw StateError('catalog unavailable');
    });
    expect(cityId, '01a0fc52-fafe-72d5-b4cc-ed34ebb3b9cc');
  });
}
