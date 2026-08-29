import { assertLatitude, assertLongitude, assertLatLng, metersToKm } from './coordinates';

describe('coordinates', () => {
  it('accepts valid latitude and longitude bounds', () => {
    expect(assertLatitude(23.0225)).toBe(23.0225);
    expect(assertLongitude(72.5714)).toBe(72.5714);
    expect(assertLatLng({ latitude: -90, longitude: 180 })).toEqual({
      latitude: -90,
      longitude: 180,
    });
  });

  it('rejects invalid latitude', () => {
    expect(() => assertLatitude(90.0001)).toThrow(/latitude/);
    expect(() => assertLatitude(-90.1)).toThrow(/latitude/);
    expect(() => assertLatitude(Number.NaN)).toThrow(/finite/);
  });

  it('rejects invalid longitude', () => {
    expect(() => assertLongitude(180.0001)).toThrow(/longitude/);
    expect(() => assertLongitude(-180.1)).toThrow(/longitude/);
  });

  it('converts integer meters to km without floats as authority', () => {
    expect(metersToKm(1)).toBe('0.001');
    expect(metersToKm(5000)).toBe('5.000');
    expect(metersToKm(8250)).toBe('8.250');
  });

  it('rejects non-positive meters', () => {
    expect(() => metersToKm(0)).toThrow(/positive integer/);
    expect(() => metersToKm(-3)).toThrow(/positive integer/);
    expect(() => metersToKm(1.5)).toThrow(/positive integer/);
  });
});
