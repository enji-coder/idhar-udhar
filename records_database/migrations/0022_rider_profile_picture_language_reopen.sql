-- Profile picture reuses stored_files. Language is the rider's own preference.
-- verification_reopened_at is not a status. After an admin reopen, document
-- decisions older than this timestamp no longer count toward approval_status.

ALTER TABLE rider_profiles
  ADD COLUMN profile_picture_file_id UUID NULL,
  ADD COLUMN preferred_language TEXT NULL,
  ADD COLUMN verification_reopened_at TIMESTAMPTZ NULL;

ALTER TABLE rider_profiles
  ADD CONSTRAINT rider_profiles_picture_fk
  FOREIGN KEY (profile_picture_file_id) REFERENCES stored_files (file_id)
  ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE rider_profiles
  ADD CONSTRAINT rider_profiles_language_chk CHECK (
    preferred_language IS NULL
    OR preferred_language IN ('en', 'hi', 'gu')
  );

COMMENT ON COLUMN rider_profiles.profile_picture_file_id IS
  'Private stored_files row. Bytes stay in object storage. Not a public URL.';
COMMENT ON COLUMN rider_profiles.preferred_language IS
  'Rider profile language preference: en, hi, or gu.';
COMMENT ON COLUMN rider_profiles.verification_reopened_at IS
  'When an admin reopened verification. Decisions at or before this time do not satisfy approval.';
