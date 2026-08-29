-- Finance freeze, cancellation, failed delivery, adjustments, resend.
-- Original fare/finance never overwritten. Case A/B formulas unchanged.

CREATE TABLE order_finance_snapshots (
  finance_snapshot_id                           UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  order_id                                      UUID NOT NULL,
  snapshot_kind                                 TEXT NOT NULL,
  trip_fare                                     money_inr NOT NULL,
  rider_percentage                              percent_100 NOT NULL,
  company_commission_percentage                 percent_100 NOT NULL,
  operational_cost_percentage_of_commission     percent_100 NOT NULL,
  rider_amount                                  money_inr NOT NULL,
  company_commission_amount                     money_inr NOT NULL,
  operational_cost_amount                       money_inr NOT NULL,
  profit_amount                                 money_inr NOT NULL,
  payment_settings_version_id                   UUID NOT NULL,
  frozen_at                                     TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT finance_snap_order_fk FOREIGN KEY (order_id) REFERENCES orders (order_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT finance_snap_settings_fk FOREIGN KEY (payment_settings_version_id) REFERENCES payment_settings_versions (payment_settings_version_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT finance_snap_kind_chk CHECK (snapshot_kind IN ('ORIGINAL', 'REVERSAL', 'ADJUSTMENT_FREEZE')),
  CONSTRAINT finance_snap_shares_chk CHECK (rider_percentage + company_commission_percentage = 100),
  CONSTRAINT finance_snap_nonneg_chk CHECK (
    trip_fare >= 0 AND rider_amount >= 0 AND company_commission_amount >= 0
    AND operational_cost_amount >= 0 AND profit_amount >= 0
  )
);

CREATE UNIQUE INDEX finance_snap_one_original
  ON order_finance_snapshots (order_id)
  WHERE snapshot_kind = 'ORIGINAL';

CREATE INDEX finance_snap_order_idx ON order_finance_snapshots (order_id);
CREATE INDEX finance_snap_frozen_idx ON order_finance_snapshots (frozen_at);

COMMENT ON TABLE order_finance_snapshots IS
  'Insert-only P&L freeze. 85/15 on trip_fare. Ops = % of company share only. Reversal = new row.';
COMMENT ON COLUMN order_finance_snapshots.trip_fare IS '85/15 BASE = confirmed Trip Fare. Not invoice total.';
COMMENT ON COLUMN order_finance_snapshots.operational_cost_amount IS 'Internal allocation from company commission. Not a rider deduction.';

CREATE TABLE order_cancellation_snapshots (
  cancellation_snapshot_id          UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  order_id                          UUID NOT NULL,
  stage                             TEXT NOT NULL,
  actor_type                        TEXT NOT NULL,
  allowed                           BOOLEAN NOT NULL,
  fee                               money_inr NOT NULL DEFAULT 0,
  rider_share_percent               percent_100 NOT NULL,
  company_share_percent             percent_100 NOT NULL,
  rider_amount                      money_inr NOT NULL,
  company_amount                    money_inr NOT NULL,
  cancellation_config_version_id    UUID NOT NULL,
  created_at                        TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT cancel_snap_order_fk FOREIGN KEY (order_id) REFERENCES orders (order_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT cancel_snap_version_fk FOREIGN KEY (cancellation_config_version_id) REFERENCES cancellation_config_versions (cancellation_config_version_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT cancel_snap_stage_chk CHECK (stage IN (
    'BEFORE_ACCEPT', 'AFTER_ACCEPT', 'AFTER_ARRIVE_PICKUP', 'AFTER_PICKUP', 'IN_TRANSIT'
  )),
  CONSTRAINT cancel_snap_actor_chk CHECK (actor_type IN ('CUSTOMER', 'RIDER', 'ADMIN')),
  CONSTRAINT cancel_snap_fee_chk CHECK (fee >= 0),
  CONSTRAINT cancel_snap_amounts_chk CHECK (rider_amount >= 0 AND company_amount >= 0),
  CONSTRAINT cancel_snap_shares_chk CHECK (rider_share_percent + company_share_percent = 100)
);

CREATE UNIQUE INDEX cancel_snap_one_successful
  ON order_cancellation_snapshots (order_id)
  WHERE allowed = TRUE;

CREATE INDEX cancel_snap_order_idx ON order_cancellation_snapshots (order_id);

COMMENT ON TABLE order_cancellation_snapshots IS
  'Write even if fee is 0. Shares from versioned cancel rules, not auto 85/15.';

CREATE TABLE failed_deliveries (
  failed_delivery_id        UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  order_id                  UUID NOT NULL,
  reason                    TEXT NOT NULL DEFAULT 'RECEIVER_UNAVAILABLE',
  office_version_id         UUID NOT NULL,
  office_address_snapshot   TEXT NOT NULL,
  office_latitude           NUMERIC(9, 6) NOT NULL,
  office_longitude          NUMERIC(9, 6) NOT NULL,
  office_distance_km        NUMERIC(10, 3) NOT NULL,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT failed_deliveries_order_fk FOREIGN KEY (order_id) REFERENCES orders (order_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT failed_deliveries_order_unique UNIQUE (order_id),
  CONSTRAINT failed_deliveries_office_fk FOREIGN KEY (office_version_id) REFERENCES company_office_versions (company_office_version_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT failed_deliveries_reason_chk CHECK (reason IN ('RECEIVER_UNAVAILABLE')),
  CONSTRAINT failed_deliveries_distance_chk CHECK (office_distance_km >= 0)
);

COMMENT ON TABLE failed_deliveries IS 'Not a cancellation. Original 85/15 stays. Office copy survives later office moves.';

CREATE TABLE order_adjustments (
  order_adjustment_id     UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  order_id                UUID NOT NULL,
  adjustment_type         TEXT NOT NULL,
  amount                  money_inr NOT NULL,
  beneficiary             TEXT NOT NULL,
  extra_rate_version_id   UUID NULL,
  distance_km             NUMERIC(10, 3) NULL,
  reason                  TEXT NOT NULL,
  actor_type              TEXT NOT NULL,
  actor_profile_id        UUID NULL,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT order_adj_order_fk FOREIGN KEY (order_id) REFERENCES orders (order_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_adj_extra_rate_fk FOREIGN KEY (extra_rate_version_id) REFERENCES extra_rate_versions (extra_rate_version_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_adj_type_chk CHECK (adjustment_type IN (
    'OFFICE_COMPENSATION', 'ADMIN_ADJUSTMENT', 'OVERPAY_CORRECTION'
  )),
  CONSTRAINT order_adj_beneficiary_chk CHECK (beneficiary IN ('RIDER', 'COMPANY', 'CUSTOMER')),
  CONSTRAINT order_adj_amount_chk CHECK (amount >= 0),
  CONSTRAINT order_adj_actor_chk CHECK (actor_type IN ('CUSTOMER', 'RIDER', 'ADMIN', 'WEBHOOK', 'SYSTEM'))
);

CREATE INDEX order_adj_order_idx ON order_adjustments (order_id);

COMMENT ON TABLE order_adjustments IS
  'One extra money fact. Office compensation = km × snapshotted 8/km to rider. Not 85/15. Not a rewrite of Trip Fare.';

CREATE TABLE resend_snapshots (
  resend_snapshot_id            UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  original_order_id             UUID NOT NULL,
  child_order_id                UUID NULL,
  resend_case                   TEXT NOT NULL,
  distance_km                   NUMERIC(10, 3) NOT NULL,
  case_a_base_fare              money_inr NULL,
  customer_amount               money_inr NOT NULL,
  rider_amount                  money_inr NOT NULL,
  company_amount                money_inr NOT NULL,
  fare_config_version_id        UUID NULL,
  extra_rate_version_id         UUID NOT NULL,
  payment_settings_version_id   UUID NULL,
  request_status                TEXT NOT NULL,
  created_at                    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT resend_original_fk FOREIGN KEY (original_order_id) REFERENCES orders (order_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT resend_child_fk FOREIGN KEY (child_order_id) REFERENCES orders (order_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT resend_extra_rate_fk FOREIGN KEY (extra_rate_version_id) REFERENCES extra_rate_versions (extra_rate_version_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT resend_fare_version_fk FOREIGN KEY (fare_config_version_id) REFERENCES fare_config_versions (fare_config_version_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT resend_payment_settings_fk FOREIGN KEY (payment_settings_version_id) REFERENCES payment_settings_versions (payment_settings_version_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT resend_case_chk CHECK (resend_case IN ('A', 'B')),
  CONSTRAINT resend_status_chk CHECK (request_status IN ('NOT_DECIDED', 'REQUESTED', 'IN_PROGRESS', 'COMPLETED')),
  CONSTRAINT resend_distance_chk CHECK (distance_km >= 0),
  CONSTRAINT resend_amounts_chk CHECK (
    customer_amount >= 0 AND rider_amount >= 0 AND company_amount >= 0
  ),
  CONSTRAINT resend_case_shape_chk CHECK (
    (
      resend_case = 'A'
      AND case_a_base_fare IS NOT NULL
      AND fare_config_version_id IS NOT NULL
      AND payment_settings_version_id IS NOT NULL
    )
    OR (
      resend_case = 'B'
      AND case_a_base_fare IS NULL
      AND fare_config_version_id IS NULL
      AND payment_settings_version_id IS NULL
    )
  )
);

CREATE INDEX resend_original_idx ON resend_snapshots (original_order_id);
CREATE UNIQUE INDEX resend_child_unique
  ON resend_snapshots (child_order_id)
  WHERE child_order_id IS NOT NULL;

COMMENT ON TABLE resend_snapshots IS
  'Case A: resend-time base + 10/km then versioned 85/15 (defaults 85/15). Case B: 10/8/2 not 85/15. Original fare never overwritten.';
COMMENT ON COLUMN resend_snapshots.customer_amount IS
  'Case A: snapshotted base + 10*km. Case B: 10*km. 85/15 uses payment_settings_version at resend for Case A, not invoice total.';
COMMENT ON COLUMN resend_snapshots.child_order_id IS
  'Optional Case A child order. Runtime shape is a technical option; both columns exist.';
