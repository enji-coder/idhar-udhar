import { cookieHeader, credentialsMatch, createSessionToken, isSecureRequest, json, parseJsonBody, secretsConfigured } from './lib/session.js';

export async function handler(event) {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 204, headers: { 'Cache-Control': 'no-store' } };
  }
  if (event.httpMethod !== 'POST') {
    return json(405, { success: false, message: 'Invalid email or password.' });
  }

  const { email, password } = parseJsonBody(event);
  if (!secretsConfigured() || !credentialsMatch(email, password)) {
    return json(401, { success: false, message: 'Invalid email or password.' });
  }

  const token = createSessionToken(email);
  return json(200, { success: true }, {
    'Set-Cookie': cookieHeader(token, { secure: isSecureRequest(event) }),
  });
}
