import { inrPaise } from './earning-settlement';
import {
  operationalStatusFor,
  rechargeToResume,
  walletSuspended,
  withdrawalBlocked,
} from './wallet-suspension';

describe('rider wallet suspension floor', () => {
  it('keeps a rider active at -₹99.99 and suspends at -₹100.00 and below', () => {
    expect(walletSuspended('-99.99')).toBe(false);
    expect(operationalStatusFor({
      walletBalance: '-99.99',
      codDue: '0.00',
      codThreshold: '100.00',
    })).toBe('CLEAR');

    expect(walletSuspended('-100.00')).toBe(true);
    expect(operationalStatusFor({
      walletBalance: '-100.00',
      codDue: '0.00',
      codThreshold: '100.00',
    })).toBe('SUSPENDED_FOR_WALLET');

    expect(walletSuspended('-100.01')).toBe(true);
    expect(operationalStatusFor({
      walletBalance: '-108.60',
      codDue: '0.00',
      codThreshold: '100.00',
    })).toBe('SUSPENDED_FOR_WALLET');
  });

  it('restores access only after the balance is greater than -₹100.00', () => {
    expect(rechargeToResume('-100.00')).toBe('0.01');
    const resumed = inrPaise('-100.00') + inrPaise('1.00');
    expect(resumed).toBe(-9900);
    expect(operationalStatusFor({
      walletBalance: '-99.00',
      codDue: '0.00',
      codThreshold: '100.00',
    })).toBe('CLEAR');
    expect(walletSuspended('-100.00')).toBe(true);
  });

  it('blocks withdrawal of a negative balance and still suspends for COD Due', () => {
    expect(withdrawalBlocked('-18.60')).toBe(true);
    expect(withdrawalBlocked('0.00')).toBe(false);
    expect(withdrawalBlocked('31.40')).toBe(false);
    expect(operationalStatusFor({
      walletBalance: '10.00',
      codDue: '100.00',
      codThreshold: '100.00',
    })).toBe('SUSPENDED_FOR_COD');
  });

  it('turns a ₹0.00 wallet into -₹18.60 and -₹90.00 into -₹108.60 for a ₹124.00 cash fare', () => {
    expect(inrPaise('0.00') - inrPaise('18.60')).toBe(inrPaise('-18.60'));
    expect(inrPaise('50.00') - inrPaise('18.60')).toBe(inrPaise('31.40'));
    expect(inrPaise('-90.00') - inrPaise('18.60')).toBe(inrPaise('-108.60'));
    expect(inrPaise('-18.60') + inrPaise('105.40')).toBe(inrPaise('86.80'));
  });
});
