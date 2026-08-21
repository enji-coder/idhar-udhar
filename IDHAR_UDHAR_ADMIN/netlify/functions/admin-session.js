import { json, readCookie, readSessionToken } from './lib/session.js';

export async function handler(event) {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 204, headers: { 'Cache-Control': 'no-store' } };
  }
  if (event.httpMethod !== 'GET' && event.httpMethod !== 'POST') {
    return json(405, { success: false });
  }

  const session = readSessionToken(readCookie(event));
  if (!session) {
    return json(401, { success: false });
  }

  return json(200, { success: true, email: session.email });
}
