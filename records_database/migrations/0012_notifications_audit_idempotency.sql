-- Inbox + future worker support. No chat. No push-provider integration.
-- Recipient uses identity (required) plus optional typed profile FKs.

CREATE TABLE notifications (
  notification_id         UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  recipient_identity_id   UUID NOT NULL,
  recipient_profile_type  TEXT NULL,
  customer_profile_id     UUID NULL,
  rider_profile_id        UUID NULL,
  admin_profile_id        UUID NULL,
  type                    TEXT NOT NULL,
  title                   TEXT NULL,
  body                    TEXT NOT NULL,
  order_id                UUID NULL,
  read_at                 TIMESTAMPTZ NULL,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT notifications_identity_fk FOREIGN KEY (recipient_identity_id) REFERENCES identities (identity_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT notifications_customer_fk FOREIGN KEY (customer_profile_id) REFERENCES customer_profiles (customer_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT notifications_rider_fk FOREIGN KEY (rider_profile_id) REFERENCES rider_profiles (rider_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT notifications_admin_fk FOREIGN KEY (admin_profile_id) REFERENCES admin_profiles (admin_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT notifications_order_fk FOREIGN KEY (order_id) REFERENCES orders (order_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT notifications_profile_type_chk CHECK (
    recipient_profile_type IS NULL
    OR recipient_profile_type IN ('CUSTOMER', 'RIDER', 'ADMIN')
  ),
  CONSTRAINT notifications_typed_profile_chk CHECK (
    (
      recipient_profile_type IS NULL
      AND customer_profile_id IS NULL
      AND rider_profile_id IS NULL
      AND admin_profile_id IS NULL
    )
    OR (
      recipient_profile_type = 'CUSTOMER'
      AND customer_profile_id IS NOT NULL
      AND rider_profile_id IS NULL
      AND admin_profile_id IS NULL
    )
    OR (
      recipient_profile_type = 'RIDER'
      AND rider_profile_id IS NOT NULL
      AND customer_profile_id IS NULL
      AND admin_profile_id IS NULL
    )
    OR (
      recipient_profile_type = 'ADMIN'
      AND admin_profile_id IS NOT NULL
      AND customer_profile_id IS NULL
      AND rider_profile_id IS NULL
    )
  )
);

CREATE INDEX notifications_identity_created_idx ON notifications (recipient_identity_id, created_at DESC);
CREATE INDEX notifications_customer_created_idx ON notifications (customer_profile_id, created_at DESC)
  WHERE customer_profile_id IS NOT NULL;
CREATE INDEX notifications_rider_created_idx ON notifications (rider_profile_id, created_at DESC)
  WHERE rider_profile_id IS NOT NULL;
CREATE INDEX notifications_unread_idx ON notifications (recipient_identity_id, created_at DESC)
  WHERE read_at IS NULL;

COMMENT ON TABLE notifications IS
  'Persisted inbox. PK is also the dedupe id. Unread = read_at IS NULL. Push delivery is a sibling table.';

CREATE TABLE notification_preferences (
  notification_preference_id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  identity_id                UUID NOT NULL,
  in_app_enabled             BOOLEAN NOT NULL DEFAULT TRUE,
  push_enabled               BOOLEAN NOT NULL DEFAULT TRUE,
  created_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT notification_preferences_identity_fk FOREIGN KEY (identity_id) REFERENCES identities (identity_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT notification_preferences_identity_unique UNIQUE (identity_id)
);

CREATE TRIGGER notification_preferences_set_updated_at
  BEFORE UPDATE ON notification_preferences
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE notification_preferences IS
  'Future worker/channel flags. Does not invent mute-by-event-type product rules.';

CREATE TABLE notification_deliveries (
  notification_delivery_id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  notification_id          UUID NOT NULL,
  channel                  TEXT NOT NULL,
  status                   TEXT NOT NULL DEFAULT 'PENDING',
  attempt_count            INTEGER NOT NULL DEFAULT 0,
  last_attempt_at          TIMESTAMPTZ NULL,
  last_error               TEXT NULL,
  provider_message_id      TEXT NULL,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT notification_deliveries_notification_fk FOREIGN KEY (notification_id) REFERENCES notifications (notification_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT notification_deliveries_channel_unique UNIQUE (notification_id, channel),
  CONSTRAINT notification_deliveries_channel_chk CHECK (channel IN ('IN_APP', 'PUSH')),
  CONSTRAINT notification_deliveries_status_chk CHECK (status IN ('PENDING', 'SENT', 'FAILED', 'SKIPPED')),
  CONSTRAINT notification_deliveries_attempts_chk CHECK (attempt_count >= 0)
);

CREATE INDEX notification_deliveries_pending_idx ON notification_deliveries (status, created_at)
  WHERE status = 'PENDING';

COMMENT ON TABLE notification_deliveries IS
  'Architecture-ready delivery/retry rows for a future notification worker. No FCM/vendor integration in this phase.';

CREATE TABLE audit_logs (
  audit_log_id          UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  actor_identity_id     UUID NULL,
  actor_profile_id      UUID NULL,
  actor_role            TEXT NULL,
  action                TEXT NOT NULL,
  entity_type           TEXT NOT NULL,
  entity_id             UUID NOT NULL,
  old_value             JSONB NULL,
  new_value             JSONB NULL,
  reason                TEXT NULL,
  request_id            TEXT NULL,
  ip                    TEXT NULL,
  user_agent            TEXT NULL,
  category              TEXT NULL,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT audit_logs_actor_identity_fk FOREIGN KEY (actor_identity_id) REFERENCES identities (identity_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT audit_logs_category_chk CHECK (category IS NULL OR category IN ('ADMIN', 'FINANCIAL'))
);

CREATE INDEX audit_logs_entity_created_idx ON audit_logs (entity_type, entity_id, created_at);

COMMENT ON TABLE audit_logs IS
  'Append-only who/what/old/new/when. entity_id is a logical pointer (no polymorphic FK). Never hard-delete financial audit.';
COMMENT ON COLUMN audit_logs.actor_identity_id IS 'Null means system.';

CREATE TABLE idempotency_keys (
  idempotency_id      UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  scope               TEXT NOT NULL,
  key                 TEXT NOT NULL,
  actor_identity_id   UUID NULL,
  request_hash        TEXT NOT NULL,
  result_entity_id    UUID NULL,
  result_payload      JSONB NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT idempotency_scope_key_unique UNIQUE (scope, key),
  CONSTRAINT idempotency_actor_fk FOREIGN KEY (actor_identity_id) REFERENCES identities (identity_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT idempotency_scope_chk CHECK (scope IN (
    'create-order',
    'accept-offer',
    'payment',
    'webhook',
    'recharge',
    'cod-settlement',
    'cancel',
    'resend',
    'invoice',
    'status'
  ))
);

COMMENT ON TABLE idempotency_keys IS
  'Same scope+key+hash returns original result. Same key different hash rejects. No TTL column — expiration is not defined.';
