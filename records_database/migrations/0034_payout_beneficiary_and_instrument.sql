-- Cashfree Payouts API 2024-01-01 requires a beneficiary to be created
-- before a transfer. No existing column stores that provider id.
-- verification_status remains the KYC field and is not reused.
-- NULL status means registration has not been confirmed.
-- UNKNOWN means the create call timed out and must be looked up
-- before a transfer is attempted. REGISTERED means Cashfree confirmed
-- the stored beneficiary id.
--
-- Does not drop rider_upis, rider_bank_accounts, rider_wallet_withdrawals,
-- wallet balances, COD balances, or ledger rows. Safe on a clean database
-- and on a database whose payout columns already came from applied 0028/0033.
-- Version 0028 stays unrecovered: this file does not reuse that version.

ALTER TABLE rider_upis
  ADD COLUMN IF NOT EXISTS cashfree_beneficiary_id TEXT NULL,
  ADD COLUMN IF NOT EXISTS cashfree_beneficiary_status TEXT NULL;

ALTER TABLE rider_bank_accounts
  ADD COLUMN IF NOT EXISTS cashfree_beneficiary_id TEXT NULL,
  ADD COLUMN IF NOT EXISTS cashfree_beneficiary_status TEXT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'rider_upis_cf_beneficiary_status_chk'
  ) THEN
    ALTER TABLE rider_upis
      ADD CONSTRAINT rider_upis_cf_beneficiary_status_chk
      CHECK (
        cashfree_beneficiary_status IS NULL
        OR cashfree_beneficiary_status IN ('REGISTERED', 'UNKNOWN')
      );
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'rider_bank_cf_beneficiary_status_chk'
  ) THEN
    ALTER TABLE rider_bank_accounts
      ADD CONSTRAINT rider_bank_cf_beneficiary_status_chk
      CHECK (
        cashfree_beneficiary_status IS NULL
        OR cashfree_beneficiary_status IN ('REGISTERED', 'UNKNOWN')
      );
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS rider_upis_cf_beneficiary_unique
  ON rider_upis (cashfree_beneficiary_id)
  WHERE cashfree_beneficiary_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS rider_bank_cf_beneficiary_unique
  ON rider_bank_accounts (cashfree_beneficiary_id)
  WHERE cashfree_beneficiary_id IS NOT NULL;
