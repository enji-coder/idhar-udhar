import { deriveAggregateStatus } from './payment-status';

describe('deriveAggregateStatus', () => {
  it('is UNPAID when nothing successful has been paid against a bill', () => {
    expect(deriveAggregateStatus('0', '90.00')).toBe('UNPAID');
    expect(deriveAggregateStatus('0.00', '100')).toBe('UNPAID');
  });

  it('is PARTIALLY_PAID when some but not all of the bill is paid', () => {
    expect(deriveAggregateStatus('50.00', '100.00')).toBe('PARTIALLY_PAID');
    expect(deriveAggregateStatus('50', '90')).toBe('PARTIALLY_PAID');
  });

  it('is PAID only when paid equals owed', () => {
    expect(deriveAggregateStatus('90.00', '90')).toBe('PAID');
    expect(deriveAggregateStatus('0', '0')).toBe('PAID');
  });

  it('does not treat overpay as PAID', () => {
    expect(deriveAggregateStatus('110.00', '100.00')).toBe('PARTIALLY_PAID');
  });
});
