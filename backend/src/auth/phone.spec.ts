import { normalizePhone } from './phone';

describe('normalizePhone', () => {
  it('accepts a 10-digit number', () => {
    expect(normalizePhone('9876543210')).toBe('9876543210');
  });

  it('strips the 91 country code', () => {
    expect(normalizePhone('+91 98765 43210')).toBe('9876543210');
  });

  it('rejects an unusable value', () => {
    expect(() => normalizePhone('123')).toThrow('Phone number must be');
  });
});
