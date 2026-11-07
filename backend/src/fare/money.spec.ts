import {
  assertNonNegativeInr,
  assertPositiveInr,
  assertPositiveKm,
  customerPayableInr,
  formatInr,
  formatKm,
  percentageShareInr,
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

  it.each([
    ['124.89', '125.00', '0.11'],
    ['124.10', '124.00', '-0.10'],
    ['124.50', '125.00', '0.50'],
    ['125.00', '125.00', '0.00'],
  ])(
    'rounds customer payable %s to %s without changing the trip fare base',
    (tripFare, netPayable, rounding) => {
      expect(customerPayableInr(tripFare)).toEqual({ netPayable, rounding });
      const rider = percentageShareInr(tripFare, 85);
      const companyPaise =
        Number(tripFare.replace('.', '')) - Number(rider.replace('.', ''));
      expect(Number(rider.replace('.', '')) + companyPaise).toBe(
        Number(tripFare.replace('.', '')),
      );
      if (tripFare !== netPayable) {
        expect(rider).not.toBe(percentageShareInr(netPayable, 85));
      }
    },
  );

  it('keeps rider and company shares on the exact trip fare', () => {
    expect(percentageShareInr('173.00', 85)).toBe('147.05');
    expect(percentageShareInr('125.00', 15)).toBe('18.75');
    const payable = customerPayableInr('124.89');
    expect(payable.netPayable).toBe('125.00');
    expect(percentageShareInr('124.89', 85)).toBe('106.16');
    expect(percentageShareInr('124.89', 15)).toBe('18.73');
    expect(percentageShareInr(payable.netPayable, 15)).toBe('18.75');
    expect(percentageShareInr('124.89', 15)).not.toBe('18.75');
  });
});
