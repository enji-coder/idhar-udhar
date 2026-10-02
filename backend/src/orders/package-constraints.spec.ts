import { ApiError } from '../common/errors/api-error';
import {
  assertDropContact,
  assertPackageForVehicle,
  packageExceedsCapacity,
  packageExceedsSize,
  parseCapacityKg,
  parseSizeCm,
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

describe('package size', () => {
  it('reads centimetres from admin size text', () => {
    expect(parseSizeCm('36cm')).toBe(36);
    expect(parseSizeCm('36')).toBe(36);
    expect(parseSizeCm('30 CM')).toBe(30);
    expect(parseSizeCm('large')).toBeNull();
  });

  it('rejects a parcel larger than the vehicle limit', () => {
    expect(packageExceedsSize(60, '36cm')).toBe(true);
    expect(() =>
      assertPackageForVehicle({
        weightKg: 5,
        weightCapacity: '20 kg',
        packageSizeCm: 60,
        sizeLimit: '36cm',
      }),
    ).toThrow('Package size exceeds this vehicle limit');
  });

  it('requires size when the vehicle has a numeric size limit', () => {
    expect(() =>
      assertPackageForVehicle({
        weightKg: 5,
        weightCapacity: '20 kg',
        packageSizeCm: null,
        sizeLimit: '36cm',
      }),
    ).toThrow('Package size is required for this vehicle');
  });
});

describe('drop contact', () => {
  it('requires receiver name and a 10-digit mobile', () => {
    expect(() =>
      assertDropContact({ contactName: '', contactPhone: '9876543210' }),
    ).toThrow('Receiver name is required');
    expect(() =>
      assertDropContact({ contactName: 'Asha', contactPhone: '123' }),
    ).toThrow('Receiver mobile must be a valid 10-digit number');
    expect(() =>
      assertDropContact({ contactName: 'Asha', contactPhone: '9876543210' }),
    ).not.toThrow();
  });
});
