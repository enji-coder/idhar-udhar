-- Versioned Admin configuration. Publish = INSERT N+1; never edit used ACTIVE/SUPERSEDED payloads.

CREATE TABLE fare_config_versions (
  fare_config_version_id        UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  version                       INTEGER NOT NULL,
  status                        TEXT NOT NULL DEFAULT 'DRAFT',
  effective_from                TIMESTAMPTZ NOT NULL,
  effective_until               TIMESTAMPTZ NULL,
  created_by_admin_profile_id   UUID NOT NULL,
  created_at                    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fare_config_version_unique UNIQUE (version),
  CONSTRAINT fare_config_version_positive_chk CHECK (version > 0),
  CONSTRAINT fare_config_status_chk CHECK (status IN ('DRAFT', 'ACTIVE', 'SUPERSEDED')),
  CONSTRAINT fare_config_created_by_fk FOREIGN KEY (created_by_admin_profile_id) REFERENCES admin_profiles (admin_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
);

CREATE UNIQUE INDEX fare_config_one_active
  ON fare_config_versions ((TRUE))
  WHERE status = 'ACTIVE';

CREATE TABLE fare_config_version_rates (
  fare_config_version_rate_id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  fare_config_version_id      UUID NOT NULL,
  vehicle_category_id         UUID NOT NULL,
  base_fare                   money_inr NOT NULL,
  per_km                      money_inr NOT NULL,
  initial_minimum             money_inr NOT NULL,
  waiting                     money_inr NOT NULL,
  surge                       money_inr NOT NULL,
  toll                        money_inr NOT NULL,
  parking                     money_inr NOT NULL,
  CONSTRAINT fare_rates_version_fk FOREIGN KEY (fare_config_version_id) REFERENCES fare_config_versions (fare_config_version_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fare_rates_category_fk FOREIGN KEY (vehicle_category_id) REFERENCES vehicle_categories (vehicle_category_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fare_rates_version_category_unique UNIQUE (fare_config_version_id, vehicle_category_id),
  CONSTRAINT fare_rates_nonneg_chk CHECK (
    base_fare >= 0 AND per_km >= 0 AND initial_minimum >= 0
    AND waiting >= 0 AND surge >= 0 AND toll >= 0 AND parking >= 0
  )
);

CREATE INDEX fare_rates_version_idx ON fare_config_version_rates (fare_config_version_id);

CREATE TABLE payment_settings_versions (
  payment_settings_version_id                 UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  version                                     INTEGER NOT NULL,
  status                                      TEXT NOT NULL DEFAULT 'DRAFT',
  rider_percentage                            percent_100 NOT NULL DEFAULT 85,
  company_commission_percentage               percent_100 NOT NULL DEFAULT 15,
  operational_cost_percentage_of_commission   percent_100 NOT NULL DEFAULT 50,
  effective_from                              TIMESTAMPTZ NOT NULL,
  effective_until                             TIMESTAMPTZ NULL,
  created_by_admin_profile_id                 UUID NOT NULL,
  created_at                                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT payment_settings_version_unique UNIQUE (version),
  CONSTRAINT payment_settings_version_positive_chk CHECK (version > 0),
  CONSTRAINT payment_settings_status_chk CHECK (status IN ('DRAFT', 'ACTIVE', 'SUPERSEDED')),
  CONSTRAINT payment_settings_shares_chk CHECK (rider_percentage + company_commission_percentage = 100),
  CONSTRAINT payment_settings_created_by_fk FOREIGN KEY (created_by_admin_profile_id) REFERENCES admin_profiles (admin_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
);

CREATE UNIQUE INDEX payment_settings_one_active
  ON payment_settings_versions ((TRUE))
  WHERE status = 'ACTIVE';

COMMENT ON TABLE payment_settings_versions IS
  'Versioned 85/15/50. Percents apply to confirmed Trip Fare, never invoice grand total, GST, or payment amount.';
COMMENT ON COLUMN payment_settings_versions.operational_cost_percentage_of_commission IS
  'Percent of company commission only. Not a rider deduction.';

CREATE TABLE payment_method_policy_versions (
  payment_method_policy_version_id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  version                          INTEGER NOT NULL,
  status                           TEXT NOT NULL DEFAULT 'DRAFT',
  cash_enabled                     BOOLEAN NOT NULL,
  online_enabled                   BOOLEAN NOT NULL,
  upi_enabled                      BOOLEAN NOT NULL DEFAULT FALSE,
  card_enabled                     BOOLEAN NOT NULL DEFAULT FALSE,
  net_banking_enabled              BOOLEAN NOT NULL DEFAULT FALSE,
  wallet_enabled                   BOOLEAN NOT NULL DEFAULT FALSE,
  effective_from                   TIMESTAMPTZ NOT NULL,
  effective_until                  TIMESTAMPTZ NULL,
  created_by_admin_profile_id      UUID NOT NULL,
  created_at                       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT payment_method_version_unique UNIQUE (version),
  CONSTRAINT payment_method_version_positive_chk CHECK (version > 0),
  CONSTRAINT payment_method_status_chk CHECK (status IN ('DRAFT', 'ACTIVE', 'SUPERSEDED')),
  CONSTRAINT payment_method_created_by_fk FOREIGN KEY (created_by_admin_profile_id) REFERENCES admin_profiles (admin_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
);

CREATE UNIQUE INDEX payment_method_one_active
  ON payment_method_policy_versions ((TRUE))
  WHERE status = 'ACTIVE';

COMMENT ON COLUMN payment_method_policy_versions.wallet_enabled IS
  'Schema supports the label. V1 booking must not auto-debit customer wallet until a future business decision.';

CREATE TABLE cancellation_config_versions (
  cancellation_config_version_id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  actor                          TEXT NOT NULL,
  version                        INTEGER NOT NULL,
  status                         TEXT NOT NULL DEFAULT 'DRAFT',
  effective_from                 TIMESTAMPTZ NOT NULL,
  effective_until                TIMESTAMPTZ NULL,
  created_by_admin_profile_id    UUID NOT NULL,
  created_at                     TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT cancellation_config_actor_version_unique UNIQUE (actor, version),
  CONSTRAINT cancellation_config_version_positive_chk CHECK (version > 0),
  CONSTRAINT cancellation_config_actor_chk CHECK (actor IN ('CUSTOMER', 'RIDER')),
  CONSTRAINT cancellation_config_status_chk CHECK (status IN ('DRAFT', 'ACTIVE', 'SUPERSEDED')),
  CONSTRAINT cancellation_config_created_by_fk FOREIGN KEY (created_by_admin_profile_id) REFERENCES admin_profiles (admin_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
);

CREATE UNIQUE INDEX cancellation_config_one_active_per_actor
  ON cancellation_config_versions (actor)
  WHERE status = 'ACTIVE';

CREATE TABLE cancellation_config_version_rules (
  cancellation_config_version_rule_id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  cancellation_config_version_id      UUID NOT NULL,
  stage                               TEXT NOT NULL,
  enabled                             BOOLEAN NOT NULL,
  fee                                 money_inr NOT NULL DEFAULT 0,
  rider_share_percent                 percent_100 NOT NULL,
  company_share_percent               percent_100 NOT NULL,
  CONSTRAINT cancel_rules_version_fk FOREIGN KEY (cancellation_config_version_id) REFERENCES cancellation_config_versions (cancellation_config_version_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT cancel_rules_stage_unique UNIQUE (cancellation_config_version_id, stage),
  CONSTRAINT cancel_rules_stage_chk CHECK (stage IN (
    'BEFORE_ACCEPT', 'AFTER_ACCEPT', 'AFTER_ARRIVE_PICKUP', 'AFTER_PICKUP', 'IN_TRANSIT'
  )),
  CONSTRAINT cancel_rules_fee_chk CHECK (fee >= 0),
  CONSTRAINT cancel_rules_shares_chk CHECK (rider_share_percent + company_share_percent = 100)
);

COMMENT ON TABLE cancellation_config_version_rules IS
  'Default fee 0. Shares sum to 100. Not automatically 85/15.';

CREATE TABLE cod_policy_versions (
  cod_policy_version_id         UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  version                       INTEGER NOT NULL,
  status                        TEXT NOT NULL DEFAULT 'DRAFT',
  suspend_threshold             money_inr NOT NULL DEFAULT 100,
  effective_from                TIMESTAMPTZ NOT NULL,
  effective_until               TIMESTAMPTZ NULL,
  created_by_admin_profile_id   UUID NOT NULL,
  created_at                    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT cod_policy_version_unique UNIQUE (version),
  CONSTRAINT cod_policy_version_positive_chk CHECK (version > 0),
  CONSTRAINT cod_policy_status_chk CHECK (status IN ('DRAFT', 'ACTIVE', 'SUPERSEDED')),
  CONSTRAINT cod_policy_threshold_chk CHECK (suspend_threshold >= 0),
  CONSTRAINT cod_policy_created_by_fk FOREIGN KEY (created_by_admin_profile_id) REFERENCES admin_profiles (admin_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
);

CREATE UNIQUE INDEX cod_policy_one_active
  ON cod_policy_versions ((TRUE))
  WHERE status = 'ACTIVE';

COMMENT ON COLUMN cod_policy_versions.suspend_threshold IS 'FINAL default today 100. Still versioned.';

CREATE TABLE extra_rate_versions (
  extra_rate_version_id             UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  version                           INTEGER NOT NULL,
  status                            TEXT NOT NULL DEFAULT 'DRAFT',
  resend_case_a_per_km              money_inr NOT NULL DEFAULT 10,
  resend_case_b_customer_per_km     money_inr NOT NULL DEFAULT 10,
  resend_case_b_rider_per_km        money_inr NOT NULL DEFAULT 8,
  resend_case_b_company_per_km      money_inr NOT NULL DEFAULT 2,
  office_handover_per_km            money_inr NOT NULL DEFAULT 8,
  effective_from                    TIMESTAMPTZ NOT NULL,
  effective_until                   TIMESTAMPTZ NULL,
  created_by_admin_profile_id       UUID NOT NULL,
  created_at                        TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT extra_rate_version_unique UNIQUE (version),
  CONSTRAINT extra_rate_version_positive_chk CHECK (version > 0),
  CONSTRAINT extra_rate_status_chk CHECK (status IN ('DRAFT', 'ACTIVE', 'SUPERSEDED')),
  CONSTRAINT extra_rate_nonneg_chk CHECK (
    resend_case_a_per_km >= 0
    AND resend_case_b_customer_per_km >= 0
    AND resend_case_b_rider_per_km >= 0
    AND resend_case_b_company_per_km >= 0
    AND office_handover_per_km >= 0
  ),
  CONSTRAINT extra_rate_created_by_fk FOREIGN KEY (created_by_admin_profile_id) REFERENCES admin_profiles (admin_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
);

CREATE UNIQUE INDEX extra_rate_one_active
  ON extra_rate_versions ((TRUE))
  WHERE status = 'ACTIVE';

COMMENT ON TABLE extra_rate_versions IS
  'Locked defaults: Case A +10/km then 85/15; Case B 10/8/2; office 8/km not 85/15. No forever 10=8+2 CHECK.';

CREATE TABLE company_office_versions (
  company_office_version_id     UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  version                       INTEGER NOT NULL,
  status                        TEXT NOT NULL DEFAULT 'DRAFT',
  city_id                       UUID NOT NULL,
  address                       TEXT NOT NULL,
  latitude                      NUMERIC(9, 6) NOT NULL,
  longitude                     NUMERIC(9, 6) NOT NULL,
  effective_from                TIMESTAMPTZ NOT NULL,
  effective_until               TIMESTAMPTZ NULL,
  created_by_admin_profile_id   UUID NOT NULL,
  created_at                    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT company_office_version_unique UNIQUE (version),
  CONSTRAINT company_office_version_positive_chk CHECK (version > 0),
  CONSTRAINT company_office_status_chk CHECK (status IN ('DRAFT', 'ACTIVE', 'SUPERSEDED')),
  CONSTRAINT company_office_city_fk FOREIGN KEY (city_id) REFERENCES cities (city_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT company_office_created_by_fk FOREIGN KEY (created_by_admin_profile_id) REFERENCES admin_profiles (admin_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
);

CREATE UNIQUE INDEX company_office_one_active_per_city
  ON company_office_versions (city_id)
  WHERE status = 'ACTIVE';
