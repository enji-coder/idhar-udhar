import {
  assertNonNegativeInr,
  assertPositiveInr,
  assertPositiveKm,
  formatInr,
  formatKm,
} from './money';

describe('money formatting', () => {
  it('pads NUMERIC text to two decimal places without floats', () => {
    expect(formatInr('79')).toBe('79.00');
    expect(formatInr('79.5')).toBe('79.50');
    expect(formatInr('100.00')).toBe('100.00');
    expect(formatInr('0')).toBe('0.00');
  });

  it('rejects non-decimal INR text', () => {
    expect(() => formatInr('79.999')).toThrow(/Invalid INR/);
    expect(() => formatInr('1e2')).toThrow(/Invalid INR/);
    expect(() => formatInr('NaN')).toThrow(/Invalid INR/);
  });

  it('pads distance to three decimal places', () => {
    expect(formatKm('5')).toBe('5.000');
    expect(formatKm('5.5')).toBe('5.500');
    expect(formatKm('5.555')).toBe('5.555');
  });

  it('rejects zero distance', () => {
    expect(() => assertPositiveKm('0')).toThrow(/greater than 0/);
    expect(() => assertPositiveKm('0.000')).toThrow(/greater than 0/);
    expect(assertPositiveKm('0.001')).toBe('0.001');
  });

  it('accepts non-negative INR and rejects zero for positive amounts', () => {
    expect(assertNonNegativeInr('0')).toBe('0.00');
    expect(assertPositiveInr('7.5')).toBe('7.50');
    expect(() => assertPositiveInr('0')).toThrow(/greater than 0/);
    expect(() => assertNonNegativeInr('-1')).toThrow(/negative/);
  });
});
