-- ARCHITECTURE READY — not V1 booking, not auto-debit, not rider wallet.
-- Isolated: no FK from orders or payment_transactions.

CREATE TABLE customer_wallet_accounts (
  customer_wallet_id    UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  customer_profile_id   UUID NOT NULL,
  available_balance     money_inr NOT NULL DEFAULT 0,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT customer_wallet_customer_fk FOREIGN KEY (customer_profile_id) REFERENCES customer_profiles (customer_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT customer_wallet_customer_unique UNIQUE (customer_profile_id),
  CONSTRAINT customer_wallet_nonneg_chk CHECK (available_balance >= 0)
);

CREATE TRIGGER customer_wallet_set_updated_at
  BEFORE UPDATE ON customer_wallet_accounts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE customer_wallet_accounts IS
  'ARCHITECTURE READY. Not required for V1 booking. Dummy promo amounts are not defaults. Do not auto-debit.';

CREATE TABLE customer_wallet_ledger_entries (
  customer_wallet_ledger_id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  customer_wallet_id        UUID NOT NULL,
  direction                 TEXT NOT NULL,
  amount                    money_inr NOT NULL,
  entry_type                TEXT NOT NULL,
  related_order_id          UUID NULL,
  actor_type                TEXT NOT NULL,
  actor_profile_id          UUID NULL,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT customer_wallet_ledger_account_fk FOREIGN KEY (customer_wallet_id) REFERENCES customer_wallet_accounts (customer_wallet_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT customer_wallet_ledger_order_fk FOREIGN KEY (related_order_id) REFERENCES orders (order_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT customer_wallet_ledger_direction_chk CHECK (direction IN ('CREDIT', 'DEBIT')),
  CONSTRAINT customer_wallet_ledger_amount_chk CHECK (amount > 0),
  CONSTRAINT customer_wallet_ledger_type_chk CHECK (entry_type IN (
    'TOP_UP', 'ADJUSTMENT', 'REFUND'
  )),
  CONSTRAINT customer_wallet_ledger_actor_chk CHECK (actor_type IN ('CUSTOMER', 'ADMIN', 'WEBHOOK', 'SYSTEM'))
);

CREATE INDEX customer_wallet_ledger_account_created_idx
  ON customer_wallet_ledger_entries (customer_wallet_id, created_at);

COMMENT ON TABLE customer_wallet_ledger_entries IS
  'ARCHITECTURE READY companion ledger. Isolated from rider wallet/COD and from V1 payment method ONLINE/CASH.';
