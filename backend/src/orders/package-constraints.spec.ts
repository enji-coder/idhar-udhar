import { ApiError } from '../common/errors/api-error';
import {
  assertPackageForVehicle,
  packageExceedsCapacity,
  parseCapacityKg,
} from './package-constraints';

describe('package capacity', () => {
  it('reads a numeric kilogram capacity and ignores unstructured text', () => {
    expect(parseCapacityKg('20')).toBe(20);
    expect(parseCapacityKg('1000 kg')).toBe(1000);
    expect(parseCapacityKg('20kg')).toBe(20);
    expect(parseCapacityKg('about 20')).toBeNull();
    expect(parseCapacityKg(null)).toBeNull();
  });

  it('rejects a package heavier than the selected vehicle', () => {
    expect(packageExceedsCapacity(25, '20 kg')).toBe(true);
    expect(() =>
      assertPackageForVehicle({ weightKg: 25, weightCapacity: '20 kg' }),
    ).toThrow(ApiError);
  });

  it('accepts a package within the selected vehicle capacity', () => {
    expect(packageExceedsCapacity(20, '20')).toBe(false);
    expect(() =>
      assertPackageForVehicle({ weightKg: 10, weightCapacity: '20 kg' }),
    ).not.toThrow();
  });

  it('requires a weight when the vehicle has a numeric capacity', () => {
    expect(() =>
      assertPackageForVehicle({ weightKg: null, weightCapacity: '20' }),
    ).toThrow('Package weight is required for this vehicle');
  });

  it('does not invent a limit when capacity is not numeric', () => {
    expect(() =>
      assertPackageForVehicle({ weightKg: 80, weightCapacity: 'large' }),
    ).not.toThrow();
  });
});
