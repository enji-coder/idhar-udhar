-- Delivery freezes the 85/15 split from the one ACTIVE payment settings version.
-- Migration 0005 created the table and its defaults, but it did not insert a
-- version because created_by_admin_profile_id requires an admin profile.
-- Mark as Delivered then fails with PAYMENT_SETTINGS_UNAVAILABLE.
--
-- This inserts the canonical 85/15/50 version only when no ACTIVE row exists.
-- An existing ACTIVE or SUPERSEDED version is not edited, superseded, or replaced.
-- Order finance snapshots, wallets, COD ledgers, and Cashfree rows are not touched.
-- If no ACTIVE version exists and admin_profiles is empty, the DO block raises.
-- That aborts the migration transaction, so this version is not recorded.

DO $$
DECLARE
  active_count integer;
  admin_count integer;
BEGIN
  SELECT COUNT(*) INTO active_count
  FROM payment_settings_versions
  WHERE status = 'ACTIVE';

  IF active_count > 0 THEN
    RETURN;
  END IF;

  SELECT COUNT(*) INTO admin_count
  FROM admin_profiles;

  IF admin_count = 0 THEN
    RAISE EXCEPTION '0036 refused: no admin profile exists to own the ACTIVE payment settings version'
      USING ERRCODE = 'check_violation';
  END IF;
END $$;

INSERT INTO payment_settings_versions (
  version,
  status,
  rider_percentage,
  company_commission_percentage,
  operational_cost_percentage_of_commission,
  effective_from,
  created_by_admin_profile_id
)
SELECT
  COALESCE((SELECT MAX(version) FROM payment_settings_versions), 0) + 1,
  'ACTIVE',
  85,
  15,
  50,
  now(),
  admin.admin_profile_id
FROM (
  SELECT admin_profile_id
  FROM admin_profiles
  ORDER BY
    active DESC,
    (
      role IN ('SUPER_ADMIN', 'FINANCE')
      OR finance_access
    ) DESC,
    created_at ASC,
    admin_profile_id ASC
  LIMIT 1
) admin
WHERE NOT EXISTS (
  SELECT 1
  FROM payment_settings_versions
  WHERE status = 'ACTIVE'
);
