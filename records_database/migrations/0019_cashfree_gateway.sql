-- Cashfree sandbox gateway facts. Does not change payment_transactions status
-- rules, 85/15 finance snapshots, rider wallet, customer wallet, or COD.
-- payment_transactions stays PENDING/PAID/FAILED/REFUNDED. Gateway ids that
-- arrive after insert live here because provider_txn_id and provider_event_id
-- are immutable on payment_transactions.

CREATE TABLE payment_gateway_attempts (
  payment_gateway_attempt_id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  payment_transaction_id     UUID NOT NULL,
  provider                   TEXT NOT NULL,
  environment                TEXT NOT NULL,
  gateway_order_id           TEXT NOT NULL,
  cf_order_id                TEXT NOT NULL,
  payment_session_id         TEXT NOT NULL,
  gateway_payment_id         TEXT NULL,
  currency                   TEXT NOT NULL DEFAULT 'INR',
  amount                     money_inr NOT NULL,
  gateway_status             TEXT NOT NULL,
  failure_reason             TEXT NULL,
  created_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT pga_tx_fk FOREIGN KEY (payment_transaction_id)
    REFERENCES payment_transactions (payment_transaction_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT pga_tx_unique UNIQUE (payment_transaction_id),
  CONSTRAINT pga_order_unique UNIQUE (provider, gateway_order_id),
  CONSTRAINT pga_provider_chk CHECK (provider IN ('cashfree')),
  CONSTRAINT pga_env_chk CHECK (environment IN ('sandbox', 'production')),
  CONSTRAINT pga_currency_chk CHECK (currency = 'INR'),
  CONSTRAINT pga_amount_chk CHECK (amount > 0),
  CONSTRAINT pga_ids_chk CHECK (
    length(gateway_order_id) BETWEEN 1 AND 50
    AND length(cf_order_id) BETWEEN 1 AND 64
    AND length(payment_session_id) BETWEEN 1 AND 1024
  )
);

CREATE INDEX pga_cf_order_idx ON payment_gateway_attempts (provider, cf_order_id);

CREATE TRIGGER pga_set_updated_at
  BEFORE UPDATE ON payment_gateway_attempts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE payment_gateway_attempts IS
  'One Cashfree order per ONLINE charge. Amount must equal payment_transactions.amount. Session id is a checkout token, not a server secret. Does not post wallet or commission.';

CREATE OR REPLACE FUNCTION payment_gateway_attempts_guard()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'payment_gateway_attempts cannot be deleted'
      USING ERRCODE = 'restrict_violation';
  END IF;
  IF TG_OP = 'INSERT' THEN
    IF NOT EXISTS (
      SELECT 1
      FROM payment_transactions t
      WHERE t.payment_transaction_id = NEW.payment_transaction_id
        AND t.amount = NEW.amount
        AND t.method = 'ONLINE'
        AND t.direction = 'CHARGE'
    ) THEN
      RAISE EXCEPTION 'gateway attempt must match the online charge amount'
        USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
  END IF;
  IF NEW.payment_gateway_attempt_id IS DISTINCT FROM OLD.payment_gateway_attempt_id
     OR NEW.payment_transaction_id IS DISTINCT FROM OLD.payment_transaction_id
     OR NEW.provider IS DISTINCT FROM OLD.provider
     OR NEW.environment IS DISTINCT FROM OLD.environment
     OR NEW.gateway_order_id IS DISTINCT FROM OLD.gateway_order_id
     OR NEW.cf_order_id IS DISTINCT FROM OLD.cf_order_id
     OR NEW.payment_session_id IS DISTINCT FROM OLD.payment_session_id
     OR NEW.currency IS DISTINCT FROM OLD.currency
     OR NEW.amount IS DISTINCT FROM OLD.amount
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
  THEN
    RAISE EXCEPTION 'payment_gateway_attempts identity columns are immutable'
      USING ERRCODE = 'restrict_violation';
  END IF;
  IF OLD.gateway_payment_id IS NOT NULL
     AND NEW.gateway_payment_id IS DISTINCT FROM OLD.gateway_payment_id
  THEN
    RAISE EXCEPTION 'gateway_payment_id cannot be replaced'
      USING ERRCODE = 'restrict_violation';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER payment_gateway_attempts_guard
  BEFORE INSERT OR UPDATE OR DELETE ON payment_gateway_attempts
  FOR EACH ROW EXECUTE FUNCTION payment_gateway_attempts_guard();

CREATE TABLE payment_webhook_events (
  payment_webhook_event_id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  provider                 TEXT NOT NULL,
  event_id                 TEXT NOT NULL,
  event_type               TEXT NOT NULL,
  payload_sha256           TEXT NOT NULL,
  payment_transaction_id   UUID NULL,
  processing_result        TEXT NOT NULL,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT pwe_provider_chk CHECK (provider IN ('cashfree')),
  CONSTRAINT pwe_event_unique UNIQUE (provider, event_id),
  CONSTRAINT pwe_result_chk CHECK (processing_result IN ('RECEIVED', 'APPLIED', 'IGNORED', 'REJECTED')),
  CONSTRAINT pwe_tx_fk FOREIGN KEY (payment_transaction_id)
    REFERENCES payment_transactions (payment_transaction_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
);

CREATE INDEX pwe_tx_idx ON payment_webhook_events (payment_transaction_id);

CREATE TRIGGER pwe_set_updated_at
  BEFORE UPDATE ON payment_webhook_events
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER payment_webhook_events_no_delete
  BEFORE DELETE ON payment_webhook_events
  FOR EACH ROW EXECUTE FUNCTION forbid_delete();

COMMENT ON TABLE payment_webhook_events IS
  'Append-only Cashfree webhook receipt. event_id is unique so a replay cannot post twice. Payload bytes are not stored.';

CREATE OR REPLACE FUNCTION payment_webhook_events_guard()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.payment_webhook_event_id IS DISTINCT FROM OLD.payment_webhook_event_id
     OR NEW.provider IS DISTINCT FROM OLD.provider
     OR NEW.event_id IS DISTINCT FROM OLD.event_id
     OR NEW.event_type IS DISTINCT FROM OLD.event_type
     OR NEW.payload_sha256 IS DISTINCT FROM OLD.payload_sha256
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
  THEN
    RAISE EXCEPTION 'payment_webhook_events identity columns are immutable'
      USING ERRCODE = 'restrict_violation';
  END IF;
  IF OLD.payment_transaction_id IS NOT NULL
     AND NEW.payment_transaction_id IS DISTINCT FROM OLD.payment_transaction_id
  THEN
    RAISE EXCEPTION 'payment_webhook_events transaction link cannot be replaced'
      USING ERRCODE = 'restrict_violation';
  END IF;
  IF OLD.processing_result IS NOT DISTINCT FROM NEW.processing_result THEN
    RETURN NEW;
  END IF;
  IF OLD.processing_result = 'RECEIVED'
     AND NEW.processing_result IN ('APPLIED', 'IGNORED', 'REJECTED')
  THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'illegal payment webhook processing_result transition % -> %',
    OLD.processing_result, NEW.processing_result
    USING ERRCODE = 'check_violation';
END;
$$;

CREATE TRIGGER payment_webhook_events_guard
  BEFORE UPDATE ON payment_webhook_events
  FOR EACH ROW EXECUTE FUNCTION payment_webhook_events_guard();

CREATE TABLE payment_gateway_refunds (
  payment_gateway_refund_id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  payment_transaction_id    UUID NOT NULL,
  refund_transaction_id     UUID NULL,
  provider                  TEXT NOT NULL,
  merchant_refund_id        TEXT NOT NULL,
  cf_refund_id              TEXT NULL,
  amount                    money_inr NOT NULL,
  currency                  TEXT NOT NULL DEFAULT 'INR',
  refund_status             TEXT NOT NULL,
  failure_reason            TEXT NULL,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT pgr_charge_fk FOREIGN KEY (payment_transaction_id)
    REFERENCES payment_transactions (payment_transaction_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT pgr_refund_tx_fk FOREIGN KEY (refund_transaction_id)
    REFERENCES payment_transactions (payment_transaction_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT pgr_merchant_unique UNIQUE (provider, merchant_refund_id),
  CONSTRAINT pgr_provider_chk CHECK (provider IN ('cashfree')),
  CONSTRAINT pgr_currency_chk CHECK (currency = 'INR'),
  CONSTRAINT pgr_amount_chk CHECK (amount > 0),
  CONSTRAINT pgr_status_chk CHECK (refund_status IN ('INITIATED', 'PENDING', 'SUCCESS', 'FAILED'))
);

CREATE INDEX pgr_charge_idx ON payment_gateway_refunds (payment_transaction_id);

CREATE TRIGGER pgr_set_updated_at
  BEFORE UPDATE ON payment_gateway_refunds
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER payment_gateway_refunds_no_delete
  BEFORE DELETE ON payment_gateway_refunds
  FOR EACH ROW EXECUTE FUNCTION forbid_delete();

COMMENT ON TABLE payment_gateway_refunds IS
  'Standard Cashfree refund (not instant). A payment_transactions REFUND/REFUNDED row is inserted only after Cashfree reports SUCCESS. Does not change 85/15.';

CREATE OR REPLACE FUNCTION payment_gateway_refunds_guard()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  charge_amount money_inr;
  other_open money_inr;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.payment_gateway_refund_id IS DISTINCT FROM OLD.payment_gateway_refund_id
       OR NEW.payment_transaction_id IS DISTINCT FROM OLD.payment_transaction_id
       OR NEW.provider IS DISTINCT FROM OLD.provider
       OR NEW.merchant_refund_id IS DISTINCT FROM OLD.merchant_refund_id
       OR NEW.amount IS DISTINCT FROM OLD.amount
       OR NEW.currency IS DISTINCT FROM OLD.currency
       OR NEW.created_at IS DISTINCT FROM OLD.created_at
    THEN
      RAISE EXCEPTION 'payment_gateway_refunds identity columns are immutable'
        USING ERRCODE = 'restrict_violation';
    END IF;
    IF OLD.cf_refund_id IS NOT NULL AND NEW.cf_refund_id IS DISTINCT FROM OLD.cf_refund_id THEN
      RAISE EXCEPTION 'cf_refund_id cannot be replaced'
        USING ERRCODE = 'restrict_violation';
    END IF;
    IF OLD.refund_transaction_id IS NOT NULL
       AND NEW.refund_transaction_id IS DISTINCT FROM OLD.refund_transaction_id
    THEN
      RAISE EXCEPTION 'refund_transaction_id cannot be replaced'
        USING ERRCODE = 'restrict_violation';
    END IF;
    IF OLD.refund_status IS DISTINCT FROM NEW.refund_status
       AND NOT (
         (OLD.refund_status = 'INITIATED' AND NEW.refund_status IN ('PENDING', 'SUCCESS', 'FAILED'))
         OR (OLD.refund_status = 'PENDING' AND NEW.refund_status IN ('SUCCESS', 'FAILED'))
       )
    THEN
      RAISE EXCEPTION 'illegal payment gateway refund_status transition % -> %',
        OLD.refund_status, NEW.refund_status
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  PERFORM 1
  FROM payment_transactions
  WHERE payment_transaction_id = NEW.payment_transaction_id
  FOR UPDATE;

  IF NEW.refund_status <> 'FAILED' THEN
    SELECT t.amount
    INTO charge_amount
    FROM payment_transactions t
    WHERE t.payment_transaction_id = NEW.payment_transaction_id
      AND t.method = 'ONLINE'
      AND t.direction = 'CHARGE'
      AND t.transaction_status = 'PAID';
    IF charge_amount IS NULL THEN
      RAISE EXCEPTION 'gateway refund requires a paid online charge'
        USING ERRCODE = 'check_violation';
    END IF;
    SELECT COALESCE(SUM(r.amount), 0)
    INTO other_open
    FROM payment_gateway_refunds r
    WHERE r.payment_transaction_id = NEW.payment_transaction_id
      AND r.refund_status <> 'FAILED'
      AND r.payment_gateway_refund_id IS DISTINCT FROM NEW.payment_gateway_refund_id;
    IF other_open + NEW.amount > charge_amount THEN
      RAISE EXCEPTION 'gateway refund exceeds the captured online payment'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER payment_gateway_refunds_guard
  BEFORE INSERT OR UPDATE ON payment_gateway_refunds
  FOR EACH ROW EXECUTE FUNCTION payment_gateway_refunds_guard();
