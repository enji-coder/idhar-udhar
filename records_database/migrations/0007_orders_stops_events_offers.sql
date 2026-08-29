-- Canonical order: UUID PK + unique IU-{CITY}-{10 digits}.
-- related_order FKs from ledgers are attached here.

CREATE TABLE order_display_counters (
  city_id   UUID PRIMARY KEY,
  last_seq  BIGINT NOT NULL DEFAULT 0,
  CONSTRAINT order_display_counters_city_fk FOREIGN KEY (city_id) REFERENCES cities (city_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_display_counters_seq_chk CHECK (last_seq >= 0 AND last_seq <= 9999999999)
);

COMMENT ON TABLE order_display_counters IS
  'Per-city 10-digit allocator. Atomic upsert; not a global sequence bottleneck.';

CREATE OR REPLACE FUNCTION allocate_order_display_id(p_city_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  v_code TEXT;
  v_seq  BIGINT;
BEGIN
  SELECT city_code INTO v_code
  FROM cities
  WHERE city_id = p_city_id;

  IF v_code IS NULL THEN
    RAISE EXCEPTION 'unknown city_id %', p_city_id
      USING ERRCODE = 'foreign_key_violation';
  END IF;

  INSERT INTO order_display_counters (city_id, last_seq)
  VALUES (p_city_id, 1)
  ON CONFLICT (city_id) DO UPDATE
    SET last_seq = order_display_counters.last_seq + 1
  RETURNING last_seq INTO v_seq;

  IF v_seq > 9999999999 THEN
    RAISE EXCEPTION 'display sequence overflow for city %', v_code
      USING ERRCODE = 'numeric_value_out_of_range';
  END IF;

  RETURN 'IU-' || v_code || '-' || lpad(v_seq::text, 10, '0');
END;
$$;

CREATE TABLE orders (
  order_id                        UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  display_id                      TEXT NOT NULL,
  customer_profile_id             UUID NOT NULL,
  rider_profile_id                UUID NULL,
  city_id                         UUID NOT NULL,
  vehicle_category_id             UUID NOT NULL,
  vehicle_category_name_snapshot  TEXT NOT NULL,
  vehicle_id                      UUID NULL,
  canonical_status                TEXT NOT NULL DEFAULT 'CREATED',
  parent_order_id                 UUID NULL,
  scheduled_at                    TIMESTAMPTZ NULL,
  created_at                      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT orders_display_id_unique UNIQUE (display_id),
  CONSTRAINT orders_display_id_format_chk CHECK (display_id ~ '^IU-[A-Z]{2,5}-[0-9]{10}$'),
  CONSTRAINT orders_customer_fk FOREIGN KEY (customer_profile_id) REFERENCES customer_profiles (customer_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT orders_rider_fk FOREIGN KEY (rider_profile_id) REFERENCES rider_profiles (rider_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT orders_city_fk FOREIGN KEY (city_id) REFERENCES cities (city_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT orders_category_fk FOREIGN KEY (vehicle_category_id) REFERENCES vehicle_categories (vehicle_category_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT orders_vehicle_fk FOREIGN KEY (vehicle_id) REFERENCES vehicles (vehicle_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT orders_parent_fk FOREIGN KEY (parent_order_id) REFERENCES orders (order_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT orders_status_chk CHECK (canonical_status IN (
    'CREATED', 'SEARCHING', 'OFFERED', 'ASSIGNED',
    'EN_ROUTE_PICKUP', 'ARRIVED_PICKUP', 'PICKED_UP',
    'IN_TRANSIT', 'NEAR_DROP', 'DELIVERY_ATTEMPT', 'DELIVERED',
    'CANCELLED', 'RECEIVER_UNAVAILABLE', 'FAILED_DELIVERY',
    'PARCEL_AT_COMPANY_OFFICE', 'RESEND_REQUESTED', 'RESEND_IN_PROGRESS', 'RESEND_COMPLETED'
  ))
);

CREATE INDEX orders_customer_created_idx ON orders (customer_profile_id, created_at DESC);
CREATE INDEX orders_customer_status_idx ON orders (customer_profile_id, canonical_status);
CREATE INDEX orders_customer_active_idx ON orders (customer_profile_id, created_at DESC)
  WHERE canonical_status NOT IN ('DELIVERED', 'CANCELLED', 'RESEND_COMPLETED');
CREATE INDEX orders_rider_status_created_idx ON orders (rider_profile_id, canonical_status, created_at DESC);
CREATE INDEX orders_city_status_created_idx ON orders (city_id, canonical_status, created_at DESC);
CREATE INDEX orders_parent_idx ON orders (parent_order_id)
  WHERE parent_order_id IS NOT NULL;

CREATE TRIGGER orders_set_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE orders IS
  'Canonical trip. PK UUID. Human id IU-{CITY}-{10 digits}. No payment_method column as the payment model.';
COMMENT ON COLUMN orders.display_id IS 'Unique human id. Not the PK. Example IU-AMD-0000010421.';
COMMENT ON COLUMN orders.parent_order_id IS 'Optional Case A child-order link. Original fare snapshot is never overwritten.';

CREATE TABLE order_stops (
  order_stop_id   UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  order_id        UUID NOT NULL,
  sequence        INTEGER NOT NULL,
  stop_type       TEXT NOT NULL,
  address_text    TEXT NOT NULL,
  latitude        NUMERIC(9, 6) NOT NULL,
  longitude       NUMERIC(9, 6) NOT NULL,
  zone_id         UUID NULL,
  contact_name    TEXT NULL,
  contact_phone   TEXT NULL,
  arrived_at      TIMESTAMPTZ NULL,
  completed_at    TIMESTAMPTZ NULL,
  proof_file_id   UUID NULL,
  CONSTRAINT order_stops_order_fk FOREIGN KEY (order_id) REFERENCES orders (order_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_stops_zone_fk FOREIGN KEY (zone_id) REFERENCES zones (zone_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_stops_proof_fk FOREIGN KEY (proof_file_id) REFERENCES stored_files (file_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_stops_sequence_unique UNIQUE (order_id, sequence),
  CONSTRAINT order_stops_sequence_chk CHECK (sequence >= 0),
  CONSTRAINT order_stops_type_chk CHECK (stop_type IN ('PICKUP', 'DROP'))
);

CREATE UNIQUE INDEX order_stops_one_pickup
  ON order_stops (order_id)
  WHERE stop_type = 'PICKUP';

CREATE INDEX order_stops_order_idx ON order_stops (order_id);

CREATE TABLE order_status_events (
  order_status_event_id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  order_id              UUID NOT NULL,
  from_status           TEXT NULL,
  to_status             TEXT NOT NULL,
  actor_type            TEXT NOT NULL,
  actor_profile_id      UUID NULL,
  reason                TEXT NULL,
  idempotency_key       TEXT NOT NULL,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT order_status_events_order_fk FOREIGN KEY (order_id) REFERENCES orders (order_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_status_events_idemp_unique UNIQUE (order_id, idempotency_key),
  CONSTRAINT order_status_events_actor_chk CHECK (actor_type IN ('CUSTOMER', 'RIDER', 'ADMIN', 'SYSTEM')),
  CONSTRAINT order_status_events_to_chk CHECK (to_status IN (
    'CREATED', 'SEARCHING', 'OFFERED', 'ASSIGNED',
    'EN_ROUTE_PICKUP', 'ARRIVED_PICKUP', 'PICKED_UP',
    'IN_TRANSIT', 'NEAR_DROP', 'DELIVERY_ATTEMPT', 'DELIVERED',
    'CANCELLED', 'RECEIVER_UNAVAILABLE', 'FAILED_DELIVERY',
    'PARCEL_AT_COMPANY_OFFICE', 'RESEND_REQUESTED', 'RESEND_IN_PROGRESS', 'RESEND_COMPLETED'
  ))
);

CREATE INDEX order_status_events_order_created_idx ON order_status_events (order_id, created_at);

CREATE TABLE order_offers (
  order_offer_id    UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  order_id          UUID NOT NULL,
  rider_profile_id  UUID NOT NULL,
  status            TEXT NOT NULL DEFAULT 'PENDING',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  responded_at      TIMESTAMPTZ NULL,
  CONSTRAINT order_offers_order_fk FOREIGN KEY (order_id) REFERENCES orders (order_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_offers_rider_fk FOREIGN KEY (rider_profile_id) REFERENCES rider_profiles (rider_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_offers_pair_unique UNIQUE (order_id, rider_profile_id),
  CONSTRAINT order_offers_status_chk CHECK (status IN ('PENDING', 'REJECTED', 'EXPIRED', 'ACCEPTED'))
);

CREATE UNIQUE INDEX order_offers_one_accepted
  ON order_offers (order_id)
  WHERE status = 'ACCEPTED';

CREATE INDEX order_offers_order_idx ON order_offers (order_id);
CREATE INDEX order_offers_rider_status_idx ON order_offers (rider_profile_id, status);

ALTER TABLE wallet_ledger_entries
  ADD CONSTRAINT wallet_ledger_order_fk
  FOREIGN KEY (related_order_id) REFERENCES orders (order_id)
  ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE cod_ledger_entries
  ADD CONSTRAINT cod_ledger_order_fk
  FOREIGN KEY (related_order_id) REFERENCES orders (order_id)
  ON DELETE RESTRICT ON UPDATE RESTRICT;
