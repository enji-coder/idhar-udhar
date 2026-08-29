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
