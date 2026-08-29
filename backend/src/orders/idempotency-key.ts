import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';

export function readIdempotencyKey(header?: string): string {
  const key = header?.trim() ?? '';
  if (!key) {
    throw new ApiError(
      ErrorCodes.IDEMPOTENCY_KEY_REQUIRED,
      'Idempotency-Key header is required',
      400,
    );
  }
  if (key.length > 128) {
    throw new ApiError(
      ErrorCodes.VALIDATION_ERROR,
      'Idempotency-Key must be 128 characters or fewer',
      400,
    );
  }
  return key;
}
