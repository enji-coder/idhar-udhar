import crypto from 'node:crypto';

export const COOKIE_NAME = 'iu_admin';
const MAX_AGE_SECONDS = 60 * 60 * 8;

function expectedEmail() {
  return String(process.env.ADMIN_EMAIL || '').trim().toLowerCase();
}

function expectedPassword() {
  return String(process.env.ADMIN_PASSWORD || '');
}

function signingKey() {
  return expectedPassword();
}

function sha256(value) {
  return crypto.createHash('sha256').update(String(value), 'utf8').digest();
}

export function secretsConfigured() {
  return Boolean(expectedEmail() && expectedPassword());
}

export function credentialsMatch(email, password) {
  if (!secretsConfigured()) return false;
  const emailOk = crypto.timingSafeEqual(sha256(String(email || '').trim().toLowerCase()), sha256(expectedEmail()));
  const passwordOk = crypto.timingSafeEqual(sha256(String(password || '')), sha256(expectedPassword()));
  return emailOk && passwordOk;
}

function b64url(input) {
  return Buffer.from(input).toString('base64url');
}

function sign(payload) {
  return crypto.createHmac('sha256', signingKey()).update(payload).digest('base64url');
}

export function createSessionToken(email) {
  const payload = b64url(JSON.stringify({
    e: String(email).trim().toLowerCase(),
    x: Date.now() + MAX_AGE_SECONDS * 1000,
  }));
  return `${payload}.${sign(payload)}`;
}

export function readSessionToken(token) {
  if (!token || !signingKey()) return null;
  const parts = String(token).split('.');
  if (parts.length !== 2) return null;
  const [payload, signature] = parts;
  const expected = sign(payload);
  const left = Buffer.from(signature);
  const right = Buffer.from(expected);
  if (left.length !== right.length || !crypto.timingSafeEqual(left, right)) return null;
  try {
    const data = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
    if (!data?.e || !data?.x || Date.now() > Number(data.x)) return null;
    if (!sha256(data.e).equals(sha256(expectedEmail()))) return null;
    return { email: data.e };
  } catch {
    return null;
  }
}

export function cookieHeader(token, { secure, clear = false } = {}) {
  const parts = [
    `${COOKIE_NAME}=${clear ? '' : token}`,
    'Path=/',
    'HttpOnly',
    'SameSite=Lax',
  ];
  if (secure) parts.push('Secure');
  if (clear) parts.push('Max-Age=0');
  else parts.push(`Max-Age=${MAX_AGE_SECONDS}`);
  return parts.join('; ');
}

export function isSecureRequest(event) {
  const proto = String(event.headers?.['x-forwarded-proto'] || event.headers?.['X-Forwarded-Proto'] || '').split(',')[0].trim();
  return proto === 'https';
}

export function readCookie(event) {
  const header = event.headers?.cookie || event.headers?.Cookie || '';
  const match = header.split(';').map((part) => part.trim()).find((part) => part.startsWith(`${COOKIE_NAME}=`));
  return match ? match.slice(COOKIE_NAME.length + 1) : '';
}

export function parseJsonBody(event) {
  if (!event.body) return {};
  const raw = event.isBase64Encoded ? Buffer.from(event.body, 'base64').toString('utf8') : event.body;
  try {
    return JSON.parse(raw);
  } catch {
    return {};
  }
}

export function json(statusCode, body, extraHeaders = {}) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
      ...extraHeaders,
    },
    body: JSON.stringify(body),
  };
}
