import 'package:flutter_test/flutter_test.dart';
import 'package:idhar_udhar/rider/data/models/vehicle_info.dart';

void main() {
  const List<({String id, String name, bool active})> rows =
      <({String id, String name, bool active})>[
    (id: '01a18c7f-0435-720a-824d-7cb9a618da57', name: 'Bike', active: true),
    (id: '01a18c7f-045c-7542-af93-0e07e40a6ef7', name: 'Scooty', active: true),
    (id: '01a18c7f-0483-7740-8e37-5bdd836f2159', name: '3W Tempo', active: true),
    (id: '01a18c7f-04ac-7aa4-ae2e-11519aea01de', name: '3W Auto', active: true),
    (
      id: '01a18c7f-04d7-7a83-bb64-91afe3935cd0',
      name: 'Chhota Hathi / Tata Ace',
      active: true,
    ),
    (id: '01a18c7f-0505-7105-a040-9ac900edc5b7', name: 'Pickup', active: true),
    (id: '01a18c7f-053b-725b-84fa-bf4407562056', name: 'Tempo 407', active: true),
    (
      id: '01a18c7f-0567-7eb1-94eb-7ff7c530e107',
      name: 'Truck / Eicher',
      active: true,
    ),
  ];

  test('each category id is saved as that id', () {
    for (final row in rows) {
      expect(
        riderCategoryIdForSave(rows: rows, categoryId: row.id),
        row.id,
      );
    }
  });

  test('a missing id is not replaced with Bike', () {
    expect(
      riderCategoryIdForSave(
        rows: rows,
        categoryId: '01a18c7f-0000-7000-8000-000000000000',
        categoryName: 'Bike',
      ),
      isNull,
    );
  });

  test('reloaded profile keeps the category id', () {
    const VehicleInfo saved = VehicleInfo(
      type: RiderVehicleType.bike,
      number: 'GJ01AB1234',
      model: 'Ace',
      color: 'White',
      manufacturingYear: 2020,
      categoryName: 'Scooty',
      categoryId: '01a18c7f-045c-7542-af93-0e07e40a6ef7',
    );
    final VehicleInfo reloaded = saved.copyWith();
    expect(reloaded.categoryId, '01a18c7f-045c-7542-af93-0e07e40a6ef7');
    expect(reloaded.displayType, 'Scooty');
    expect(
      riderCategoryIdForSave(
        rows: rows,
        categoryId: reloaded.categoryId,
        categoryName: reloaded.categoryName,
      ),
      '01a18c7f-045c-7542-af93-0e07e40a6ef7',
    );
  });

  test('an inactive category is not selected', () {
    expect(
      riderCategoryIdForSave(
        rows: <({String id, String name, bool active})>[
          (id: rows.first.id, name: 'Bike', active: false),
        ],
        categoryId: rows.first.id,
      ),
      isNull,
    );
  });
}
