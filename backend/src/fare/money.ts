/**
 * INR helpers that never use IEEE-754 as the financial authority.
 * PostgreSQL NUMERIC(12,2) / money_inr remains the source of truth.
 * Application code only formats already-rounded NUMERIC text.
 */

const INR_PATTERN = /^-?\d+(?:\.\d{1,2})?$/;
const KM_PATTERN = /^(?:\d+)(?:\.\d{1,3})?$/;

export function formatInr(raw: string): string {
  if (!INR_PATTERN.test(raw)) {
    throw new Error(`Invalid INR numeric text: ${raw}`);
  }
  const negative = raw.startsWith('-');
  const unsigned = negative ? raw.slice(1) : raw;
  const [whole, frac = ''] = unsigned.split('.');
  const padded = `${whole}.${(frac + '00').slice(0, 2)}`;
  return negative ? `-${padded}` : padded;
}

export function formatKm(raw: string): string {
  if (!KM_PATTERN.test(raw)) {
    throw new Error(`Invalid distance numeric text: ${raw}`);
  }
  const [whole, frac = ''] = raw.split('.');
  return `${whole}.${(frac + '000').slice(0, 3)}`;
}

export function assertPositiveKm(raw: string): string {
  const formatted = formatKm(raw);
  const [whole, frac = '000'] = formatted.split('.');
  if (whole === '0' && frac === '000') {
    throw new Error('distance_km must be greater than 0');
  }
  return formatted;
}

export function assertNonNegativeInr(raw: string): string {
  const formatted = formatInr(raw);
  if (formatted.startsWith('-')) {
    throw new Error('amount cannot be negative');
  }
  return formatted;
}

export function assertPositiveInr(raw: string): string {
  const formatted = assertNonNegativeInr(raw);
  if (formatted === '0.00') {
    throw new Error('amount must be greater than 0');
  }
  return formatted;
}

function inrToPaise(formatted: string): number {
  const negative = formatted.startsWith('-');
  const [whole, frac] = (negative ? formatted.slice(1) : formatted).split('.');
  const paise = Number(whole) * 100 + Number(frac);
  if (!Number.isSafeInteger(paise)) {
    throw new Error('INR amount is out of range');
  }
  return negative ? -paise : paise;
}

function paiseToInr(paise: number): string {
  if (!Number.isSafeInteger(paise)) {
    throw new Error('INR amount is out of range');
  }
  const negative = paise < 0;
  const abs = Math.abs(paise);
  const whole = Math.floor(abs / 100);
  const frac = String(abs % 100).padStart(2, '0');
  return negative ? `-${whole}.${frac}` : `${whole}.${frac}`;
}

/**
 * Customer bill for a trip fare. Half-up to the nearest rupee.
 * Matches PostgreSQL ROUND(trip_fare, 0). The difference is the rounding
 * column. It is not added to the rider or company share.
 */
export function customerPayableInr(tripFare: string): {
  netPayable: string;
  rounding: string;
} {
  const formatted = formatInr(tripFare);
  if (formatted.startsWith('-')) {
    throw new Error('trip fare cannot be negative');
  }
  const paise = inrToPaise(formatted);
  const remainder = paise % 100;
  const payablePaise = (Math.floor(paise / 100) + (remainder >= 50 ? 1 : 0)) * 100;
  return {
    netPayable: paiseToInr(payablePaise),
    rounding: paiseToInr(payablePaise - paise),
  };
}

/**
 * Matches PostgreSQL ROUND(amount * percentage / 100, 2) for an integer
 * percentage. The fare SQL applies this to trip_fare, not net_payable.
 */
export function percentageShareInr(amount: string, percentage: number): string {
  if (!Number.isInteger(percentage) || percentage < 0 || percentage > 100) {
    throw new Error('percentage must be an integer from 0 to 100');
  }
  const paise = inrToPaise(formatInr(amount));
  const negative = paise < 0;
  const product = Math.abs(paise) * percentage;
  const quotient = Math.floor(product / 100);
  const remainder = product % 100;
  const rounded = remainder >= 50 ? quotient + 1 : quotient;
  return paiseToInr(negative ? -rounded : rounded);
}
