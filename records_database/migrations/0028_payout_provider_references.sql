-- Payout provider references and single-refund audit for rider withdrawals.

ALTER TABLE rider_wallet_withdrawals
  ADD COLUMN IF NOT EXISTS merchant_transfer_id TEXT NULL,
  ADD COLUMN IF NOT EXISTS provider_status TEXT NULL,
  ADD COLUMN IF NOT EXISTS refund_wallet_ledger_id UUID NULL,
  ADD COLUMN IF NOT EXISTS last_reconciled_at TIMESTAMPTZ NULL;

ALTER TABLE rider_wallet_withdrawals
  DROP CONSTRAINT IF EXISTS rww_refund_ledger_fk;

ALTER TABLE rider_wallet_withdrawals
  ADD CONSTRAINT rww_refund_ledger_fk FOREIGN KEY (refund_wallet_ledger_id)
    REFERENCES wallet_ledger_entries (wallet_ledger_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT;

CREATE UNIQUE INDEX IF NOT EXISTS rww_merchant_transfer_unique
  ON rider_wallet_withdrawals (merchant_transfer_id)
  WHERE merchant_transfer_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS rww_provider_transfer_unique
  ON rider_wallet_withdrawals (provider_transfer_id)
  WHERE provider_transfer_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS rww_refund_ledger_unique
  ON rider_wallet_withdrawals (refund_wallet_ledger_id)
  WHERE refund_wallet_ledger_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS rww_processing_reconcile_idx
  ON rider_wallet_withdrawals (status, updated_at)
  WHERE status = 'PROCESSING';

COMMENT ON COLUMN rider_wallet_withdrawals.merchant_transfer_id IS
  'Merchant transfer_id sent to Cashfree Payouts; set before the provider call for timeout-safe reconciliation.';

COMMENT ON COLUMN rider_wallet_withdrawals.provider_status IS
  'Last authoritative provider status string (e.g. SUCCESS, FAILED, PENDING).';

COMMENT ON COLUMN rider_wallet_withdrawals.refund_wallet_ledger_id IS
  'Ledger credit that restored funds after FAILED/REJECTED/REVERSED. At most one refund per withdrawal.';
