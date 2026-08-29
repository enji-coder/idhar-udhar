export class ApiError extends Error {
  constructor({ code, message, requestId, status }) {
    super(message || 'Something went wrong.');
    this.name = 'ApiError';
    this.code = code || 'INTERNAL_ERROR';
    this.requestId = requestId || null;
    this.status = status || 500;
  }
}

const FRIENDLY = {
  NETWORK_ERROR: 'Cannot reach the local API. Confirm NestJS is running on http://localhost:3000.',
  INVALID_CREDENTIALS: 'Invalid email or password.',
  UNAUTHENTICATED: 'Please sign in again.',
  INVALID_REFRESH_TOKEN: 'Please sign in again.',
  SESSION_REVOKED: 'Please sign in again.',
  SESSION_EXPIRED: 'Please sign in again.',
  FORBIDDEN: 'You do not have access to this action.',
  NOT_FOUND: 'The requested record was not found.',
  INVALID_TRANSITION: 'That status change is not allowed yet.',
  ORDER_NOT_MODIFIABLE: 'This order cannot be changed.',
  RIDER_NOT_ELIGIBLE: 'This rider cannot take the order.',
  RIDER_HAS_ACTIVE_ORDER: 'This rider already has an active order.',
  VEHICLE_CATEGORY_IN_USE: 'Cannot delete this vehicle category because it is already used by published fare data or other protected records. Please deactivate it instead.',
  VEHICLE_CATEGORY_NAME_TAKEN: 'This vehicle category already exists.',
  ZONE_NAME_TAKEN: 'This zone already exists.',
  VEHICLE_REGISTRATION_TAKEN: 'A vehicle with this RC number already exists.',
  VEHICLE_IN_USE: 'Cannot delete this vehicle because orders reference it. Please deactivate it instead.',
};

function looksUnsafe(text) {
  return /sql|postgres|relation |column |syntax error/i.test(String(text || ''));
}

export function mapApiError(payload, status) {
  const error = payload?.error || {};
  const code = error.code || 'INTERNAL_ERROR';
  const raw = error.message || '';
  const message = FRIENDLY[code] || (looksUnsafe(raw) ? 'Something went wrong. Try again.' : raw) || 'Something went wrong.';
  return new ApiError({
    code,
    message,
    requestId: error.request_id,
    status,
  });
}
