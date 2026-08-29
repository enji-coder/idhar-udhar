-- Object-storage metadata only. No bytea file payloads.
-- KYC / vehicle papers / bank / UPI.

CREATE TABLE stored_files (
  file_id                 UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  storage_key             TEXT NOT NULL,
  content_type            TEXT NULL,
  size_bytes              INTEGER NULL,
  checksum                TEXT NULL,
  purpose                 TEXT NOT NULL,
  virus_scan_status       TEXT NULL,
  created_by_identity_id  UUID NULL,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT stored_files_storage_key_unique UNIQUE (storage_key),
  CONSTRAINT stored_files_size_chk CHECK (size_bytes IS NULL OR size_bytes >= 0),
  CONSTRAINT stored_files_purpose_chk CHECK (purpose IN ('KYC', 'POD', 'INVOICE_PDF', 'OTHER')),
  CONSTRAINT stored_files_scan_chk CHECK (
    virus_scan_status IS NULL
    OR virus_scan_status IN ('PENDING', 'CLEAN', 'INFECTED', 'SKIPPED')
  ),
  CONSTRAINT stored_files_created_by_fk FOREIGN KEY (created_by_identity_id) REFERENCES identities (identity_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
);

COMMENT ON TABLE stored_files IS 'Metadata only. Bytes live in object storage. virus_scan_status is ARCHITECTURE READY.';

CREATE TABLE vehicles (
  vehicle_id            UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  vehicle_category_id   UUID NOT NULL,
  rider_profile_id      UUID NULL,
  registration          TEXT NULL,
  two_wheeler_subtype   TEXT NULL,
  active                BOOLEAN NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT vehicles_category_fk FOREIGN KEY (vehicle_category_id) REFERENCES vehicle_categories (vehicle_category_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT vehicles_rider_fk FOREIGN KEY (rider_profile_id) REFERENCES rider_profiles (rider_profile_id)
    ON DELETE SET NULL ON UPDATE RESTRICT,
  CONSTRAINT vehicles_subtype_chk CHECK (
    two_wheeler_subtype IS NULL OR two_wheeler_subtype IN ('BIKE', 'SCOOTER')
  )
);

CREATE INDEX vehicles_rider_idx ON vehicles (rider_profile_id);
CREATE INDEX vehicles_category_idx ON vehicles (vehicle_category_id);

CREATE TRIGGER vehicles_set_updated_at
  BEFORE UPDATE ON vehicles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE rider_drivers (
  rider_driver_id             UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  rider_profile_id            UUID NOT NULL,
  name                        TEXT NULL,
  mobile                      TEXT NULL,
  date_of_birth               DATE NULL,
  licence_masked              TEXT NULL,
  licence_encrypted_or_token  TEXT NULL,
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT rider_drivers_rider_fk FOREIGN KEY (rider_profile_id) REFERENCES rider_profiles (rider_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT rider_drivers_rider_unique UNIQUE (rider_profile_id)
);

COMMENT ON TABLE rider_drivers IS 'Licence-holder placeholder. V1 one driver per rider. Not a fleet product.';
COMMENT ON COLUMN rider_drivers.licence_encrypted_or_token IS 'National ID at rest: encrypt/tokenize. Never log full licence.';

CREATE TABLE rider_documents (
  rider_document_id           UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  rider_profile_id            UUID NOT NULL,
  document_type               TEXT NOT NULL,
  file_id                     UUID NOT NULL,
  status                      TEXT NOT NULL DEFAULT 'UPLOADED',
  reviewer_admin_profile_id   UUID NULL,
  reviewed_at                 TIMESTAMPTZ NULL,
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT rider_documents_rider_fk FOREIGN KEY (rider_profile_id) REFERENCES rider_profiles (rider_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT rider_documents_file_fk FOREIGN KEY (file_id) REFERENCES stored_files (file_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT rider_documents_reviewer_fk FOREIGN KEY (reviewer_admin_profile_id) REFERENCES admin_profiles (admin_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT rider_documents_status_chk CHECK (status IN ('UPLOADED', 'APPROVED', 'REJECTED'))
);

CREATE INDEX rider_documents_rider_idx ON rider_documents (rider_profile_id);

CREATE TABLE vehicle_documents (
  vehicle_document_id         UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  vehicle_id                  UUID NOT NULL,
  document_type               TEXT NOT NULL,
  file_id                     UUID NOT NULL,
  status                      TEXT NOT NULL DEFAULT 'UPLOADED',
  reviewer_admin_profile_id   UUID NULL,
  reviewed_at                 TIMESTAMPTZ NULL,
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT vehicle_documents_vehicle_fk FOREIGN KEY (vehicle_id) REFERENCES vehicles (vehicle_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT vehicle_documents_file_fk FOREIGN KEY (file_id) REFERENCES stored_files (file_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT vehicle_documents_reviewer_fk FOREIGN KEY (reviewer_admin_profile_id) REFERENCES admin_profiles (admin_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT vehicle_documents_status_chk CHECK (status IN ('UPLOADED', 'APPROVED', 'REJECTED'))
);

CREATE INDEX vehicle_documents_vehicle_idx ON vehicle_documents (vehicle_id);

CREATE TABLE rider_bank_accounts (
  bank_account_id               UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  rider_profile_id              UUID NOT NULL,
  holder_name                   TEXT NOT NULL,
  account_masked                TEXT NOT NULL,
  account_encrypted_or_token    TEXT NOT NULL,
  ifsc_or_bank                  TEXT NULL,
  is_current                    BOOLEAN NOT NULL DEFAULT FALSE,
  verification_status           TEXT NULL,
  created_at                    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT rider_bank_rider_fk FOREIGN KEY (rider_profile_id) REFERENCES rider_profiles (rider_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
);

CREATE UNIQUE INDEX rider_bank_one_current
  ON rider_bank_accounts (rider_profile_id)
  WHERE is_current = TRUE;

CREATE INDEX rider_bank_rider_idx ON rider_bank_accounts (rider_profile_id);

CREATE TABLE rider_upis (
  rider_upi_id            UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  rider_profile_id        UUID NOT NULL,
  vpa_masked              TEXT NOT NULL,
  vpa_encrypted_or_token  TEXT NOT NULL,
  is_current              BOOLEAN NOT NULL DEFAULT FALSE,
  verification_status     TEXT NULL,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT rider_upis_rider_fk FOREIGN KEY (rider_profile_id) REFERENCES rider_profiles (rider_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
);

CREATE UNIQUE INDEX rider_upis_one_current
  ON rider_upis (rider_profile_id)
  WHERE is_current = TRUE;

CREATE INDEX rider_upis_rider_idx ON rider_upis (rider_profile_id);
