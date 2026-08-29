import { createHash } from 'node:crypto';

/**
 * Name-based UUID (v5) so the same logical event always maps to the same
 * notifications.notification_id. The table PK is the architecture's dedupe id;
 * idempotency_keys has no notification scope, so this uses the existing unique PK
 * instead of a schema change.
 */
export const NOTIFICATION_NAMESPACE = '7c2e9a14-6b5d-4f31-8a0e-9d4c1b8f3e27';

export function notificationIdFromEventKey(eventKey: string): string {
  return uuidv5(eventKey, NOTIFICATION_NAMESPACE);
}

export function uuidv5(name: string, namespace: string): string {
  const ns = namespace.replace(/-/g, '');
  const nsBytes = Buffer.from(ns, 'hex');
  const hash = createHash('sha1');
  hash.update(nsBytes);
  hash.update(name, 'utf8');
  const bytes = Buffer.from(hash.digest().subarray(0, 16));
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`;
}
