import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  compatibleVehicle,
  issuesForVehicleCategoryForm,
  isVehiclePair,
  vehiclesForType,
} from './vehicleCatalog.js';

const valid = [
  ['two_wheeler', 'bike'],
  ['two_wheeler', 'scooty'],
  ['three_wheeler', 'loader_riksha'],
  ['truck', 'mini_truck'],
  ['truck', 'tempo'],
  ['truck', 'large_tempo'],
  ['truck', 'truck'],
];

const invalid = [
  ['two_wheeler', 'tempo'],
  ['two_wheeler', 'truck'],
  ['three_wheeler', 'bike'],
  ['truck', 'bike'],
  ['three_wheeler', 'scooty'],
];

describe('admin vehicle hierarchy', () => {
  for (const [vehicleType, vehicle] of valid) {
    it(`accepts ${vehicleType} / ${vehicle}`, () => {
      assert.equal(isVehiclePair(vehicleType, vehicle), true);
      assert.equal(compatibleVehicle(vehicleType, vehicle), vehicle);
    });
  }

  for (const [vehicleType, vehicle] of invalid) {
    it(`rejects ${vehicleType} / ${vehicle}`, () => {
      assert.equal(isVehiclePair(vehicleType, vehicle), false);
      assert.equal(compatibleVehicle(vehicleType, vehicle), '');
    });
  }

  it('lists only the vehicles for the selected type', () => {
    assert.deepEqual(vehiclesForType('two_wheeler').map((item) => item.id), ['bike', 'scooty']);
    assert.deepEqual(vehiclesForType('three_wheeler').map((item) => item.id), ['loader_riksha']);
    assert.deepEqual(vehiclesForType('truck').map((item) => item.id), ['mini_truck', 'tempo', 'large_tempo', 'truck']);
    assert.deepEqual(vehiclesForType(''), []);
  });

  it('requires a vehicle after the type is chosen and derives the display name', () => {
    const missing = issuesForVehicleCategoryForm({
      vehicleType: 'truck',
      vehicle: '',
      riderSharePercent: '85',
      companyCommissionPercent: '15',
    });
    assert.equal(missing.issues.vehicle, 'Vehicle is required.');

    const saved = issuesForVehicleCategoryForm({
      vehicleType: 'truck',
      vehicle: 'large_tempo',
      riderSharePercent: '80',
      companyCommissionPercent: '20',
      baseFare: '10',
      perKmCharge: '2',
      initialMinimum: '10',
      waitingCharge: '1',
      surgeCharge: '0',
      tollCharge: '3',
      parkingCharge: '4',
      weightCapacityKg: '1500',
      size: 'large',
    });
    assert.equal(saved.name, 'Large Tempo');
    assert.deepEqual(saved.issues, {});
  });

  it('rejects invalid money, weight, and a commission split that is not 100', () => {
    const issues = issuesForVehicleCategoryForm({
      vehicleType: 'two_wheeler',
      vehicle: 'bike',
      riderSharePercent: '90',
      companyCommissionPercent: '15',
      baseFare: '-1',
      perKmCharge: '2',
      weightCapacityKg: '-5',
    }).issues;
    assert.equal(issues.companyCommissionPercent, 'Rider percentage and company commission must add up to 100%.');
    assert.equal(issues.baseFare, 'Base fare must be 0 or more.');
    assert.equal(issues.weightCapacityKg, 'Weight capacity must be 0 or more.');
  });

  it('rejects a second Bike and keeps an unrelated text weight', () => {
    const duplicate = issuesForVehicleCategoryForm(
      {
        id: 'new',
        vehicleType: 'two_wheeler',
        vehicle: 'bike',
        riderSharePercent: '85',
        companyCommissionPercent: '15',
      },
      [{ id: 'existing', name: 'Bike' }],
    );
    assert.equal(duplicate.issues.vehicle, 'This vehicle category already exists.');

    const textWeight = issuesForVehicleCategoryForm({
      id: 'existing',
      vehicleType: 'two_wheeler',
      vehicle: 'bike',
      riderSharePercent: '85',
      companyCommissionPercent: '15',
      weightCapacityKg: '20 kg',
    }, [{ id: 'existing', name: 'Bike' }]);
    assert.equal(textWeight.issues.weightCapacityKg, undefined);
  });
});
