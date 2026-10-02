CREATE TABLE states (
  state_id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  name TEXT NOT NULL,
  code TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT states_code_unique UNIQUE (code),
  CONSTRAINT states_code_format_chk CHECK (code ~ '^[A-Z]{2,5}$')
);

COMMENT ON TABLE states IS
  'Indian state/UT master. Cities belong to a state. Launch state is Gujarat (GJ).';

COMMENT ON COLUMN states.code IS
  'Stable state token, e.g. GJ. Do not recycle.';

INSERT INTO states (name, code, active)
SELECT 'Gujarat', 'GJ', TRUE
WHERE NOT EXISTS (
  SELECT 1 FROM states WHERE code = 'GJ'
);

ALTER TABLE cities
  ADD COLUMN state_id UUID NULL;

COMMENT ON COLUMN cities.state_id IS
  'Owning state. Required after Stage B backfill.';

ALTER TABLE cities
  ADD CONSTRAINT cities_state_fk FOREIGN KEY (state_id) REFERENCES states (state_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT;

CREATE INDEX cities_state_id_idx ON cities (state_id);

UPDATE cities c
SET state_id = s.state_id
FROM states s
WHERE s.code = 'GJ'
  AND c.city_code = 'AMD'
  AND c.state_id IS NULL;

DO $$
DECLARE
  orphan_count INTEGER;
BEGIN
  SELECT count(*)::int INTO orphan_count FROM cities WHERE state_id IS NULL;
  IF orphan_count > 0 THEN
    RAISE EXCEPTION
      'cities.state_id backfill incomplete: % city row(s) have no state. Associate every city with a state before NOT NULL.',
      orphan_count;
  END IF;
END $$;

ALTER TABLE cities
  ALTER COLUMN state_id SET NOT NULL;
