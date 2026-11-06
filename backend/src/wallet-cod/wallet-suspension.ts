import { inrPaise } from './earning-settlement';

/**
 * One suspension floor for the rider earning wallet.
 * Service stops when the balance is at or below this amount.
 * A greater balance restores access. COD Due uses its own policy.
 */
export const WALLET_SUSPEND_FLOOR = '-100.00';

export type RiderMoneyStatus = 'CLEAR' | 'SUSPENDED_FOR_COD' | 'SUSPENDED_FOR_WALLET';

export function walletSuspended(
  balance: string,
  floor: string = WALLET_SUSPEND_FLOOR,
): boolean {
  return inrPaise(balance) <= inrPaise(floor);
}

export function withdrawalBlocked(balance: string): boolean {
  return inrPaise(balance) < 0;
}

/** Smallest positive recharge that makes the balance greater than the floor. */
export function rechargeToResume(
  balance: string,
  floor: string = WALLET_SUSPEND_FLOOR,
): string {
  const gap = inrPaise(floor) - inrPaise(balance);
  if (gap < 0) {
    return '0.00';
  }
  return paiseToInr(gap + 1);
}

export function operationalStatusFor(input: {
  walletBalance: string;
  codDue: string;
  codThreshold: string;
  floor?: string;
}): RiderMoneyStatus {
  if (walletSuspended(input.walletBalance, input.floor ?? WALLET_SUSPEND_FLOOR)) {
    return 'SUSPENDED_FOR_WALLET';
  }
  if (inrPaise(input.codDue) >= inrPaise(input.codThreshold)) {
    return 'SUSPENDED_FOR_COD';
  }
  return 'CLEAR';
}

export function paiseToInr(paise: number): string {
  if (!Number.isSafeInteger(paise)) {
    throw new Error('INR paise is out of range');
  }
  const negative = paise < 0;
  const abs = Math.abs(paise);
  const whole = Math.floor(abs / 100);
  const frac = String(abs % 100).padStart(2, '0');
  const text = `${whole}.${frac}`;
  return negative ? `-${text}` : text;
}
