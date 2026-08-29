import { adminLogin, adminLogout, adminProfile, adminSession } from '../api/adminApi';
import { clearTokens, hasRefreshToken } from '../api/client';
import { mapAdminSession } from '../api/mappers';
import { ApiError } from '../api/errors';

const AUTH_FAILURE_CODES = new Set([
  'UNAUTHENTICATED',
  'INVALID_REFRESH_TOKEN',
  'SESSION_REVOKED',
  'SESSION_EXPIRED',
  'INVALID_CREDENTIALS',
]);

function isAuthFailure(error) {
  return error instanceof ApiError && (error.status === 401 || AUTH_FAILURE_CODES.has(error.code));
}

export async function fetchSession() {
  if (!hasRefreshToken()) return null;
  try {
    await adminSession();
    const profile = await adminProfile();
    return mapAdminSession(profile);
  } catch (error) {
    if (isAuthFailure(error)) {
      clearTokens();
      return null;
    }
    throw error;
  }
}

export async function loginRequest({ email, password }) {
  await adminLogin(email, password);
  await adminSession();
  const profile = await adminProfile();
  return mapAdminSession(profile);
}

export async function logoutRequest() {
  try {
    await adminLogout();
  } catch (error) {
    if (!(error instanceof ApiError)) clearTokens();
  }
}
