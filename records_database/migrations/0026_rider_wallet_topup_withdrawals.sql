-- Rider wallet top-up via Cashfree (no order) and withdrawal requests.
-- Rider contact email remains on identities.email (via rider_profiles.identity_id).

ALTER TABLE payment_transactions
  DROP CONSTRAINT payment_tx_purpose_chk;

ALTER TABLE payment_transactions
  DROP CONSTRAINT payment_tx_payer_chk;

ALTER TABLE payment_transactions
  ALTER COLUMN order_id DROP NOT NULL;

ALTER TABLE payment_transactions
  ADD COLUMN rider_profile_id UUID NULL,
  ADD CONSTRAINT payment_tx_rider_fk FOREIGN KEY (rider_profile_id)
    REFERENCES rider_profiles (rider_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE payment_transactions
  ADD CONSTRAINT payment_tx_purpose_chk
  CHECK (charge_purpose IN ('BOOKING', 'RECEIVABLE_CLEARANCE', 'WALLET_TOPUP'));

ALTER TABLE payment_transactions
  ADD CONSTRAINT payment_tx_payer_chk
  CHECK (payer_type IN ('CUSTOMER', 'RECEIVER', 'RIDER'));

ALTER TABLE payment_transactions
  ADD CONSTRAINT payment_tx_wallet_topup_shape_chk
  CHECK (
    (
      charge_purpose = 'WALLET_TOPUP'
      AND rider_profile_id IS NOT NULL
      AND order_id IS NULL
    )
    OR (
      charge_purpose <> 'WALLET_TOPUP'
      AND order_id IS NOT NULL
    )
  );

ALTER TABLE payment_transactions
  DROP CONSTRAINT payment_tx_idemp_unique;

CREATE UNIQUE INDEX payment_tx_order_idemp_unique
  ON payment_transactions (order_id, idempotency_key)
  WHERE order_id IS NOT NULL;

CREATE UNIQUE INDEX payment_tx_wallet_topup_idemp_unique
  ON payment_transactions (rider_profile_id, idempotency_key)
  WHERE charge_purpose = 'WALLET_TOPUP';

CREATE UNIQUE INDEX wallet_ledger_payment_tx_unique
  ON wallet_ledger_entries (related_payment_transaction_id)
  WHERE related_payment_transaction_id IS NOT NULL;

COMMENT ON COLUMN payment_transactions.rider_profile_id IS
  'Required for WALLET_TOPUP (order_id NULL). Email for Cashfree customer metadata uses identities.email through rider_profiles.identity_id.';

CREATE TABLE rider_wallet_withdrawals (
  withdrawal_id                 UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  rider_profile_id              UUID NOT NULL,
  amount                        money_inr NOT NULL,
  status                        TEXT NOT NULL,
  payout_method                 TEXT NOT NULL,
  rider_upi_id                  UUID NULL,
  bank_account_id               UUID NULL,
  wallet_ledger_id              UUID NULL,
  provider_transfer_id          TEXT NULL,
  failure_reason                TEXT NULL,
  requested_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at                  TIMESTAMPTZ NULL,
  decided_by_admin_profile_id   UUID NULL,
  created_at                    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT rww_rider_fk FOREIGN KEY (rider_profile_id)
    REFERENCES rider_profiles (rider_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT rww_upi_fk FOREIGN KEY (rider_upi_id)
    REFERENCES rider_upis (rider_upi_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT rww_bank_fk FOREIGN KEY (bank_account_id)
    REFERENCES rider_bank_accounts (bank_account_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT rww_wallet_ledger_fk FOREIGN KEY (wallet_ledger_id)
    REFERENCES wallet_ledger_entries (wallet_ledger_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT rww_admin_fk FOREIGN KEY (decided_by_admin_profile_id)
    REFERENCES admin_profiles (admin_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT rww_amount_chk CHECK (amount > 0),
  CONSTRAINT rww_status_chk CHECK (status IN (
    'REQUESTED', 'PENDING', 'PROCESSING', 'SUCCESSFUL', 'FAILED', 'REJECTED', 'CANCELLED'
  )),
  CONSTRAINT rww_payout_method_chk CHECK (payout_method IN ('UPI', 'BANK')),
  CONSTRAINT rww_destination_chk CHECK (
    (payout_method = 'UPI' AND rider_upi_id IS NOT NULL AND bank_account_id IS NULL)
    OR (payout_method = 'BANK' AND bank_account_id IS NOT NULL AND rider_upi_id IS NULL)
  )
);

CREATE INDEX rww_rider_status_idx ON rider_wallet_withdrawals (rider_profile_id, status);

CREATE TRIGGER rww_set_updated_at
  BEFORE UPDATE ON rider_wallet_withdrawals
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE rider_wallet_withdrawals IS
  'Rider-initiated payout requests. SUCCESSFUL requires an external transfer; admin marks processing/reject.';

ALTER TABLE rider_profiles
  ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ NULL;

CREATE INDEX IF NOT EXISTS rider_profiles_online_last_seen_idx
  ON rider_profiles (online_status, last_seen_at)
  WHERE online_status = 'ONLINE';

COMMENT ON COLUMN rider_profiles.last_seen_at IS
  'Last confirmed presence while ONLINE (availability toggle or location ping). Email remains on identities.email.';
