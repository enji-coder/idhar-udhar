import { createHmac, timingSafeEqual } from 'node:crypto';

const MAX_AGE_MS = 72 * 60 * 60 * 1000;
const MAX_FUTURE_MS = 5 * 60 * 1000;

export type SignatureCheck =
  | { ok: true }
  | { ok: false; reason: 'signature' | 'timestamp' };

/**
 * Cashfree signs `timestamp + rawBody` with HMAC-SHA256, base64.
 * The raw body must be the exact bytes received, not a re-serialized JSON object.
 */
export function verifyCashfreeWebhookSignature(input: {
  secret: string;
  rawBody: string;
  timestamp: string;
  signature: string;
  nowMs?: number;
}): SignatureCheck {
  if (!input.secret || !/^\d+$/.test(input.timestamp) || !input.signature) {
    return { ok: false, reason: 'signature' };
  }
  const timestampMs = Number(input.timestamp);
  if (!Number.isSafeInteger(timestampMs)) {
    return { ok: false, reason: 'timestamp' };
  }
  const now = input.nowMs ?? Date.now();
  if (timestampMs > now + MAX_FUTURE_MS || now - timestampMs > MAX_AGE_MS) {
    return { ok: false, reason: 'timestamp' };
  }
  const expected = createHmac('sha256', input.secret)
    .update(input.timestamp + input.rawBody)
    .digest('base64');
  const left = Buffer.from(expected);
  const right = Buffer.from(input.signature);
  if (left.length !== right.length || !timingSafeEqual(left, right)) {
    return { ok: false, reason: 'signature' };
  }
  return { ok: true };
}
