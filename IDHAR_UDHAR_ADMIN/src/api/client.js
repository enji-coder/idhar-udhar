import { ACCESS_KEY, REFRESH_KEY, apiBaseUrl } from './config';
import { mapApiError } from './errors';

function loopbackFetchOptions() {
  try {
    const host = new URL(apiBaseUrl()).hostname;
    if (
      typeof window !== 'undefined' &&
      window.isSecureContext &&
      (host === 'localhost' || host === '127.0.0.1')
    ) {
      return { targetAddressSpace: 'loopback' };
    }
  } catch {
    /* ignore */
  }
  return {};
}

async function readJson(response) {
  try {
    return await response.json();
  } catch {
    return {};
  }
}

function tokens() {
  return {
    access: sessionStorage.getItem(ACCESS_KEY) || '',
    refresh: sessionStorage.getItem(REFRESH_KEY) || '',
  };
}

export function saveTokens({ access_token, refresh_token }) {
  if (access_token) sessionStorage.setItem(ACCESS_KEY, access_token);
  if (refresh_token) sessionStorage.setItem(REFRESH_KEY, refresh_token);
}

export function clearTokens() {
  sessionStorage.removeItem(ACCESS_KEY);
  sessionStorage.removeItem(REFRESH_KEY);
}

export function hasRefreshToken() {
  return Boolean(sessionStorage.getItem(REFRESH_KEY));
}

let refreshInFlight = null;

async function refreshAccess() {
  const { refresh } = tokens();
  if (!refresh) return null;
  if (refreshInFlight) return refreshInFlight;
  refreshInFlight = (async () => {
    const response = await fetch(`${apiBaseUrl()}/v1/auth/token/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: refresh }),
      ...loopbackFetchOptions(),
    });
    const body = await readJson(response);
    if (!response.ok) {
      clearTokens();
      return null;
    }
    saveTokens(body);
    return body.access_token;
  })().finally(() => {
    refreshInFlight = null;
  });
  return refreshInFlight;
}

export async function apiRequest(path, { method = 'GET', body, headers = {}, skipAuth = false, retry = true } = {}) {
  const { access } = tokens();
  let response;
  try {
    response = await fetch(`${apiBaseUrl()}${path}`, {
      method,
      headers: {
        ...(body != null ? { 'Content-Type': 'application/json' } : {}),
        ...(!skipAuth && access ? { Authorization: `Bearer ${access}` } : {}),
        ...headers,
      },
      body: body != null ? JSON.stringify(body) : undefined,
      ...loopbackFetchOptions(),
    });
  } catch {
    throw mapApiError(
      { error: { code: 'NETWORK_ERROR', message: `Cannot reach the API at ${apiBaseUrl()}.` } },
      0,
    );
  }
  const payload = await readJson(response);
  if (response.status === 401 && retry && !skipAuth && !path.includes('/auth/token/refresh') && !path.includes('/admin/auth/login')) {
    const next = await refreshAccess();
    if (next) {
      return apiRequest(path, { method, body, headers, skipAuth, retry: false });
    }
  }
  if (!response.ok) {
    throw mapApiError(payload, response.status);
  }
  return payload;
}

function filenameFromDisposition(header, fallback) {
  const match = /filename="?([^"]+)"?/i.exec(header || '');
  return match ? match[1] : fallback;
}

/**
 * Same auth and refresh behaviour as apiRequest, for endpoints that stream a
 * file instead of JSON.
 */
export async function apiDownload(path, { fallbackFilename = 'download', retry = true } = {}) {
  const { access } = tokens();
  let response;
  try {
    response = await fetch(`${apiBaseUrl()}${path}`, {
      headers: { ...(access ? { Authorization: `Bearer ${access}` } : {}) },
      ...loopbackFetchOptions(),
    });
  } catch {
    throw mapApiError(
      { error: { code: 'NETWORK_ERROR', message: `Cannot reach the API at ${apiBaseUrl()}.` } },
      0,
    );
  }
  if (response.status === 401 && retry) {
    const next = await refreshAccess();
    if (next) {
      return apiDownload(path, { fallbackFilename, retry: false });
    }
  }
  if (!response.ok) {
    throw mapApiError(await readJson(response), response.status);
  }
  return {
    blob: await response.blob(),
    filename: filenameFromDisposition(
      response.headers.get('Content-Disposition'),
      fallbackFilename,
    ),
  };
}
