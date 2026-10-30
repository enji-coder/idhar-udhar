import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/constants/asset_paths.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_data.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/screens/vehicle_selection_screen.dart';
import 'package:idhar_udhar/shared/parcel/dimension_cm.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category.dart';

VehicleCategory _row({
  required String id,
  required String name,
  String? vehicleType,
  String? vehicle,
  String? size,
}) {
  return VehicleCategory.fromJson(<String, Object?>{
    'vehicle_category_id': id,
    'name': name,
    'active': true,
    if (vehicleType != null) 'vehicle_type': vehicleType,
    if (vehicle != null) 'vehicle': vehicle,
    if (size != null) 'size': size,
    'rates': <String, Object>{
      'base_fare': '40',
      'per_km': '8',
    },
  });
}

void main() {
  const String bike = '01a18c7f-0435-720a-824d-7cb9a618da57';
  const String scooty = '01a18c7f-045c-7542-af93-0e07e40a6ef7';
  const String tempo3w = '01a18c7f-0483-7740-8e37-5bdd836f2159';
  const String auto3w = '01a18c7f-04ac-7aa4-ae2e-11519aea01de';
  const String ace = '01a18c7f-04d7-7a83-bb64-91afe3935cd0';
  const String pickup = '01a18c7f-0505-7105-a040-9ac900edc5b7';
  const String tempo407 = '01a18c7f-053b-725b-84fa-bf4407562056';
  const String eicher = '01a18c7f-0567-7eb1-94eb-7ff7c530e107';

  final List<VehicleCategory> catalog = <VehicleCategory>[
    _row(id: bike, name: 'Bike', vehicleType: 'two_wheeler', vehicle: 'bike', size: '36 cm'),
    _row(id: scooty, name: 'Scooty', vehicleType: 'two_wheeler', vehicle: 'scooty', size: '36 cm'),
    _row(id: tempo3w, name: '3W Tempo', size: '5.5 ft long, 4.5 ft wide, 5 ft high'),
    _row(id: auto3w, name: '3W Auto', size: '60 cm'),
    _row(id: ace, name: 'Chhota Hathi / Tata Ace', size: '7.2 ft long, 5 ft wide, 2 ft high'),
    _row(id: pickup, name: 'Pickup', size: '8 ft'),
    _row(id: tempo407, name: 'Tempo 407', size: '10 ft'),
    _row(id: eicher, name: 'Truck / Eicher', size: '14 ft'),
  ];

  test('all eight category ids stay on the booking vehicle', () {
    final List<MockVehicle> vehicles =
        catalog.map(customerVehicleFromCategory).toList(growable: false);
    expect(
      vehicles.map((MockVehicle vehicle) => vehicle.id),
      <String>[bike, scooty, tempo3w, auto3w, ace, pickup, tempo407, eicher],
    );
    expect(
      vehicles.map((MockVehicle vehicle) => vehicle.name),
      <String>[
        'Bike',
        'Scooty',
        '3W Tempo',
        '3W Auto',
        'Chhota Hathi / Tata Ace',
        'Pickup',
        'Tempo 407',
        'Truck / Eicher',
      ],
    );
  });

  test('3W Tempo is not placed on the truck tile because of its name', () {
    final List<MockVehicle> vehicles =
        catalog.map(customerVehicleFromCategory).toList(growable: false);
    expect(
      vehiclesForBookingFamily(vehicles, ServiceFamily.threeWheeler)
          .map((MockVehicle vehicle) => vehicle.id),
      <String>[tempo3w, auto3w],
    );
    expect(
      vehiclesForBookingFamily(vehicles, ServiceFamily.truck)
          .map((MockVehicle vehicle) => vehicle.id),
      <String>[ace, pickup, tempo407, eicher],
    );
    expect(
      vehiclesForBookingFamily(vehicles, ServiceFamily.twoWheeler)
          .map((MockVehicle vehicle) => vehicle.id),
      <String>[bike, scooty],
    );
    final MockVehicle tempo = vehicles
        .firstWhere((MockVehicle vehicle) => vehicle.id == tempo3w);
    expect(tempo.serviceFamily, ServiceFamily.threeWheeler);
    expect(tempo.imagePath, isNot(AssetPaths.truck));
    expect(
      MockData.artworkForCategoryName('3W Tempo'),
      isNot(AssetPaths.truck),
    );
  });

  test('an unknown name is not given a truck identity', () {
    final MockVehicle unknown = customerVehicleFromCategory(
      _row(id: 'future-1', name: 'Special Van'),
    );
    expect(unknown.id, 'future-1');
    expect(unknown.serviceFamily, isNull);
    expect(unknown.imagePath, AssetPaths.parcel);
    expect(
      vehiclesForBookingFamily(<MockVehicle>[unknown], ServiceFamily.truck),
      isEmpty,
    );
  });

  test('feet are centimetres and a box is not one guessed limit', () {
    expect(parseSingleSizeLimitCm('36 cm'), 36);
    expect(parseSingleSizeLimitCm('60 cm'), 60);
    expect(parseSingleSizeLimitCm('8 ft'), 243.84);
    expect(parseSingleSizeLimitCm('10 ft'), 304.8);
    expect(parseSingleSizeLimitCm('14 ft'), 426.72);
    expect(parseSingleSizeLimitCm('8'), isNull);
    final LabeledBoxThousandths? box =
        parseLabeledBoxThousandths('5.5 ft long, 4.5 ft wide, 5 ft high');
    expect(box?.lengthCm, 167.64);
    expect(box?.widthCm, 137.16);
    expect(box?.heightCm, 152.4);
    expect(parseSingleSizeLimitCm('5.5 ft long, 4.5 ft wide, 5 ft high'), isNull);
  });
}
