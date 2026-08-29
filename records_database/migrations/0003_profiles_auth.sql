-- Role profiles, OTP, sessions, saved addresses.
-- Password lives on admin_profiles so OTP marketplace users have no password column.

CREATE TABLE customer_profiles (
  customer_profile_id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  identity_id         UUID NOT NULL,
  display_name        TEXT NOT NULL,
  email               TEXT NULL,
  invoice_email       TEXT NULL,
  status              TEXT NOT NULL DEFAULT 'ACTIVE',
  default_city_id     UUID NULL,
  deactivated_at      TIMESTAMPTZ NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT customer_profiles_identity_fk FOREIGN KEY (identity_id) REFERENCES identities (identity_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT customer_profiles_identity_unique UNIQUE (identity_id),
  CONSTRAINT customer_profiles_city_fk FOREIGN KEY (default_city_id) REFERENCES cities (city_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT customer_profiles_status_chk CHECK (status IN ('ACTIVE', 'DEACTIVATED'))
);

CREATE TRIGGER customer_profiles_set_updated_at
  BEFORE UPDATE ON customer_profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE rider_profiles (
  rider_profile_id        UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  identity_id             UUID NOT NULL,
  onboarding_kyc_status   TEXT NOT NULL DEFAULT 'PENDING',
  approval_status         TEXT NOT NULL DEFAULT 'PENDING',
  online_status           TEXT NOT NULL DEFAULT 'OFFLINE',
  home_city_id            UUID NULL,
  home_zone_id            UUID NULL,
  cod_operational_status  TEXT NOT NULL DEFAULT 'CLEAR',
  deactivated_at          TIMESTAMPTZ NULL,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT rider_profiles_identity_fk FOREIGN KEY (identity_id) REFERENCES identities (identity_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT rider_profiles_identity_unique UNIQUE (identity_id),
  CONSTRAINT rider_profiles_city_fk FOREIGN KEY (home_city_id) REFERENCES cities (city_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT rider_profiles_zone_fk FOREIGN KEY (home_zone_id) REFERENCES zones (zone_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT rider_profiles_kyc_chk CHECK (onboarding_kyc_status IN ('PENDING', 'SUBMITTED', 'APPROVED', 'REJECTED')),
  CONSTRAINT rider_profiles_approval_chk CHECK (approval_status IN ('PENDING', 'APPROVED', 'REJECTED', 'SUSPENDED')),
  CONSTRAINT rider_profiles_online_chk CHECK (online_status IN ('ONLINE', 'OFFLINE')),
  CONSTRAINT rider_profiles_cod_chk CHECK (cod_operational_status IN ('CLEAR', 'SUSPENDED_FOR_COD'))
);

CREATE INDEX rider_profiles_cod_status_idx ON rider_profiles (cod_operational_status);
CREATE INDEX rider_profiles_home_city_idx ON rider_profiles (home_city_id);

CREATE TRIGGER rider_profiles_set_updated_at
  BEFORE UPDATE ON rider_profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON COLUMN rider_profiles.cod_operational_status IS
  'SUSPENDED_FOR_COD when COD Due >= active threshold (default 100). Cannot accept new offers.';

CREATE TABLE admin_profiles (
  admin_profile_id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  identity_id      UUID NOT NULL,
  role             TEXT NOT NULL,
  modules          JSONB NOT NULL DEFAULT '[]'::jsonb,
  finance_access   BOOLEAN NOT NULL DEFAULT FALSE,
  payout_approve   BOOLEAN NOT NULL DEFAULT FALSE,
  city_scope_id    UUID NULL,
  password_hash    TEXT NOT NULL,
  active           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT admin_profiles_identity_fk FOREIGN KEY (identity_id) REFERENCES identities (identity_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT admin_profiles_identity_unique UNIQUE (identity_id),
  CONSTRAINT admin_profiles_city_fk FOREIGN KEY (city_scope_id) REFERENCES cities (city_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT admin_profiles_role_chk CHECK (role IN (
    'SUPER_ADMIN', 'SUB_ADMIN', 'OPERATIONS', 'FINANCE', 'SUPPORT', 'MANAGER'
  ))
);

CREATE TRIGGER admin_profiles_set_updated_at
  BEFORE UPDATE ON admin_profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON COLUMN admin_profiles.password_hash IS 'Argon2id or equivalent. Never stored in React. OTP users have no password.';

CREATE TABLE otp_challenges (
  otp_challenge_id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  phone_normalized TEXT NOT NULL,
  identity_id      UUID NULL,
  code_hash        TEXT NOT NULL,
  expires_at       TIMESTAMPTZ NOT NULL,
  attempt_count    INTEGER NOT NULL DEFAULT 0,
  max_attempts     INTEGER NULL,
  cooldown_until   TIMESTAMPTZ NULL,
  ip               TEXT NULL,
  consumed_at      TIMESTAMPTZ NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT otp_challenges_identity_fk FOREIGN KEY (identity_id) REFERENCES identities (identity_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT otp_challenges_attempts_chk CHECK (attempt_count >= 0),
  CONSTRAINT otp_challenges_max_attempts_chk CHECK (max_attempts IS NULL OR max_attempts > 0)
);

CREATE INDEX otp_challenges_phone_created_idx ON otp_challenges (phone_normalized, created_at DESC);
CREATE INDEX otp_challenges_identity_idx ON otp_challenges (identity_id);

COMMENT ON COLUMN otp_challenges.code_hash IS 'Never store plaintext OTP.';

CREATE TABLE sessions (
  session_id            UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  identity_id           UUID NOT NULL,
  active_profile_type   TEXT NOT NULL,
  customer_profile_id   UUID NULL,
  rider_profile_id      UUID NULL,
  admin_profile_id      UUID NULL,
  refresh_token_hash    TEXT NULL,
  expires_at            TIMESTAMPTZ NOT NULL,
  revoked_at            TIMESTAMPTZ NULL,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT sessions_identity_fk FOREIGN KEY (identity_id) REFERENCES identities (identity_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT sessions_customer_fk FOREIGN KEY (customer_profile_id) REFERENCES customer_profiles (customer_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT sessions_rider_fk FOREIGN KEY (rider_profile_id) REFERENCES rider_profiles (rider_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT sessions_admin_fk FOREIGN KEY (admin_profile_id) REFERENCES admin_profiles (admin_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT sessions_profile_type_chk CHECK (active_profile_type IN ('CUSTOMER', 'RIDER', 'ADMIN')),
  CONSTRAINT sessions_exactly_one_profile_chk CHECK (
    (active_profile_type = 'CUSTOMER'
      AND customer_profile_id IS NOT NULL
      AND rider_profile_id IS NULL
      AND admin_profile_id IS NULL)
    OR (active_profile_type = 'RIDER'
      AND rider_profile_id IS NOT NULL
      AND customer_profile_id IS NULL
      AND admin_profile_id IS NULL)
    OR (active_profile_type = 'ADMIN'
      AND admin_profile_id IS NOT NULL
      AND customer_profile_id IS NULL
      AND rider_profile_id IS NULL)
  )
);

CREATE INDEX sessions_identity_idx ON sessions (identity_id);
CREATE INDEX sessions_refresh_hash_idx ON sessions (refresh_token_hash)
  WHERE refresh_token_hash IS NOT NULL;

CREATE TABLE customer_saved_addresses (
  saved_address_id      UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  customer_profile_id   UUID NOT NULL,
  label                 TEXT NULL,
  address_text          TEXT NOT NULL,
  latitude              NUMERIC(9, 6) NULL,
  longitude             NUMERIC(9, 6) NULL,
  zone_id               UUID NULL,
  deactivated_at        TIMESTAMPTZ NULL,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT saved_addresses_customer_fk FOREIGN KEY (customer_profile_id) REFERENCES customer_profiles (customer_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT saved_addresses_zone_fk FOREIGN KEY (zone_id) REFERENCES zones (zone_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
);

CREATE INDEX saved_addresses_customer_idx ON customer_saved_addresses (customer_profile_id);

COMMENT ON TABLE customer_saved_addresses IS 'Reusable addresses. Booked trips copy location onto order_stops.';
