import { createHmac, timingSafeEqual } from 'node:crypto';

const MAX_AGE_MS = 72 * 60 * 60 * 1000;
const MAX_FUTURE_MS = 5 * 60 * 1000;

export type TimestampRejectionBucket =
  | 'stale'
  | 'future'
  | 'not_integer'
  | 'unsafe_integer';

export type TimestampDigitClass = '10_digit' | '13_digit' | 'other_digit_length';

/**
 * Staging diagnosis only. Never includes the timestamp, signature, or body.
 * `skew_seconds` is omitted unless the header is a safe integer.
 */
export type TimestampRejectionDiagnostic = {
  timestamp_bucket: TimestampRejectionBucket;
  skew_seconds?: number;
  timestamp_digits?: TimestampDigitClass;
};

export type SignatureCheck =
  | { ok: true }
  | {
      ok: false;
      reason: 'signature' | 'timestamp';
      timestampDiagnostic?: TimestampRejectionDiagnostic;
    };

function digitClass(timestamp: string): TimestampDigitClass | undefined {
  if (!/^\d+$/.test(timestamp)) {
    return undefined;
  }
  if (timestamp.length === 10) {
    return '10_digit';
  }
  if (timestamp.length === 13) {
    return '13_digit';
  }
  return 'other_digit_length';
}

function skewSeconds(timestamp: string, nowMs: number): number | undefined {
  if (!/^\d+$/.test(timestamp)) {
    return undefined;
  }
  const value = BigInt(timestamp);
  if (value > BigInt(Number.MAX_SAFE_INTEGER)) {
    return undefined;
  }
  const now = BigInt(nowMs);
  const deltaMs = value > now ? value - now : now - value;
  const seconds = deltaMs / 1000n;
  if (seconds > BigInt(Number.MAX_SAFE_INTEGER)) {
    return undefined;
  }
  return Number(seconds);
}

function timestampDiagnostic(
  bucket: TimestampRejectionBucket,
  timestamp: string,
  nowMs: number,
): TimestampRejectionDiagnostic {
  const diagnostic: TimestampRejectionDiagnostic = { timestamp_bucket: bucket };
  const digits = digitClass(timestamp);
  if (digits) {
    diagnostic.timestamp_digits = digits;
  }
  if (bucket === 'stale' || bucket === 'future') {
    const skew = skewSeconds(timestamp, nowMs);
    if (skew !== undefined) {
      diagnostic.skew_seconds = skew;
    }
  }
  return diagnostic;
}

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
  const now = input.nowMs ?? Date.now();
  const timestamp = input.timestamp ?? '';
  if (!input.secret || !/^\d+$/.test(timestamp) || !input.signature) {
    if (input.secret && input.signature && !/^\d+$/.test(timestamp)) {
      return {
        ok: false,
        reason: 'signature',
        timestampDiagnostic: timestampDiagnostic('not_integer', timestamp, now),
      };
    }
    return { ok: false, reason: 'signature' };
  }
  const timestampMs = Number(timestamp);
  if (!Number.isSafeInteger(timestampMs)) {
    return {
      ok: false,
      reason: 'timestamp',
      timestampDiagnostic: timestampDiagnostic('unsafe_integer', timestamp, now),
    };
  }
  if (timestampMs > now + MAX_FUTURE_MS) {
    return {
      ok: false,
      reason: 'timestamp',
      timestampDiagnostic: timestampDiagnostic('future', timestamp, now),
    };
  }
  if (now - timestampMs > MAX_AGE_MS) {
    return {
      ok: false,
      reason: 'timestamp',
      timestampDiagnostic: timestampDiagnostic('stale', timestamp, now),
    };
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
