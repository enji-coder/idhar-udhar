-- Rider earning wallet and COD Due are SEPARATE.
-- Settlement is a COD ledger DECREASE (+ optional wallet CREDIT). No third balance table.

CREATE TABLE rider_wallet_accounts (
  wallet_account_id   UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  rider_profile_id    UUID NOT NULL,
  available_balance   money_inr NOT NULL DEFAULT 0,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT rider_wallet_rider_fk FOREIGN KEY (rider_profile_id) REFERENCES rider_profiles (rider_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT rider_wallet_rider_unique UNIQUE (rider_profile_id),
  CONSTRAINT rider_wallet_nonneg_chk CHECK (available_balance >= 0)
);

CREATE TRIGGER rider_wallet_set_updated_at
  BEFORE UPDATE ON rider_wallet_accounts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE rider_wallet_accounts IS
  'Rider earning wallet materialized balance. NEVER stores COD Due. Never negative. Ledger is source of truth.';

CREATE TABLE rider_cod_accounts (
  cod_account_id      UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  rider_profile_id    UUID NOT NULL,
  cod_due             money_inr NOT NULL DEFAULT 0,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT rider_cod_rider_fk FOREIGN KEY (rider_profile_id) REFERENCES rider_profiles (rider_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT rider_cod_rider_unique UNIQUE (rider_profile_id),
  CONSTRAINT rider_cod_nonneg_chk CHECK (cod_due >= 0)
);

CREATE INDEX rider_cod_due_idx ON rider_cod_accounts (cod_due);

CREATE TRIGGER rider_cod_set_updated_at
  BEFORE UPDATE ON rider_cod_accounts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE rider_cod_accounts IS
  'Money the rider owes the company from cash collections. Separate from wallet. Ledger is truth.';

-- Twin FKs added after both tables exist (DEFERRABLE).
CREATE TABLE wallet_ledger_entries (
  wallet_ledger_id                  UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  wallet_account_id                 UUID NOT NULL,
  direction                         TEXT NOT NULL,
  amount                            money_inr NOT NULL,
  entry_type                        TEXT NOT NULL,
  related_order_id                  UUID NULL,
  related_payment_transaction_id    UUID NULL,
  related_cod_ledger_id             UUID NULL,
  actor_type                        TEXT NOT NULL,
  actor_profile_id                  UUID NULL,
  created_at                        TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT wallet_ledger_account_fk FOREIGN KEY (wallet_account_id) REFERENCES rider_wallet_accounts (wallet_account_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT wallet_ledger_direction_chk CHECK (direction IN ('CREDIT', 'DEBIT')),
  CONSTRAINT wallet_ledger_amount_chk CHECK (amount > 0),
  CONSTRAINT wallet_ledger_type_chk CHECK (entry_type IN (
    'EARNING', 'COD_SETTLEMENT', 'RECHARGE', 'PAYOUT', 'ADJUSTMENT', 'CANCELLATION_SHARE', 'RESEND_EARNING'
  )),
  CONSTRAINT wallet_ledger_actor_chk CHECK (actor_type IN ('CUSTOMER', 'RIDER', 'ADMIN', 'WEBHOOK', 'SYSTEM'))
);

CREATE INDEX wallet_ledger_account_created_idx ON wallet_ledger_entries (wallet_account_id, created_at);

COMMENT ON TABLE wallet_ledger_entries IS 'Append-only source of truth for rider wallet. Cash-trip rider share is NOT posted here.';

CREATE TABLE cod_ledger_entries (
  cod_ledger_id               UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  cod_account_id              UUID NOT NULL,
  direction                   TEXT NOT NULL,
  amount                      money_inr NOT NULL,
  source                      TEXT NOT NULL,
  related_order_id            UUID NULL,
  related_wallet_ledger_id    UUID NULL,
  source_txn_id               TEXT NULL,
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT cod_ledger_account_fk FOREIGN KEY (cod_account_id) REFERENCES rider_cod_accounts (cod_account_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT cod_ledger_direction_chk CHECK (direction IN ('INCREASE', 'DECREASE')),
  CONSTRAINT cod_ledger_amount_chk CHECK (amount > 0),
  CONSTRAINT cod_ledger_source_chk CHECK (source IN (
    'CASH_COMPANY_SHARE',
    'RECHARGE_SETTLEMENT',
    'DIGITAL_EARNING_SETTLEMENT',
    'CANCELLATION_SHARE_SETTLEMENT',
    'ADMIN_ADJUSTMENT'
  ))
);

CREATE UNIQUE INDEX cod_ledger_source_txn_unique
  ON cod_ledger_entries (cod_account_id, source_txn_id)
  WHERE source_txn_id IS NOT NULL;

CREATE INDEX cod_ledger_account_created_idx ON cod_ledger_entries (cod_account_id, created_at);

COMMENT ON TABLE cod_ledger_entries IS
  'Append-only COD increases and settlement decreases. Settlement is these DECREASE rows, not a third table.';

ALTER TABLE wallet_ledger_entries
  ADD CONSTRAINT wallet_ledger_cod_twin_fk
  FOREIGN KEY (related_cod_ledger_id) REFERENCES cod_ledger_entries (cod_ledger_id)
  ON DELETE RESTRICT ON UPDATE RESTRICT
  DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE cod_ledger_entries
  ADD CONSTRAINT cod_ledger_wallet_twin_fk
  FOREIGN KEY (related_wallet_ledger_id) REFERENCES wallet_ledger_entries (wallet_ledger_id)
  ON DELETE RESTRICT ON UPDATE RESTRICT
  DEFERRABLE INITIALLY DEFERRED;
