import { authenticateSubAdmin, sessionFromEmail } from './adminUsers';

const FUNCTION_BASE = '/.netlify/functions';

async function readJson(response) {
  try {
    return await response.json();
  } catch {
    return {};
  }
}

export async function fetchSession() {
  const response = await fetch(`${FUNCTION_BASE}/admin-session`, {
    method: 'GET',
    credentials: 'include',
  });
  const data = await readJson(response);
  if (response.ok && data.success) {
    return sessionFromEmail(data.email);
  }
  try {
    const raw = sessionStorage.getItem('iu_admin_local_session');
    if (raw) return JSON.parse(raw);
  } catch {
    /* ignore */
  }
  return null;
}

export async function loginRequest({ email, password }) {
  const local = authenticateSubAdmin(email, password);
  if (local) {
    sessionStorage.setItem('iu_admin_local_session', JSON.stringify(local));
    return local;
  }

  const response = await fetch(`${FUNCTION_BASE}/admin-login`, {
    method: 'POST',
    credentials: 'include',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const data = await readJson(response);
  if (!response.ok || !data.success) {
    const error = new Error(data.message || 'Invalid email or password.');
    error.code = 'INVALID_CREDENTIALS';
    throw error;
  }
  sessionStorage.removeItem('iu_admin_local_session');
  const session = await fetchSession();
  if (!session) {
    return sessionFromEmail(email);
  }
  return session;
}

export async function logoutRequest() {
  sessionStorage.removeItem('iu_admin_local_session');
  await fetch(`${FUNCTION_BASE}/admin-logout`, {
    method: 'POST',
    credentials: 'include',
  });
}
