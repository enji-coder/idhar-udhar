-- Administrative order purge and wallet reversal.
--
-- Hard delete of an order is still rejected unless the application has set
-- the transaction-local flag app.order_purge = 'on' after proving the order
-- has no protected financial rows. Wallet, COD, payment, invoice, and
-- finance-snapshot rows stay append-only. A mistaken wallet entry is
-- corrected by a new REVERSAL row, never by deleting the original.
--
-- Rollback: dropping the new columns and restoring the previous trigger
-- functions is possible only while no REVERSAL rows and no
-- removed_from_operations_at values exist. Do not drop those columns after
-- administrators have used the feature.

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS removed_from_operations_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS removed_by_identity_id UUID NULL,
  ADD COLUMN IF NOT EXISTS removal_reason TEXT NULL;

ALTER TABLE orders
  DROP CONSTRAINT IF EXISTS orders_removal_reason_chk;

ALTER TABLE orders
  ADD CONSTRAINT orders_removal_reason_chk CHECK (
    removed_from_operations_at IS NULL
    OR (
      removal_reason IS NOT NULL
      AND length(btrim(removal_reason)) >= 8
      AND removed_by_identity_id IS NOT NULL
    )
  );

ALTER TABLE orders
  DROP CONSTRAINT IF EXISTS orders_removed_by_fk;

ALTER TABLE orders
  ADD CONSTRAINT orders_removed_by_fk
  FOREIGN KEY (removed_by_identity_id) REFERENCES identities (identity_id)
  ON DELETE RESTRICT ON UPDATE RESTRICT;

CREATE INDEX IF NOT EXISTS orders_open_operations_idx
  ON orders (created_at DESC)
  WHERE removed_from_operations_at IS NULL;

COMMENT ON COLUMN orders.removed_from_operations_at IS
  'Admin hid this order from the ordinary operations list. Financial rows are kept.';

-- Rider wallet reversal linkage.
ALTER TABLE wallet_ledger_entries
  ADD COLUMN IF NOT EXISTS reverses_wallet_ledger_id UUID NULL,
  ADD COLUMN IF NOT EXISTS reversal_reason TEXT NULL;

ALTER TABLE wallet_ledger_entries
  DROP CONSTRAINT IF EXISTS wallet_ledger_type_chk;

ALTER TABLE wallet_ledger_entries
  ADD CONSTRAINT wallet_ledger_type_chk CHECK (entry_type IN (
    'EARNING', 'COD_SETTLEMENT', 'RECHARGE', 'PAYOUT', 'ADJUSTMENT',
    'CANCELLATION_SHARE', 'RESEND_EARNING', 'REVERSAL'
  ));

ALTER TABLE wallet_ledger_entries
  DROP CONSTRAINT IF EXISTS wallet_ledger_reversal_chk;

ALTER TABLE wallet_ledger_entries
  ADD CONSTRAINT wallet_ledger_reversal_chk CHECK (
    (
      entry_type <> 'REVERSAL'
      AND reverses_wallet_ledger_id IS NULL
    )
    OR (
      entry_type = 'REVERSAL'
      AND reverses_wallet_ledger_id IS NOT NULL
      AND reversal_reason IS NOT NULL
      AND length(btrim(reversal_reason)) >= 8
    )
  );

CREATE UNIQUE INDEX IF NOT EXISTS wallet_ledger_reversal_once
  ON wallet_ledger_entries (reverses_wallet_ledger_id)
  WHERE reverses_wallet_ledger_id IS NOT NULL;

ALTER TABLE wallet_ledger_entries
  DROP CONSTRAINT IF EXISTS wallet_ledger_reverses_fk;

ALTER TABLE wallet_ledger_entries
  ADD CONSTRAINT wallet_ledger_reverses_fk
  FOREIGN KEY (reverses_wallet_ledger_id) REFERENCES wallet_ledger_entries (wallet_ledger_id)
  ON DELETE RESTRICT ON UPDATE RESTRICT;

-- COD reversal linkage. Settlement rows stay; ADMIN_ADJUSTMENT can be reversed.
ALTER TABLE cod_ledger_entries
  ADD COLUMN IF NOT EXISTS reverses_cod_ledger_id UUID NULL,
  ADD COLUMN IF NOT EXISTS reversal_reason TEXT NULL;

ALTER TABLE cod_ledger_entries
  DROP CONSTRAINT IF EXISTS cod_ledger_source_chk;

ALTER TABLE cod_ledger_entries
  ADD CONSTRAINT cod_ledger_source_chk CHECK (source IN (
    'CASH_COMPANY_SHARE',
    'RECHARGE_SETTLEMENT',
    'DIGITAL_EARNING_SETTLEMENT',
    'CANCELLATION_SHARE_SETTLEMENT',
    'ADMIN_ADJUSTMENT',
    'REVERSAL'
  ));

ALTER TABLE cod_ledger_entries
  DROP CONSTRAINT IF EXISTS cod_ledger_reversal_chk;

ALTER TABLE cod_ledger_entries
  ADD CONSTRAINT cod_ledger_reversal_chk CHECK (
    (
      source <> 'REVERSAL'
      AND reverses_cod_ledger_id IS NULL
    )
    OR (
      source = 'REVERSAL'
      AND reverses_cod_ledger_id IS NOT NULL
      AND reversal_reason IS NOT NULL
      AND length(btrim(reversal_reason)) >= 8
    )
  );

CREATE UNIQUE INDEX IF NOT EXISTS cod_ledger_reversal_once
  ON cod_ledger_entries (reverses_cod_ledger_id)
  WHERE reverses_cod_ledger_id IS NOT NULL;

ALTER TABLE cod_ledger_entries
  DROP CONSTRAINT IF EXISTS cod_ledger_reverses_fk;

ALTER TABLE cod_ledger_entries
  ADD CONSTRAINT cod_ledger_reverses_fk
  FOREIGN KEY (reverses_cod_ledger_id) REFERENCES cod_ledger_entries (cod_ledger_id)
  ON DELETE RESTRICT ON UPDATE RESTRICT;

-- Customer wallet reversal linkage.
ALTER TABLE customer_wallet_ledger_entries
  ADD COLUMN IF NOT EXISTS reverses_customer_wallet_ledger_id UUID NULL,
  ADD COLUMN IF NOT EXISTS reversal_reason TEXT NULL;

ALTER TABLE customer_wallet_ledger_entries
  DROP CONSTRAINT IF EXISTS customer_wallet_ledger_type_chk;

ALTER TABLE customer_wallet_ledger_entries
  ADD CONSTRAINT customer_wallet_ledger_type_chk CHECK (entry_type IN (
    'TOP_UP', 'ADJUSTMENT', 'REFUND', 'WAITING_COLLECTION', 'REVERSAL'
  ));

ALTER TABLE customer_wallet_ledger_entries
  DROP CONSTRAINT IF EXISTS customer_wallet_ledger_reversal_chk;

ALTER TABLE customer_wallet_ledger_entries
  ADD CONSTRAINT customer_wallet_ledger_reversal_chk CHECK (
    (
      entry_type <> 'REVERSAL'
      AND reverses_customer_wallet_ledger_id IS NULL
    )
    OR (
      entry_type = 'REVERSAL'
      AND reverses_customer_wallet_ledger_id IS NOT NULL
      AND reversal_reason IS NOT NULL
      AND length(btrim(reversal_reason)) >= 8
    )
  );

CREATE UNIQUE INDEX IF NOT EXISTS customer_wallet_ledger_reversal_once
  ON customer_wallet_ledger_entries (reverses_customer_wallet_ledger_id)
  WHERE reverses_customer_wallet_ledger_id IS NOT NULL;

ALTER TABLE customer_wallet_ledger_entries
  DROP CONSTRAINT IF EXISTS customer_wallet_ledger_reverses_fk;

ALTER TABLE customer_wallet_ledger_entries
  ADD CONSTRAINT customer_wallet_ledger_reverses_fk
  FOREIGN KEY (reverses_customer_wallet_ledger_id)
  REFERENCES customer_wallet_ledger_entries (customer_wallet_ledger_id)
  ON DELETE RESTRICT ON UPDATE RESTRICT;

CREATE OR REPLACE FUNCTION forbid_update_delete()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE'
     AND current_setting('app.order_purge', true) = 'on'
     AND TG_TABLE_NAME IN (
       'order_fare_snapshots',
       'order_status_events',
       'failed_deliveries',
       'order_payment_responsibilities',
       'order_payment_plans'
     )
  THEN
    RETURN OLD;
  END IF;
  RAISE EXCEPTION '% is append-only/immutable and cannot be %', TG_TABLE_NAME, lower(TG_OP)
    USING ERRCODE = 'restrict_violation';
END;
$$;

COMMENT ON FUNCTION forbid_update_delete() IS
  'Financial and history protection. Order purge may delete only the operational tables listed above, and only inside the transaction that set app.order_purge. order_waiting_charges stay out of this list: order_waiting_charges_guard rejects every DELETE, and those rows reference fare snapshots and status events.';

CREATE OR REPLACE FUNCTION forbid_delete()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_TABLE_NAME = 'orders'
     AND current_setting('app.order_purge', true) = 'on'
  THEN
    RETURN OLD;
  END IF;
  RAISE EXCEPTION '% rows cannot be deleted', TG_TABLE_NAME
    USING ERRCODE = 'restrict_violation';
END;
$$;

CREATE OR REPLACE FUNCTION enforce_order_stop_shape()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_order UUID;
  pickup_count INTEGER;
  drop_count INTEGER;
BEGIN
  IF current_setting('app.order_purge', true) = 'on' THEN
    RETURN NULL;
  END IF;
  v_order := COALESCE(NEW.order_id, OLD.order_id);
  IF NOT EXISTS (SELECT 1 FROM orders WHERE order_id = v_order) THEN
    RETURN NULL;
  END IF;
  SELECT
    count(*) FILTER (WHERE stop_type = 'PICKUP'),
    count(*) FILTER (WHERE stop_type = 'DROP')
  INTO pickup_count, drop_count
  FROM order_stops
  WHERE order_id = v_order;

  IF pickup_count <> 1 THEN
    RAISE EXCEPTION 'order % must have exactly 1 PICKUP (found %)', v_order, pickup_count
      USING ERRCODE = 'check_violation';
  END IF;
  IF drop_count < 1 OR drop_count > 3 THEN
    RAISE EXCEPTION 'order % must have 1 to 3 DROP stops (found %)', v_order, drop_count
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NULL;
END;
$$;
