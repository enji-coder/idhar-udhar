import { ApiError } from '../common/errors/api-error';
import {
  assertDropContact,
  assertPackageForVehicle,
  packageExceedsCapacity,
  packageExceedsSize,
  parseCapacityKg,
  parseLabeledBoxCm,
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
  it('reads an explicit centimetre limit and ignores a missing unit', () => {
    expect(parseSizeCm('36cm')).toBe(36);
    expect(parseSizeCm('36 cm')).toBe(36);
    expect(parseSizeCm('30 CM')).toBe(30);
    expect(parseSizeCm('36')).toBeNull();
    expect(parseSizeCm('large')).toBeNull();
    expect(parseSizeCm('about 8 ft')).toBeNull();
  });

  it('converts feet, inches, millimetres, and metres into centimetres', () => {
    expect(parseSizeCm('8 ft')).toBe(243.84);
    expect(parseSizeCm('8 feet')).toBe(243.84);
    expect(parseSizeCm('10 ft')).toBe(304.8);
    expect(parseSizeCm('14 ft')).toBe(426.72);
    expect(parseSizeCm('5 ft')).toBe(152.4);
    expect(parseSizeCm('4.5 ft')).toBe(137.16);
    expect(parseSizeCm('7.2 ft')).toBe(219.456);
    expect(parseSizeCm('5.5 ft')).toBe(167.64);
    expect(parseSizeCm('1 in')).toBe(2.54);
    expect(parseSizeCm('2 inch')).toBe(5.08);
    expect(parseSizeCm('12 inches')).toBe(30.48);
    expect(parseSizeCm('10 mm')).toBe(1);
    expect(parseSizeCm('1.5 m')).toBe(150);
  });

  it('keeps each side of a labeled box and does not pick one limit', () => {
    expect(
      parseLabeledBoxCm('5.5 ft long, 4.5 ft wide, 5 ft high'),
    ).toEqual({
      lengthCm: 167.64,
      widthCm: 137.16,
      heightCm: 152.4,
    });
    expect(
      parseLabeledBoxCm('7.2 ft long, 5 ft wide, 2 ft high'),
    ).toEqual({
      lengthCm: 219.456,
      widthCm: 152.4,
      heightCm: 60.96,
    });
    expect(parseSizeCm('5.5 ft long, 4.5 ft wide, 5 ft high')).toBeNull();
    expect(() =>
      assertPackageForVehicle({
        weightKg: 10,
        weightCapacity: '500 kg',
        packageSizeCm: 90,
        sizeLimit: '5.5 ft long, 4.5 ft wide, 5 ft high',
      }),
    ).not.toThrow();
  });

  it('rejects a parcel larger than the vehicle limit and allows an exact fit', () => {
    expect(packageExceedsSize(60, '36cm')).toBe(true);
    expect(packageExceedsSize(36, '36 cm')).toBe(false);
    expect(packageExceedsSize(243.84, '8 ft')).toBe(false);
    expect(packageExceedsSize(243.841, '8 ft')).toBe(true);
    expect(packageExceedsSize(30.48, '12 in')).toBe(false);
    expect(packageExceedsSize(100, '36')).toBe(false);
    expect(() =>
      assertPackageForVehicle({
        weightKg: 5,
        weightCapacity: '20 kg',
        packageSizeCm: 60,
        sizeLimit: '36cm',
      }),
    ).toThrow('Package size exceeds this vehicle limit');
    expect(() =>
      assertPackageForVehicle({
        weightKg: 5,
        weightCapacity: '20 kg',
        packageSizeCm: 36,
        sizeLimit: '36 cm',
      }),
    ).not.toThrow();
  });

  it('requires size when the vehicle has a single explicit size limit', () => {
    expect(() =>
      assertPackageForVehicle({
        weightKg: 5,
        weightCapacity: '20 kg',
        packageSizeCm: null,
        sizeLimit: '36cm',
      }),
    ).toThrow('Package size is required for this vehicle');
  });

  it('does not apply a size limit when the unit is missing', () => {
    expect(() =>
      assertPackageForVehicle({
        weightKg: 5,
        weightCapacity: '20 kg',
        packageSizeCm: null,
        sizeLimit: '36',
      }),
    ).not.toThrow();
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
