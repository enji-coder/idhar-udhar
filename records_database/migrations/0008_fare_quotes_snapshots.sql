-- Fare quote + immutable fare snapshot.
-- 85/15 base is trip_fare, NOT net_payable. GST on fare = 0.

CREATE TABLE fare_quotes (
  fare_quote_id             UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  customer_profile_id       UUID NOT NULL,
  fare_config_version_id    UUID NOT NULL,
  vehicle_category_id       UUID NOT NULL,
  distance_km               NUMERIC(10, 3) NOT NULL,
  stop_count                INTEGER NOT NULL,
  base_fare                 money_inr NOT NULL,
  per_km                    money_inr NOT NULL,
  distance_charge           money_inr NOT NULL,
  initial_minimum           money_inr NOT NULL,
  waiting                   money_inr NOT NULL,
  surge                     money_inr NOT NULL,
  toll                      money_inr NOT NULL,
  parking                   money_inr NOT NULL,
  trip_fare                 money_inr NOT NULL,
  discount                  money_inr NOT NULL DEFAULT 0,
  rounding                  money_inr NOT NULL DEFAULT 0,
  net_payable               money_inr NOT NULL,
  tax                       money_inr NOT NULL DEFAULT 0,
  expires_at                TIMESTAMPTZ NOT NULL,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fare_quotes_customer_fk FOREIGN KEY (customer_profile_id) REFERENCES customer_profiles (customer_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fare_quotes_version_fk FOREIGN KEY (fare_config_version_id) REFERENCES fare_config_versions (fare_config_version_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fare_quotes_category_fk FOREIGN KEY (vehicle_category_id) REFERENCES vehicle_categories (vehicle_category_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fare_quotes_distance_chk CHECK (distance_km > 0),
  CONSTRAINT fare_quotes_stop_count_chk CHECK (stop_count BETWEEN 2 AND 4),
  CONSTRAINT fare_quotes_nonneg_chk CHECK (
    base_fare >= 0 AND per_km >= 0 AND distance_charge >= 0 AND initial_minimum >= 0
    AND waiting >= 0 AND surge >= 0 AND toll >= 0 AND parking >= 0
    AND trip_fare >= 0 AND discount >= 0 AND net_payable >= 0
  ),
  CONSTRAINT fare_quotes_tax_zero_chk CHECK (tax = 0)
);

CREATE INDEX fare_quotes_customer_created_idx ON fare_quotes (customer_profile_id, created_at DESC);

COMMENT ON COLUMN fare_quotes.tax IS 'GST on fare locked at 0.';
COMMENT ON COLUMN fare_quotes.trip_fare IS '85/15 is applied to trip_fare after confirm, not to net_payable.';

CREATE TABLE order_fare_snapshots (
  fare_snapshot_id          UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  order_id                  UUID NOT NULL,
  fare_config_version_id    UUID NOT NULL,
  vehicle_category_id       UUID NOT NULL,
  vehicle_category_name     TEXT NOT NULL,
  distance_km               NUMERIC(10, 3) NOT NULL,
  stop_count                INTEGER NOT NULL,
  base_fare                 money_inr NOT NULL,
  per_km                    money_inr NOT NULL,
  distance_charge           money_inr NOT NULL,
  initial_minimum           money_inr NOT NULL,
  waiting                   money_inr NOT NULL,
  surge                     money_inr NOT NULL,
  toll                      money_inr NOT NULL,
  parking                   money_inr NOT NULL,
  trip_fare                 money_inr NOT NULL,
  discount                  money_inr NOT NULL DEFAULT 0,
  rounding                  money_inr NOT NULL DEFAULT 0,
  net_payable               money_inr NOT NULL,
  tax                       money_inr NOT NULL DEFAULT 0,
  quoted_at                 TIMESTAMPTZ NULL,
  confirmed_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT order_fare_snapshots_order_fk FOREIGN KEY (order_id) REFERENCES orders (order_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_fare_snapshots_order_unique UNIQUE (order_id),
  CONSTRAINT order_fare_snapshots_version_fk FOREIGN KEY (fare_config_version_id) REFERENCES fare_config_versions (fare_config_version_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_fare_snapshots_category_fk FOREIGN KEY (vehicle_category_id) REFERENCES vehicle_categories (vehicle_category_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_fare_snapshots_distance_chk CHECK (distance_km > 0),
  CONSTRAINT order_fare_snapshots_stop_count_chk CHECK (stop_count BETWEEN 2 AND 4),
  CONSTRAINT order_fare_snapshots_nonneg_chk CHECK (
    base_fare >= 0 AND per_km >= 0 AND distance_charge >= 0 AND initial_minimum >= 0
    AND waiting >= 0 AND surge >= 0 AND toll >= 0 AND parking >= 0
    AND trip_fare >= 0 AND discount >= 0 AND net_payable >= 0
  ),
  CONSTRAINT order_fare_snapshots_tax_zero_chk CHECK (tax = 0)
);

CREATE INDEX order_fare_snapshots_confirmed_idx ON order_fare_snapshots (confirmed_at);

COMMENT ON TABLE order_fare_snapshots IS
  'Immutable confirmed fare. trip_fare is the 85/15 base. tax always 0. Never overwrite.';
COMMENT ON COLUMN order_fare_snapshots.trip_fare IS '85/15 BASE. Not net_payable, not invoice grand total, not payment amount.';
COMMENT ON COLUMN order_fare_snapshots.net_payable IS 'Usual bill total for responsibility. Not the 85/15 base.';
