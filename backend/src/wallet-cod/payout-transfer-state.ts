/**
 * Local coordination values stored in rider_wallet_withdrawals.provider_status
 * before Cashfree has a transfer status. They are not provider statuses.
 *
 * IU_TRANSFER_NOT_SENT is written in the same transaction that moves a
 * withdrawal to PROCESSING, before any transfer HTTP call.
 * A worker may POST /transfers only by transitioning that value to
 * IU_TRANSFER_CLAIMED. A later 404 is not proof the transfer was never
 * created once the claim exists, and a null provider_status is legacy
 * ambiguity from before this claim existed.
 *
 * Cashfree's transfer_id is reused for a legitimate first send. This code
 * does not treat that reuse as a guarantee that a second POST is deduplicated.
 */

export const TRANSFER_NOT_SENT = 'IU_TRANSFER_NOT_SENT';
export const TRANSFER_CLAIMED = 'IU_TRANSFER_CLAIMED';

export const CLAIM_PAYOUT_TRANSFER_SQL = `
UPDATE rider_wallet_withdrawals
SET provider_status = '${TRANSFER_CLAIMED}'
WHERE withdrawal_id = $1
  AND status = 'PROCESSING'
  AND provider_transfer_id IS NULL
  AND provider_status = '${TRANSFER_NOT_SENT}'
RETURNING withdrawal_id
`;

export const RELEASE_PAYOUT_TRANSFER_SQL = `
UPDATE rider_wallet_withdrawals
SET provider_status = '${TRANSFER_NOT_SENT}'
WHERE withdrawal_id = $1
  AND status = 'PROCESSING'
  AND provider_transfer_id IS NULL
  AND provider_status = '${TRANSFER_CLAIMED}'
RETURNING withdrawal_id
`;

export function transferConfirmedUnsent(
  providerStatus: string | null,
  providerTransferId: string | null,
): boolean {
  return providerTransferId == null && providerStatus === TRANSFER_NOT_SENT;
}
