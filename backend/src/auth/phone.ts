import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';

export function normalizePhone(raw: string): string {
  const digits = raw.replace(/\D/g, '');
  if (digits.length === 10) {
    return digits;
  }
  if (digits.length === 12 && digits.startsWith('91')) {
    return digits.slice(2);
  }
  if (digits.length === 11 && digits.startsWith('0')) {
    return digits.slice(1);
  }
  throw new ApiError(
    ErrorCodes.VALIDATION_ERROR,
    'Phone number must be a 10-digit or E.164 India number',
    400,
    [{ field: 'phone', message: 'Invalid phone number' }],
  );
}

export function maskPhone(phoneNormalized: string): string {
  if (phoneNormalized.length < 4) {
    return '****';
  }
  return `****${phoneNormalized.slice(-4)}`;
}
