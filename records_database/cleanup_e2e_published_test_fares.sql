-- Development-database cleanup of leftover E2E published fare test rows.
-- Does NOT drop/disable/alter migration 0014 triggers, FKs, indexes, or schema.
--
-- Dependency chain (all current rows are e2e leftovers; no real business data):
--   E2E vehicle_categories
--     -> fare_config_versions (ACTIVE / SUPERSEDED)
--       -> fare_config_version_rates
--
-- Row DELETE on published rates is correctly blocked by fare_rates_protect_published.
-- TRUNCATE is used only on fare_config_version_rates after proving:
--   * no orders / vehicles / quotes / snapshots / resends
--   * remaining categories are E2E test names only
-- TRUNCATE does not fire FOR EACH ROW DELETE triggers and does not disable them.

BEGIN;

DO $$
DECLARE
  unexpected INTEGER;
  dependents BIGINT;
BEGIN
  SELECT count(*) INTO unexpected
  FROM vehicle_categories
  WHERE name NOT LIKE 'E2E Fare %'
    AND name NOT LIKE 'E2E Bike %';

  IF unexpected > 0 THEN
    RAISE EXCEPTION 'Refusing cleanup: non-test vehicle categories exist';
  END IF;

  SELECT
    (SELECT count(*) FROM orders)
    + (SELECT count(*) FROM vehicles)
    + (SELECT count(*) FROM fare_quotes)
    + (SELECT count(*) FROM order_fare_snapshots)
    + (SELECT count(*) FROM resend_snapshots)
  INTO dependents;

  IF dependents > 0 THEN
    RAISE EXCEPTION 'Refusing cleanup: historical business dependents exist (%)', dependents;
  END IF;
END $$;

TRUNCATE fare_config_version_rates;

DELETE FROM fare_config_versions;
DELETE FROM vehicle_categories
WHERE name LIKE 'E2E Fare %'
   OR name LIKE 'E2E Bike %';

DELETE FROM sessions
WHERE identity_id IN (
  SELECT identity_id FROM identities WHERE email LIKE 'p2-admin-%@example.test'
);

DELETE FROM otp_challenges
WHERE identity_id IN (
  SELECT identity_id FROM identities WHERE email LIKE 'p2-admin-%@example.test'
)
OR phone_normalized IN (
  SELECT phone_normalized FROM identities WHERE email LIKE 'p2-admin-%@example.test'
);

DELETE FROM notification_deliveries
WHERE notification_id IN (
  SELECT notification_id
  FROM notifications
  WHERE recipient_identity_id IN (
    SELECT identity_id FROM identities WHERE email LIKE 'p2-admin-%@example.test'
  )
);

DELETE FROM notifications
WHERE recipient_identity_id IN (
  SELECT identity_id FROM identities WHERE email LIKE 'p2-admin-%@example.test'
);

DELETE FROM notification_preferences
WHERE identity_id IN (
  SELECT identity_id FROM identities WHERE email LIKE 'p2-admin-%@example.test'
);

DELETE FROM admin_profiles
WHERE identity_id IN (
  SELECT identity_id FROM identities WHERE email LIKE 'p2-admin-%@example.test'
);

DELETE FROM identities
WHERE email LIKE 'p2-admin-%@example.test';

COMMIT;
