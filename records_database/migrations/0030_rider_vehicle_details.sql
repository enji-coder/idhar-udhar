-- Optional vehicle description collected on rider onboarding.
-- Nullable so existing vehicle rows stay valid and are not marked complete.

ALTER TABLE vehicles
  ADD COLUMN model TEXT NULL,
  ADD COLUMN color TEXT NULL,
  ADD COLUMN manufacturing_year INTEGER NULL;

ALTER TABLE vehicles
  ADD CONSTRAINT vehicles_manufacturing_year_chk
  CHECK (
    manufacturing_year IS NULL
    OR (manufacturing_year >= 1980 AND manufacturing_year <= 2100)
  );
