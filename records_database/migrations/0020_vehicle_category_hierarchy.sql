-- Parent vehicle type and canonical vehicle slug on the existing category row.
-- Pricing and the rider/company split stay on fare_config_version_rates.
-- A null pair keeps rows whose name is not one of the production vehicles.
-- A set pair must be a supported combination. Display text stays in name.

ALTER TABLE vehicle_categories
  ADD COLUMN vehicle_type TEXT NULL,
  ADD COLUMN vehicle TEXT NULL;

-- Both columns null, or both set to one supported pair.
-- IS NOT NULL is required: comparing NULL is UNKNOWN, and CHECK accepts UNKNOWN.
ALTER TABLE vehicle_categories
  ADD CONSTRAINT vehicle_categories_hierarchy_chk CHECK (
    (vehicle_type IS NULL AND vehicle IS NULL)
    OR (
      vehicle_type IS NOT NULL
      AND vehicle IS NOT NULL
      AND (
        (vehicle_type = 'two_wheeler' AND vehicle IN ('bike', 'scooty'))
        OR (vehicle_type = 'three_wheeler' AND vehicle = 'loader_riksha')
        OR (vehicle_type = 'truck' AND vehicle IN ('mini_truck', 'tempo', 'large_tempo', 'truck'))
      )
    )
  );

COMMENT ON COLUMN vehicle_categories.vehicle_type IS
  'Canonical parent: two_wheeler, three_wheeler, or truck. Null only when the row is outside the production hierarchy.';
COMMENT ON COLUMN vehicle_categories.vehicle IS
  'Canonical vehicle slug under vehicle_type. Customers still read the display name column.';

-- Exact display names only. Unlisted names, including Auto, are left unset.
UPDATE vehicle_categories
SET vehicle_type = 'two_wheeler',
    vehicle = 'bike'
WHERE vehicle_type IS NULL
  AND vehicle IS NULL
  AND lower(btrim(regexp_replace(name, '[[:space:]]+', ' ', 'g'))) = 'bike';

UPDATE vehicle_categories
SET vehicle_type = 'two_wheeler',
    vehicle = 'scooty'
WHERE vehicle_type IS NULL
  AND vehicle IS NULL
  AND lower(btrim(regexp_replace(name, '[[:space:]]+', ' ', 'g'))) IN ('scooty', 'scooter');

UPDATE vehicle_categories
SET vehicle_type = 'three_wheeler',
    vehicle = 'loader_riksha'
WHERE vehicle_type IS NULL
  AND vehicle IS NULL
  AND lower(btrim(regexp_replace(name, '[[:space:]]+', ' ', 'g'))) IN (
    'loader riksha', 'loader rickshaw', 'loader rikshaw'
  );

UPDATE vehicle_categories
SET vehicle_type = 'truck',
    vehicle = 'mini_truck'
WHERE vehicle_type IS NULL
  AND vehicle IS NULL
  AND lower(btrim(regexp_replace(name, '[[:space:]]+', ' ', 'g'))) = 'mini truck';

UPDATE vehicle_categories
SET vehicle_type = 'truck',
    vehicle = 'large_tempo'
WHERE vehicle_type IS NULL
  AND vehicle IS NULL
  AND lower(btrim(regexp_replace(name, '[[:space:]]+', ' ', 'g'))) = 'large tempo';

UPDATE vehicle_categories
SET vehicle_type = 'truck',
    vehicle = 'tempo'
WHERE vehicle_type IS NULL
  AND vehicle IS NULL
  AND lower(btrim(regexp_replace(name, '[[:space:]]+', ' ', 'g'))) = 'tempo';

UPDATE vehicle_categories
SET vehicle_type = 'truck',
    vehicle = 'truck'
WHERE vehicle_type IS NULL
  AND vehicle IS NULL
  AND lower(btrim(regexp_replace(name, '[[:space:]]+', ' ', 'g'))) = 'truck';
