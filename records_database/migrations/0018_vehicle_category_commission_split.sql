-- Per-category rider/company split, versioned with fare rates and copied onto
-- quotes and order fare snapshots. Existing rows have no explicit split, so
-- they receive the current 85/15 rule. Later publishes do not rewrite snapshots.
-- Operational cost remains on payment_settings_versions (50% of company commission).

ALTER TABLE fare_config_version_rates
  ADD COLUMN rider_percentage percent_100 NOT NULL DEFAULT 85,
  ADD COLUMN company_commission_percentage percent_100 NOT NULL DEFAULT 15;

ALTER TABLE fare_config_version_rates
  ADD CONSTRAINT fare_rates_shares_chk
  CHECK (rider_percentage + company_commission_percentage = 100);

ALTER TABLE fare_quotes
  ADD COLUMN rider_percentage percent_100 NOT NULL DEFAULT 85,
  ADD COLUMN company_commission_percentage percent_100 NOT NULL DEFAULT 15;

ALTER TABLE fare_quotes
  ADD CONSTRAINT fare_quotes_shares_chk
  CHECK (rider_percentage + company_commission_percentage = 100);

ALTER TABLE order_fare_snapshots
  ADD COLUMN rider_percentage percent_100 NOT NULL DEFAULT 85,
  ADD COLUMN company_commission_percentage percent_100 NOT NULL DEFAULT 15;

ALTER TABLE order_fare_snapshots
  ADD CONSTRAINT order_fare_snapshots_shares_chk
  CHECK (rider_percentage + company_commission_percentage = 100);

COMMENT ON COLUMN fare_config_version_rates.rider_percentage IS
  'Rider share of trip_fare for this category version. Not a live recalculation of old orders.';
COMMENT ON COLUMN fare_config_version_rates.company_commission_percentage IS
  'Company share of trip_fare. Must sum with rider_percentage to 100. Operational cost is still a percent of this share.';
COMMENT ON COLUMN order_fare_snapshots.rider_percentage IS
  'Split frozen at confirm from the fare version. Finance freeze must use this, not a later category edit.';
