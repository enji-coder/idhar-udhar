import { createCipheriv, createDecipheriv, randomBytes } from 'crypto';

const PREFIX = 'enc1:';

/**
 * AES-256-GCM. The key is 32 bytes supplied by configuration, never logged.
 * The prefix has no key id. Rotation requires a reader that accepts the old
 * key and the new key, a rewrite of every enc1 row, then removal of the old
 * key. Do not decrypt with a missing or wrong key by returning the stored
 * bytes as plaintext.
 */

export function classifyStoredPayoutInstrument(
  stored: string | null | undefined,
): 'empty' | 'encrypted' | 'legacy_plaintext' {
  if (stored == null || stored.length === 0) {
    return 'empty';
  }
  if (stored.startsWith(PREFIX)) {
    return 'encrypted';
  }
  return 'legacy_plaintext';
}

export function encryptPayoutInstrument(plaintext: string, key: Buffer): string {
  if (key.length !== 32) {
    throw new Error('Payout instrument key must be 32 bytes');
  }
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const ciphertext = Buffer.concat([
    cipher.update(plaintext, 'utf8'),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();
  return PREFIX + Buffer.concat([iv, tag, ciphertext]).toString('base64');
}

/**
 * Decrypts values written by encryptPayoutInstrument.
 * Legacy plaintext is rejected. Those rows are paid only after the explicit
 * backfill in payout-instrument-backfill.ts. Authentication failure throws
 * and must not be treated as a successful decrypt.
 */
export function decryptPayoutInstrument(stored: string, key: Buffer | null): string {
  if (!stored.startsWith(PREFIX)) {
    throw new Error('Payout instrument is not encrypted');
  }
  if (!key || key.length !== 32) {
    throw new Error('Payout instrument key is required');
  }
  const raw = Buffer.from(stored.slice(PREFIX.length), 'base64');
  const iv = raw.subarray(0, 12);
  const tag = raw.subarray(12, 28);
  const ciphertext = raw.subarray(28);
  const decipher = createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(ciphertext), decipher.final()]).toString('utf8');
}

/** Cashfree beneficiary_name allows letters and spaces only. */
export function cashfreeBeneficiaryName(raw: string | null | undefined): string | null {
  const cleaned = (raw ?? '')
    .replace(/[^A-Za-z\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  if (!/^[A-Za-z][A-Za-z ]{0,99}$/.test(cleaned) || cleaned.length < 2) {
    return null;
  }
  return cleaned;
}

/** Stable merchant id for one destination row. Not a Cashfree registration. */
export function payoutBeneficiaryId(kind: 'UPI' | 'BANK', destinationId: string): string {
  const prefix = kind === 'UPI' ? 'u' : 'b';
  return `${prefix}${destinationId.replace(/-/g, '')}`.slice(0, 50);
}
