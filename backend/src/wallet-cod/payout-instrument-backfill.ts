import {
  classifyStoredPayoutInstrument,
  encryptPayoutInstrument,
} from './payout-instrument-crypto';

/**
 * Auditable plan for encrypting legacy payout instruments. This module does
 * not open a database connection and is not a migration.
 *
 * Columns that store the raw instrument:
 * - rider_upis.vpa_encrypted_or_token (current and historical UPI rows)
 * - rider_bank_accounts.account_encrypted_or_token (current and historical bank rows)
 *
 * Do not update rider_wallet_withdrawals. Withdrawals point at those rows by
 * id, and their merchant_transfer_id / provider_transfer_id stay as recorded.
 *
 * Deployment plan, in order:
 * 1. Confirm the target process boots with PAYMENT_PROVIDER=cashfree and a
 *    PAYOUT_INSTRUMENT_KEY that decodes to 32 bytes. Do not put the key in SQL.
 * 2. Read one primary-key page with the select below. The cursor makes a
 *    stopped run resumable.
 * 3. If the value is already enc1:, skip it. If it is legacy plaintext,
 *    encrypt it in the application and update only when the stored value is
 *    still that same legacy value, so a concurrent re-save is not overwritten.
 * 4. Repeat until the select returns no rows. Run it again later; enc1: rows
 *    and lost compare-and-set updates are skipped.
 *
 * Key rotation is a later rewrite, not this backfill. enc1 values have no key
 * id. Add a reader that tries the new key and then the old key, rewrite every
 * enc1 row with the new key, then remove the old key. Do not run that rewrite
 * from this module.
 */

export const PAYOUT_INSTRUMENT_TARGETS = [
  {
    table: 'rider_upis',
    idColumn: 'rider_upi_id',
    valueColumn: 'vpa_encrypted_or_token',
  },
  {
    table: 'rider_bank_accounts',
    idColumn: 'bank_account_id',
    valueColumn: 'account_encrypted_or_token',
  },
] as const;

export type PayoutInstrumentTarget = (typeof PAYOUT_INSTRUMENT_TARGETS)[number];

export function legacyInstrumentPageSql(target: PayoutInstrumentTarget): string {
  return `
SELECT ${target.idColumn} AS id, ${target.valueColumn} AS stored
FROM ${target.table}
WHERE ${target.valueColumn} IS NOT NULL
  AND ${target.valueColumn} NOT LIKE 'enc1:%'
  AND ${target.idColumn} > $1
ORDER BY ${target.idColumn} ASC
LIMIT $2
`;
}

export function legacyInstrumentCompareAndSetSql(
  target: PayoutInstrumentTarget,
): string {
  return `
UPDATE ${target.table}
SET ${target.valueColumn} = $2
WHERE ${target.idColumn} = $1
  AND ${target.valueColumn} = $3
  AND ${target.valueColumn} NOT LIKE 'enc1:%'
`;
}

/**
 * Returns the ciphertext to store, the original value when it is already
 * encrypted, or null when there is nothing to write. Never logs the value.
 */
export function sealLegacyInstrument(
  stored: string | null | undefined,
  key: Buffer,
): string | null {
  const kind = classifyStoredPayoutInstrument(stored);
  if (kind === 'empty') {
    return null;
  }
  if (kind === 'encrypted') {
    return stored ?? null;
  }
  return encryptPayoutInstrument(stored as string, key);
}
