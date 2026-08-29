const DEFAULT_DEV = 'http://localhost:3000';

export function apiBaseUrl() {
  const fromEnv = String(import.meta.env.VITE_API_BASE_URL || '').trim().replace(/\/$/, '');
  if (fromEnv) return fromEnv;
  if (import.meta.env.PROD) {
    throw new Error('VITE_API_BASE_URL must be set for production Admin builds.');
  }
  return DEFAULT_DEV;
}

export const ACCESS_KEY = 'iu_admin_access_token';
export const REFRESH_KEY = 'iu_admin_refresh_token';
