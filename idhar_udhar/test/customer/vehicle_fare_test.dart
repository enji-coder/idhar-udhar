import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/customer/core/data/mock/mock_models.dart';
import 'package:idhar_udhar/customer/core/state/vehicle_fare.dart';

VehicleFareOption _option({
  required String id,
  required String vehicle,
  required String vehicleType,
  required double tripFare,
  double? capacityKg,
  String? capacity,
}) {
  return VehicleFareOption(
    vehicleCategoryId: id,
    name: vehicle,
    vehicleType: vehicleType,
    vehicle: vehicle,
    tripFare: tripFare,
    netPayable: tripFare,
    baseFare: 100,
    distanceCharge: tripFare - 100,
    waiting: 0,
    surge: 0,
    toll: 0,
    parking: 0,
    discount: 0,
    rounding: 0,
    tax: 0,
    weightCapacity: capacity,
    weightCapacityKg: capacityKg,
  );
}

void main() {
  final VehicleFareOption truck = _option(
    id: 'truck-1',
    vehicle: 'truck',
    vehicleType: 'truck',
    tripFare: 819,
    capacityKg: 1000,
    capacity: '1000 kg',
  );
  final VehicleFareOption tempo = _option(
    id: 'tempo-1',
    vehicle: 'tempo',
    vehicleType: 'truck',
    tripFare: 420,
    capacityKg: 500,
    capacity: '500 kg',
  );
  final List<VehicleFareOption> options = <VehicleFareOption>[truck, tempo];

  test('parses the backend vehicle list and drops inactive or taxed rows', () {
    final VehicleFarePreview preview = VehicleFarePreview.parse(<String, dynamic>{
      'distance_km': '12.000',
      'vehicles': <Map<String, dynamic>>[
        <String, dynamic>{
          'vehicle_category_id': 'truck-1',
          'name': 'Truck',
          'vehicle_type': 'truck',
          'vehicle': 'truck',
          'active': true,
          'weight_capacity': '1000 kg',
          'weight_capacity_kg': '1000.000',
          'fare': <String, dynamic>{
            'trip_fare': '819.00',
            'net_payable': '819.00',
            'base_fare': '100.00',
            'distance_charge': '120.00',
            'tax': '0.00',
          },
        },
        <String, dynamic>{
          'vehicle_category_id': 'bike-1',
          'name': 'Bike',
          'vehicle_type': 'two_wheeler',
          'vehicle': 'bike',
          'active': false,
          'fare': <String, dynamic>{'trip_fare': '79.00', 'tax': '0.00'},
        },
        <String, dynamic>{
          'vehicle_category_id': 'taxed',
          'name': 'Taxed',
          'vehicle_type': 'truck',
          'vehicle': 'tempo',
          'active': true,
          'fare': <String, dynamic>{'trip_fare': '10.00', 'tax': '5.00'},
        },
      ],
    });

    expect(preview.distanceLabel, '12.0 km');
    expect(preview.vehicles.map((VehicleFareOption row) => row.name), <String>['Truck']);
    expect(preview.vehicles.single.tripFare, 819);
    expect(preview.vehicles.single.weightCapacityKg, 1000);
  });

  test('selecting a vehicle shows that vehicle fare', () {
    const VehicleFareSelection selection = VehicleFareSelection(
      calculating: false,
      options: <VehicleFareOption>[],
      selectedId: 'truck-1',
      packageWeightKg: 10,
      family: ServiceFamily.truck,
    );
    final VehicleFareSelection priced = VehicleFareSelection(
      calculating: false,
      options: options,
      selectedId: selection.selectedId,
      packageWeightKg: 10,
      family: ServiceFamily.truck,
    );

    expect(priced.visible.map((VehicleFareOption row) => row.vehicle), <String>[
      'truck',
      'tempo',
    ]);
    expect(priced.fareLabelFor('truck-1'), '₹819');
    expect(priced.selected?.vehicleCategoryId, 'truck-1');
    expect(priced.canContinueSelection, isTrue);
  });

  test('changing vehicle does not keep the previous fare', () {
    final VehicleFareSelection truckSelected = VehicleFareSelection(
      calculating: false,
      options: options,
      selectedId: 'truck-1',
      packageWeightKg: 10,
      family: ServiceFamily.truck,
    );
    final VehicleFareSelection tempoSelected = VehicleFareSelection(
      calculating: false,
      options: options,
      selectedId: 'tempo-1',
      packageWeightKg: 10,
      family: ServiceFamily.truck,
    );

    expect(truckSelected.selected?.tripFare, 819);
    expect(tempoSelected.selected?.tripFare, 420);
    expect(tempoSelected.fareLabelFor('tempo-1'), isNot('₹819'));
    expect(tempoSelected.selected?.weightCapacityKg, 500);
  });

  test('loading hides fares so a previous price cannot be shown as current', () {
    final VehicleFareSelection loading = VehicleFareSelection(
      calculating: true,
      options: options,
      selectedId: 'tempo-1',
      packageWeightKg: 10,
      family: ServiceFamily.truck,
    );

    expect(loading.visible, isEmpty);
    expect(loading.selected, isNull);
    expect(loading.fareLabelFor('tempo-1'), 'Calculating');
    expect(loading.canContinueSelection, isFalse);
  });

  test('package constraints follow the selected vehicle', () {
    final VehicleFareSelection bike = VehicleFareSelection(
      calculating: false,
      options: <VehicleFareOption>[
        _option(
          id: 'bike-1',
          vehicle: 'bike',
          vehicleType: 'two_wheeler',
          tripFare: 90,
          capacityKg: 20,
          capacity: '20 kg',
        ),
      ],
      selectedId: 'bike-1',
      packageWeightKg: 25,
      family: ServiceFamily.twoWheeler,
    );
    expect(bike.packageError, contains('exceeds'));
    expect(bike.canContinuePackage, isFalse);

    final VehicleFareSelection corrected = VehicleFareSelection(
      calculating: false,
      options: bike.options,
      selectedId: 'bike-1',
      packageWeightKg: 10,
      family: ServiceFamily.twoWheeler,
    );
    expect(corrected.packageError, isNull);
    expect(corrected.canContinuePackage, isTrue);
    expect(corrected.selected?.vehicleCategoryId, 'bike-1');
  });

  test('customer fare lines omit GST and unused components', () {
    final List<FareLine> lines = customerFareLines(
      baseFare: 100,
      distanceCharge: 120,
      waiting: 0,
      surge: 15,
      toll: 0,
      parking: 0,
      discount: 0,
      rounding: 0,
    );
    expect(
      lines.map((FareLine line) => line.label),
      <String>['Base Fare', 'Distance Charge', 'Surge Charge'],
    );
  });
}
