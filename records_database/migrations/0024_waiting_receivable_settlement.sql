-- Pickup waiting rule, one assessment per order, and a customer receivable
-- ledger. Booking responsibility, trip_fare, and 85/15 stay unchanged.
-- Legacy fare_config_version_rates.waiting remains a flat rupee column and
-- is no longer an input to new route fares.

ALTER TABLE fare_config_version_rates
  ADD COLUMN initial_waiting_minutes INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN waiting_charge_per_minute money_inr NOT NULL DEFAULT 0;

ALTER TABLE fare_config_version_rates
  ADD CONSTRAINT fare_rates_waiting_minutes_chk
  CHECK (initial_waiting_minutes >= 0 AND initial_waiting_minutes <= 1440);

ALTER TABLE fare_config_version_rates
  ADD CONSTRAINT fare_rates_waiting_per_minute_chk
  CHECK (waiting_charge_per_minute >= 0);

ALTER TABLE fare_quotes
  ADD COLUMN initial_waiting_minutes INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN waiting_charge_per_minute money_inr NOT NULL DEFAULT 0;

ALTER TABLE fare_quotes
  ADD CONSTRAINT fare_quotes_waiting_minutes_chk
  CHECK (initial_waiting_minutes >= 0 AND initial_waiting_minutes <= 1440);

ALTER TABLE fare_quotes
  ADD CONSTRAINT fare_quotes_waiting_per_minute_chk
  CHECK (waiting_charge_per_minute >= 0);

ALTER TABLE order_fare_snapshots
  ADD COLUMN initial_waiting_minutes INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN waiting_charge_per_minute money_inr NOT NULL DEFAULT 0;

ALTER TABLE order_fare_snapshots
  ADD CONSTRAINT order_fare_snapshots_waiting_minutes_chk
  CHECK (initial_waiting_minutes >= 0 AND initial_waiting_minutes <= 1440);

ALTER TABLE order_fare_snapshots
  ADD CONSTRAINT order_fare_snapshots_waiting_per_minute_chk
  CHECK (waiting_charge_per_minute >= 0);

CREATE TABLE order_waiting_charges (
  order_waiting_charge_id     UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  order_id                    UUID NOT NULL,
  fare_snapshot_id            UUID NOT NULL,
  fare_config_version_id      UUID NOT NULL,
  arrived_event_id            UUID NULL,
  picked_up_event_id          UUID NULL,
  elapsed_minutes             INTEGER NOT NULL,
  initial_waiting_minutes     INTEGER NOT NULL,
  waiting_charge_per_minute   money_inr NOT NULL,
  chargeable_minutes          INTEGER NOT NULL,
  amount                      money_inr NOT NULL,
  settlement_status           TEXT NOT NULL DEFAULT 'OPEN',
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT order_waiting_order_fk FOREIGN KEY (order_id) REFERENCES orders (order_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_waiting_order_unique UNIQUE (order_id),
  CONSTRAINT order_waiting_snapshot_fk FOREIGN KEY (fare_snapshot_id) REFERENCES order_fare_snapshots (fare_snapshot_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_waiting_version_fk FOREIGN KEY (fare_config_version_id) REFERENCES fare_config_versions (fare_config_version_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_waiting_arrived_fk FOREIGN KEY (arrived_event_id) REFERENCES order_status_events (order_status_event_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_waiting_picked_fk FOREIGN KEY (picked_up_event_id) REFERENCES order_status_events (order_status_event_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_waiting_minutes_chk CHECK (
    elapsed_minutes >= 0
    AND initial_waiting_minutes >= 0
    AND initial_waiting_minutes <= 1440
    AND chargeable_minutes >= 0
    AND chargeable_minutes = GREATEST(0, elapsed_minutes - initial_waiting_minutes)
  ),
  CONSTRAINT order_waiting_money_chk CHECK (
    waiting_charge_per_minute >= 0
    AND amount >= 0
    AND amount = ROUND(chargeable_minutes * waiting_charge_per_minute, 2)
  ),
  CONSTRAINT order_waiting_status_chk CHECK (settlement_status IN ('OPEN', 'SETTLED', 'VOID'))
);

CREATE INDEX order_waiting_snapshot_idx ON order_waiting_charges (fare_snapshot_id);

COMMENT ON TABLE order_waiting_charges IS
  'One pickup-wait assessment per order. Amount is not part of trip_fare. OPEN until DELIVERED settlement or VOID on cancel before settlement.';

CREATE TABLE customer_receivable_entries (
  customer_receivable_entry_id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  customer_profile_id          UUID NOT NULL,
  order_id                     UUID NOT NULL,
  order_waiting_charge_id      UUID NOT NULL,
  direction                    TEXT NOT NULL,
  amount                       money_inr NOT NULL,
  entry_type                   TEXT NOT NULL,
  idempotency_key              TEXT NOT NULL,
  created_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT customer_recv_customer_fk FOREIGN KEY (customer_profile_id) REFERENCES customer_profiles (customer_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT customer_recv_order_fk FOREIGN KEY (order_id) REFERENCES orders (order_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT customer_recv_waiting_fk FOREIGN KEY (order_waiting_charge_id) REFERENCES order_waiting_charges (order_waiting_charge_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT customer_recv_direction_chk CHECK (direction IN ('CHARGE', 'CREDIT')),
  CONSTRAINT customer_recv_amount_chk CHECK (amount > 0),
  CONSTRAINT customer_recv_type_chk CHECK (entry_type IN (
    'WAITING_ASSESSMENT', 'WALLET_COLLECTION', 'ONLINE_CLEARANCE'
  )),
  CONSTRAINT customer_recv_idemp_unique UNIQUE (idempotency_key)
);

CREATE UNIQUE INDEX customer_recv_assessment_once
  ON customer_receivable_entries (order_waiting_charge_id)
  WHERE entry_type = 'WAITING_ASSESSMENT';

CREATE UNIQUE INDEX customer_recv_wallet_once
  ON customer_receivable_entries (order_waiting_charge_id)
  WHERE entry_type = 'WALLET_COLLECTION';

CREATE INDEX customer_recv_customer_idx
  ON customer_receivable_entries (customer_profile_id, created_at);

COMMENT ON TABLE customer_receivable_entries IS
  'Append-only customer debt for post-booking charges. Outstanding is SUM(CHARGE) - SUM(CREDIT). Not a rewrite of payment responsibility.';

CREATE TRIGGER customer_receivable_entries_immutable
  BEFORE UPDATE OR DELETE ON customer_receivable_entries
  FOR EACH ROW EXECUTE FUNCTION forbid_update_delete();

ALTER TABLE customer_wallet_ledger_entries
  DROP CONSTRAINT customer_wallet_ledger_type_chk;

ALTER TABLE customer_wallet_ledger_entries
  ADD CONSTRAINT customer_wallet_ledger_type_chk CHECK (entry_type IN (
    'TOP_UP', 'ADJUSTMENT', 'REFUND', 'WAITING_COLLECTION'
  ));

CREATE UNIQUE INDEX customer_wallet_waiting_once
  ON customer_wallet_ledger_entries (customer_wallet_id, related_order_id)
  WHERE entry_type = 'WAITING_COLLECTION' AND related_order_id IS NOT NULL;

ALTER TABLE payment_transactions
  ADD COLUMN charge_purpose TEXT NOT NULL DEFAULT 'BOOKING';

ALTER TABLE payment_transactions
  ADD CONSTRAINT payment_tx_purpose_chk
  CHECK (charge_purpose IN ('BOOKING', 'RECEIVABLE_CLEARANCE'));

COMMENT ON COLUMN payment_transactions.charge_purpose IS
  'BOOKING counts toward responsibility. RECEIVABLE_CLEARANCE collects a post-booking receivable and is excluded from booking paid totals and COD cash.';

CREATE OR REPLACE FUNCTION order_waiting_charges_guard()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'order_waiting_charges cannot be deleted'
      USING ERRCODE = 'restrict_violation';
  END IF;
  IF NEW.order_waiting_charge_id IS DISTINCT FROM OLD.order_waiting_charge_id
     OR NEW.order_id IS DISTINCT FROM OLD.order_id
     OR NEW.fare_snapshot_id IS DISTINCT FROM OLD.fare_snapshot_id
     OR NEW.fare_config_version_id IS DISTINCT FROM OLD.fare_config_version_id
     OR NEW.arrived_event_id IS DISTINCT FROM OLD.arrived_event_id
     OR NEW.picked_up_event_id IS DISTINCT FROM OLD.picked_up_event_id
     OR NEW.elapsed_minutes IS DISTINCT FROM OLD.elapsed_minutes
     OR NEW.initial_waiting_minutes IS DISTINCT FROM OLD.initial_waiting_minutes
     OR NEW.waiting_charge_per_minute IS DISTINCT FROM OLD.waiting_charge_per_minute
     OR NEW.chargeable_minutes IS DISTINCT FROM OLD.chargeable_minutes
     OR NEW.amount IS DISTINCT FROM OLD.amount
     OR NEW.created_at IS DISTINCT FROM OLD.created_at
  THEN
    RAISE EXCEPTION 'order_waiting_charges assessment is immutable'
      USING ERRCODE = 'restrict_violation';
  END IF;
  IF OLD.settlement_status = NEW.settlement_status THEN
    RETURN NEW;
  END IF;
  IF OLD.settlement_status = 'OPEN' AND NEW.settlement_status IN ('SETTLED', 'VOID') THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'illegal waiting settlement status % -> %',
    OLD.settlement_status, NEW.settlement_status
    USING ERRCODE = 'check_violation';
END;
$$;

CREATE TRIGGER order_waiting_charges_guard
  BEFORE UPDATE OR DELETE ON order_waiting_charges
  FOR EACH ROW EXECUTE FUNCTION order_waiting_charges_guard();
