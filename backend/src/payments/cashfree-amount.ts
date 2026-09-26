import { formatInr } from '../fare/money';

const INR_TEXT = /^-?\d+(?:\.\d{1,2})?$/;

/**
 * Converts a Cashfree JSON amount into NUMERIC(12,2) text.
 * Rejects values that are not exact to the paise. Does not use the result as a fare.
 */
export function gatewayAmountToInr(value: unknown): string | null {
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!INR_TEXT.test(trimmed)) {
      return null;
    }
    try {
      return formatInr(trimmed);
    } catch {
      return null;
    }
  }
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return null;
  }
  const fixed = value.toFixed(2);
  if (Math.abs(value - Number(fixed)) > 1e-6) {
    return null;
  }
  try {
    return formatInr(fixed);
  } catch {
    return null;
  }
}
