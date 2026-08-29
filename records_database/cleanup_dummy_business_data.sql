-- Local-dev cleanup of e2e leftover business rows.
-- Does NOT drop schema, migrations, constraints, indexes, triggers, or functions.
-- Temporarily disables USER triggers so immutable financial rows can be removed.
-- Keep: schema_migrations, Ahmedabad/AMD, operator admin, payment_settings 85/15.

BEGIN;

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT format('%I.%I', n.nspname, c.relname) AS fq
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'
      AND c.relname <> 'schema_migrations'
  LOOP
    EXECUTE 'ALTER TABLE ' || r.fq || ' DISABLE TRIGGER USER';
  END LOOP;
END $$;

-- Break circular wallet/COD twin FKs and order/payment FKs before deleting parents.
UPDATE wallet_ledger_entries
SET related_cod_ledger_id = NULL,
    related_order_id = NULL,
    related_payment_transaction_id = NULL;
UPDATE cod_ledger_entries
SET related_wallet_ledger_id = NULL,
    related_order_id = NULL;
UPDATE customer_wallet_ledger_entries
SET related_order_id = NULL;

DELETE FROM notification_deliveries;
DELETE FROM notifications;
DELETE FROM notification_preferences;
DELETE FROM otp_challenges;
DELETE FROM sessions;
DELETE FROM idempotency_keys;
DELETE FROM invoice_lines;
DELETE FROM invoices;
DELETE FROM order_ratings;
DELETE FROM resend_snapshots;
DELETE FROM failed_deliveries;
DELETE FROM order_adjustments;
DELETE FROM order_cancellation_snapshots;
DELETE FROM order_tax_snapshots;
DELETE FROM order_finance_snapshots;
DELETE FROM wallet_ledger_entries;
DELETE FROM customer_wallet_ledger_entries;
DELETE FROM cod_ledger_entries;
DELETE FROM payment_transactions;
DELETE FROM order_payment_plans;
DELETE FROM order_payment_responsibilities;
DELETE FROM order_fare_snapshots;
DELETE FROM fare_quotes;
DELETE FROM order_offers;
DELETE FROM order_status_events;
DELETE FROM order_stops;
DELETE FROM orders;
DELETE FROM rider_cod_accounts;
DELETE FROM rider_wallet_accounts;
DELETE FROM customer_wallet_accounts;
DELETE FROM customer_saved_addresses;
DELETE FROM rider_documents;
DELETE FROM vehicle_documents;
DELETE FROM stored_files;
DELETE FROM rider_bank_accounts;
DELETE FROM rider_upis;
DELETE FROM rider_drivers;
DELETE FROM vehicles;
DELETE FROM fare_config_version_rates;
DELETE FROM fare_config_versions;
DELETE FROM cancellation_config_version_rules;
DELETE FROM cancellation_config_versions;
DELETE FROM payment_method_policy_versions;
DELETE FROM cod_policy_versions;
DELETE FROM extra_rate_versions;
DELETE FROM company_office_versions;
-- Removed with the e2e admins that created them; re-seeded below like the
-- kept payment_settings 85/15, so a freeze still resolves a published version.
DELETE FROM tax_config_versions;
DELETE FROM audit_logs;
DELETE FROM order_display_counters;
DELETE FROM vehicle_categories;
DELETE FROM zones;
DELETE FROM customer_profiles;
DELETE FROM rider_profiles;

DELETE FROM admin_profiles
WHERE identity_id NOT IN (
  SELECT identity_id
  FROM identities
  WHERE lower(coalesce(email, '')) IN (
    'swiftsendinnovation@gmail.com',
    'phase3-catalog-owner@example.test'
  )
);

WITH keep_identities AS (
  SELECT identity_id
  FROM identities
  WHERE lower(coalesce(email, '')) IN (
    'swiftsendinnovation@gmail.com',
    'phase3-catalog-owner@example.test'
  )
)
DELETE FROM identities
WHERE identity_id NOT IN (SELECT identity_id FROM keep_identities);

DELETE FROM cities WHERE city_code <> 'AMD';

INSERT INTO order_display_counters (city_id, last_seq)
SELECT city_id, 0
FROM cities
WHERE city_code = 'AMD'
ON CONFLICT (city_id) DO UPDATE SET last_seq = 0;

-- Restore the seeded GST default owned by a surviving admin. Inserts zero rows
-- when no SUPER_ADMIN remains; the report then says TAX_CONFIG_UNAVAILABLE
-- rather than inventing a rate.
INSERT INTO tax_config_versions (
  version,
  status,
  gst_rate,
  gst_calculation_basis,
  applies_to,
  notes,
  effective_from,
  created_by_admin_profile_id
)
SELECT
  1,
  'ACTIVE',
  18.00,
  'EXCLUSIVE',
  'COMPANY_COMMISSION',
  'Re-seeded default after local cleanup: 18% EXCLUSIVE on company commission.',
  now(),
  a.admin_profile_id
FROM admin_profiles a
WHERE a.role = 'SUPER_ADMIN'
ORDER BY a.created_at ASC, a.admin_profile_id ASC
LIMIT 1;

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT format('%I.%I', n.nspname, c.relname) AS fq
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'
      AND c.relname <> 'schema_migrations'
  LOOP
    EXECUTE 'ALTER TABLE ' || r.fq || ' ENABLE TRIGGER USER';
  END LOOP;
END $$;

COMMIT;
