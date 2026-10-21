import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/constants/asset_paths.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/customer/features/booking/presentation/screens/vehicle_selection_screen.dart';
import 'package:idhar_udhar/shared/vehicle_category/vehicle_category.dart';

VehicleCategory _category({
  required String id,
  required String name,
  String? vehicleType,
  String? vehicle,
  String? weightCapacity,
  double baseFare = 10,
}) {
  return VehicleCategory.fromJson(<String, Object?>{
    'id': id,
    'name': name,
    if (vehicleType != null) 'vehicle_type': vehicleType,
    if (vehicle != null) 'vehicle': vehicle,
    if (weightCapacity != null) 'weight_capacity': weightCapacity,
    'rates': <String, Object>{'base_fare': baseFare.toString()},
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('select vehicle orders two wheelers, three wheelers, then trucks', () {
    final List<VehicleCategory> source = <VehicleCategory>[
      _category(
        id: 'truck',
        name: 'Truck',
        vehicleType: 'truck',
        vehicle: 'truck',
        weightCapacity: '1500 kg',
        baseFare: 400,
      ),
      _category(
        id: 'scooty',
        name: 'Scooty',
        vehicleType: 'two_wheeler',
        vehicle: 'scooty',
        baseFare: 40,
      ),
      _category(
        id: 'large',
        name: 'Large Tempo',
        vehicleType: 'truck',
        vehicle: 'large_tempo',
        baseFare: 300,
      ),
      _category(
        id: 'riksha',
        name: 'Loader Riksha',
        vehicleType: 'three_wheeler',
        vehicle: 'loader_riksha',
        baseFare: 90,
      ),
      _category(
        id: 'tempo',
        name: 'Tempo',
        vehicleType: 'truck',
        vehicle: 'tempo',
        baseFare: 200,
      ),
      _category(
        id: 'bike',
        name: 'Bike',
        vehicleType: 'two_wheeler',
        vehicle: 'bike',
        baseFare: 30,
      ),
      _category(
        id: 'mini',
        name: 'Mini Truck',
        vehicleType: 'truck',
        vehicle: 'mini_truck',
        baseFare: 150,
      ),
      _category(id: 'other', name: 'Special Van', baseFare: 12),
    ];
    final List<String> before = source.map((VehicleCategory row) => row.id).toList();

    final List<VehicleCategory> sorted = sortedVehicleCategoriesForDisplay(source);

    expect(source.map((VehicleCategory row) => row.id), before);
    expect(
      sorted.map((VehicleCategory row) => row.id),
      <String>[
        'scooty',
        'bike',
        'riksha',
        'mini',
        'tempo',
        'large',
        'truck',
        'other',
      ],
    );
    expect(sorted, hasLength(source.length));
    expect(
      sorted.map((VehicleCategory row) => row.baseFare),
      <double>[40, 30, 90, 150, 200, 300, 400, 12],
    );

    expect(
      sorted
          .where((VehicleCategory row) => row.vehicleTypeCode == 'truck')
          .map((VehicleCategory row) => row.name),
      <String>['Mini Truck', 'Tempo', 'Large Tempo', 'Truck'],
    );
    final List<MockVehicle> trucks = vehiclesForBookingFamily(
      sorted
          .where((VehicleCategory row) => row.vehicleTypeCode == 'truck')
          .map(customerVehicleFromCategory)
          .toList(growable: false),
      ServiceFamily.truck,
    );
    expect(
      trucks.map((MockVehicle vehicle) => vehicle.name),
      <String>['Mini Truck', 'Tempo', 'Large Tempo', 'Truck'],
    );
    expect(
      vehiclesForBookingFamily(
        sorted.map(customerVehicleFromCategory).toList(growable: false),
        ServiceFamily.twoWheeler,
      ).map((MockVehicle vehicle) => vehicle.id),
      <String>['scooty', 'bike'],
    );
  });

  test('mini truck uses the shipped pickup image and it decodes', () async {
    final MockVehicle mini = customerVehicleFromCategory(
      _category(
        id: 'mini',
        name: 'Mini Truck',
        vehicleType: 'truck',
        vehicle: 'mini_truck',
      ),
    );
    final MockVehicle bike = customerVehicleFromCategory(
      _category(
        id: 'bike',
        name: 'Bike',
        vehicleType: 'two_wheeler',
        vehicle: 'bike',
      ),
    );
    final MockVehicle truck = customerVehicleFromCategory(
      _category(
        id: 'truck',
        name: 'Truck',
        vehicleType: 'truck',
        vehicle: 'truck',
      ),
    );

    expect(mini.imagePath, AssetPaths.pickupTruck);
    expect(
      mini.imagePath,
      'assets/customer/images/3d/idhar_udhar_pickup_truck_1.png',
    );
    expect(bike.imagePath, AssetPaths.bike);
    expect(truck.imagePath, AssetPaths.truck);
    expect(mini.imagePath, isNot(truck.imagePath));

    final ByteData data = await rootBundle.load(mini.imagePath);
    final Uint8List bytes = data.buffer.asUint8List();
    expect(bytes.length, greaterThan(24));
    expect(bytes.sublist(0, 8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);

    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    expect(frame.image.width, greaterThan(0));
    expect(frame.image.height, greaterThan(0));
    frame.image.dispose();
  });
}
