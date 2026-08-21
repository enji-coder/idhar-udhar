import { cookieHeader, isSecureRequest, json } from './lib/session.js';

export async function handler(event) {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 204, headers: { 'Cache-Control': 'no-store' } };
  }
  if (event.httpMethod !== 'POST') {
    return json(405, { success: false, message: 'Method not allowed.' });
  }

  return json(200, { success: true }, {
    'Set-Cookie': cookieHeader('', { secure: isSecureRequest(event), clear: true }),
  });
}
