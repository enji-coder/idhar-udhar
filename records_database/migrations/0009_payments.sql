-- Four payment facts: responsibility, plan, transactions, derived aggregates.
-- No Receiver user table. No orders.payment_method as the model.

CREATE TABLE order_payment_responsibilities (
  payment_responsibility_id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  order_id                  UUID NOT NULL,
  applicable_bill_total     money_inr NOT NULL,
  customer_responsibility   money_inr NOT NULL,
  receiver_responsibility   money_inr NOT NULL,
  who_pays                  TEXT NOT NULL,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT payment_resp_order_fk FOREIGN KEY (order_id) REFERENCES orders (order_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT payment_resp_order_unique UNIQUE (order_id),
  CONSTRAINT payment_resp_nonneg_chk CHECK (
    applicable_bill_total >= 0
    AND customer_responsibility >= 0
    AND receiver_responsibility >= 0
  ),
  CONSTRAINT payment_resp_sum_chk CHECK (
    customer_responsibility + receiver_responsibility = applicable_bill_total
  ),
  CONSTRAINT payment_resp_who_pays_chk CHECK (who_pays IN ('CUSTOMER', 'RECEIVER', 'SPLIT'))
);

COMMENT ON TABLE order_payment_responsibilities IS
  'Who owes the BILL (usually net payable). NOT the 85/15 base. Receiver is a payer type, not a user table.';

CREATE TABLE order_payment_plans (
  payment_plan_id             UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  order_id                    UUID NOT NULL,
  customer_planned_online     money_inr NOT NULL DEFAULT 0,
  customer_planned_cash       money_inr NOT NULL DEFAULT 0,
  receiver_planned_online     money_inr NOT NULL DEFAULT 0,
  receiver_planned_cash       money_inr NOT NULL DEFAULT 0,
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT payment_plan_order_fk FOREIGN KEY (order_id) REFERENCES orders (order_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT payment_plan_order_unique UNIQUE (order_id),
  CONSTRAINT payment_plan_nonneg_chk CHECK (
    customer_planned_online >= 0 AND customer_planned_cash >= 0
    AND receiver_planned_online >= 0 AND receiver_planned_cash >= 0
  )
);

COMMENT ON TABLE order_payment_plans IS 'Intention only. Not PAID. Per-payer planned methods must equal that payer responsibility (enforced by trigger).';

CREATE TABLE payment_transactions (
  payment_transaction_id  UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  order_id                UUID NOT NULL,
  payer_type              TEXT NOT NULL,
  method                  TEXT NOT NULL,
  amount                  money_inr NOT NULL,
  direction               TEXT NOT NULL DEFAULT 'CHARGE',
  transaction_status      TEXT NOT NULL DEFAULT 'PENDING',
  provider_txn_id         TEXT NULL,
  provider_event_id       TEXT NULL,
  idempotency_key         TEXT NOT NULL,
  created_by_type         TEXT NOT NULL,
  created_by_profile_id   UUID NULL,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT payment_tx_order_fk FOREIGN KEY (order_id) REFERENCES orders (order_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT payment_tx_amount_chk CHECK (amount > 0),
  CONSTRAINT payment_tx_payer_chk CHECK (payer_type IN ('CUSTOMER', 'RECEIVER')),
  CONSTRAINT payment_tx_method_chk CHECK (method IN ('ONLINE', 'CASH')),
  CONSTRAINT payment_tx_direction_chk CHECK (direction IN ('CHARGE', 'REFUND')),
  CONSTRAINT payment_tx_status_chk CHECK (transaction_status IN ('PENDING', 'PAID', 'FAILED', 'REFUNDED')),
  CONSTRAINT payment_tx_created_by_chk CHECK (created_by_type IN ('CUSTOMER', 'RIDER', 'ADMIN', 'WEBHOOK', 'SYSTEM')),
  CONSTRAINT payment_tx_idemp_unique UNIQUE (order_id, idempotency_key)
);

CREATE UNIQUE INDEX payment_tx_provider_event_unique
  ON payment_transactions (provider_event_id)
  WHERE provider_event_id IS NOT NULL;

CREATE INDEX payment_tx_order_created_idx ON payment_transactions (order_id, created_at);

CREATE TRIGGER payment_tx_set_updated_at
  BEFORE UPDATE ON payment_transactions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE payment_transactions IS
  'One actual attempt or cash collection. Many per order. Status is PENDING/PAID/FAILED/REFUNDED — never UNPAID/PARTIALLY_PAID/PAID aggregates. No PAN/CVV.';
COMMENT ON COLUMN payment_transactions.transaction_status IS
  'Transaction attempt status. Aggregate UNPAID/PARTIALLY_PAID/PAID is derived from PAID charges minus refunds vs responsibility.';

ALTER TABLE wallet_ledger_entries
  ADD CONSTRAINT wallet_ledger_payment_tx_fk
  FOREIGN KEY (related_payment_transaction_id) REFERENCES payment_transactions (payment_transaction_id)
  ON DELETE RESTRICT ON UPDATE RESTRICT;
