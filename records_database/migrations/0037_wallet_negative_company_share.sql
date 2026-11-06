-- Cash company share is a wallet debit and the balance may be negative.
-- The rider is financially suspended at or below -100.00.
-- Historical ledger rows are not rewritten. COD Due is not changed here.

ALTER TABLE rider_wallet_accounts
  DROP CONSTRAINT IF EXISTS rider_wallet_nonneg_chk;

COMMENT ON TABLE rider_wallet_accounts IS
  'Rider earning wallet. Cash company share is debited here and the balance may be negative. COD Due stays on rider_cod_accounts. Ledger is source of truth.';

COMMENT ON COLUMN rider_profiles.cod_operational_status IS
  'CLEAR, SUSPENDED_FOR_COD when COD Due reaches its policy, or SUSPENDED_FOR_WALLET when the wallet is at or below -100.00.';

ALTER TABLE rider_profiles
  DROP CONSTRAINT IF EXISTS rider_profiles_cod_chk;

ALTER TABLE rider_profiles
  ADD CONSTRAINT rider_profiles_cod_chk CHECK (
    cod_operational_status IN ('CLEAR', 'SUSPENDED_FOR_COD', 'SUSPENDED_FOR_WALLET')
  );

ALTER TABLE wallet_ledger_entries
  DROP CONSTRAINT IF EXISTS wallet_ledger_type_chk;

ALTER TABLE wallet_ledger_entries
  ADD CONSTRAINT wallet_ledger_type_chk CHECK (entry_type IN (
    'EARNING', 'COD_SETTLEMENT', 'RECHARGE', 'PAYOUT', 'ADJUSTMENT',
    'CANCELLATION_SHARE', 'RESEND_EARNING', 'REVERSAL', 'COMPANY_SHARE'
  ));

CREATE UNIQUE INDEX IF NOT EXISTS wallet_company_share_order_unique
  ON wallet_ledger_entries (wallet_account_id, related_order_id)
  WHERE entry_type = 'COMPANY_SHARE' AND related_order_id IS NOT NULL;
