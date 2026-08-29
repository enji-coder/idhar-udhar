-- Identities (login person) + geography + vehicle catalog.
-- Phone is never an order foreign key.

CREATE TABLE identities (
  identity_id         UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  phone_normalized    TEXT NOT NULL,
  email               TEXT NULL,
  auth_status         TEXT NOT NULL DEFAULT 'ACTIVE',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT identities_phone_unique UNIQUE (phone_normalized),
  CONSTRAINT identities_auth_status_chk CHECK (auth_status IN ('ACTIVE', 'LOCKED', 'REVOKED'))
);

CREATE UNIQUE INDEX identities_email_unique
  ON identities (email)
  WHERE email IS NOT NULL;

CREATE TRIGGER identities_set_updated_at
  BEFORE UPDATE ON identities
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE identities IS 'One physical person, one login. Customer and Rider profiles may share this row.';
COMMENT ON COLUMN identities.phone_normalized IS 'Unique 10-digit / E.164. Not an order FK.';

CREATE TABLE cities (
  city_id     UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  name        TEXT NOT NULL,
  city_code   TEXT NOT NULL,
  active      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT cities_code_unique UNIQUE (city_code),
  CONSTRAINT cities_code_format_chk CHECK (city_code ~ '^[A-Z]{2,5}$')
);

COMMENT ON COLUMN cities.city_code IS 'Display-id city token, e.g. AMD. Do not recycle.';

CREATE TABLE zones (
  zone_id     UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  city_id     UUID NOT NULL,
  name        TEXT NOT NULL,
  active      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT zones_city_fk FOREIGN KEY (city_id) REFERENCES cities (city_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
);

CREATE INDEX zones_city_id_idx ON zones (city_id);

CREATE TABLE vehicle_categories (
  vehicle_category_id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  code                TEXT NULL,
  name                TEXT NOT NULL,
  active              BOOLEAN NOT NULL DEFAULT TRUE,
  weight_capacity     TEXT NULL,
  size                TEXT NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX vehicle_categories_code_unique
  ON vehicle_categories (code)
  WHERE code IS NOT NULL;

CREATE TRIGGER vehicle_categories_set_updated_at
  BEFORE UPDATE ON vehicle_categories
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE vehicle_categories IS 'Sellable type. Join by id, never by the word Bike.';
