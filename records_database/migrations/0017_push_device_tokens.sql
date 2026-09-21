-- FCM device token registry. Required for PushProvider=fcm fan-out.
-- One physical device token is unique; an identity/profile may have many active tokens.
-- Never log fcm_token. Bytes are not stored here.

CREATE TABLE push_device_tokens (
  push_device_token_id  UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  identity_id           UUID NOT NULL,
  profile_type          TEXT NOT NULL,
  customer_profile_id   UUID NULL,
  rider_profile_id      UUID NULL,
  admin_profile_id      UUID NULL,
  fcm_token             TEXT NOT NULL,
  platform              TEXT NULL,
  active                BOOLEAN NOT NULL DEFAULT TRUE,
  last_seen_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  deactivated_at        TIMESTAMPTZ NULL,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT push_device_tokens_identity_fk FOREIGN KEY (identity_id) REFERENCES identities (identity_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT push_device_tokens_customer_fk FOREIGN KEY (customer_profile_id) REFERENCES customer_profiles (customer_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT push_device_tokens_rider_fk FOREIGN KEY (rider_profile_id) REFERENCES rider_profiles (rider_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT push_device_tokens_admin_fk FOREIGN KEY (admin_profile_id) REFERENCES admin_profiles (admin_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT push_device_tokens_token_unique UNIQUE (fcm_token),
  CONSTRAINT push_device_tokens_profile_type_chk CHECK (
    profile_type IN ('CUSTOMER', 'RIDER', 'ADMIN')
  ),
  CONSTRAINT push_device_tokens_platform_chk CHECK (
    platform IS NULL OR platform IN ('ANDROID', 'IOS', 'WEB')
  ),
  CONSTRAINT push_device_tokens_token_len_chk CHECK (
    char_length(fcm_token) BETWEEN 32 AND 4096
  ),
  CONSTRAINT push_device_tokens_typed_profile_chk CHECK (
    (
      profile_type = 'CUSTOMER'
      AND customer_profile_id IS NOT NULL
      AND rider_profile_id IS NULL
      AND admin_profile_id IS NULL
    )
    OR (
      profile_type = 'RIDER'
      AND rider_profile_id IS NOT NULL
      AND customer_profile_id IS NULL
      AND admin_profile_id IS NULL
    )
    OR (
      profile_type = 'ADMIN'
      AND admin_profile_id IS NOT NULL
      AND customer_profile_id IS NULL
      AND rider_profile_id IS NULL
    )
  )
);

CREATE INDEX push_device_tokens_identity_active_idx
  ON push_device_tokens (identity_id, profile_type)
  WHERE active = TRUE;

COMMENT ON TABLE push_device_tokens IS
  'FCM registration tokens per authenticated profile. Multiple devices allowed. Never log fcm_token.';
COMMENT ON COLUMN push_device_tokens.fcm_token IS
  'FCM registration token. Sensitive. Required to send; never log or return to other users.';
