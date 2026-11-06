-- One Online → Offline presence session per row.
-- Timestamps are UTC (timestamptz). Daily totals are allocated in Asia/Kolkata
-- by the API, including shifts that cross local midnight.
-- Existing rider_profiles rows are not rewritten.

CREATE TABLE rider_online_sessions (
  session_id        UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  rider_profile_id  UUID NOT NULL,
  started_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at          TIMESTAMPTZ NULL,
  close_reason      TEXT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT rider_online_sessions_rider_fk
    FOREIGN KEY (rider_profile_id) REFERENCES rider_profiles (rider_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT rider_online_sessions_end_chk
    CHECK (ended_at IS NULL OR ended_at >= started_at),
  CONSTRAINT rider_online_sessions_reason_chk
    CHECK (
      close_reason IS NULL
      OR close_reason IN ('OFFLINE', 'PRESENCE_STALE', 'DEACTIVATED')
    )
);

CREATE UNIQUE INDEX rider_online_sessions_one_open
  ON rider_online_sessions (rider_profile_id)
  WHERE ended_at IS NULL;

CREATE INDEX rider_online_sessions_rider_started_idx
  ON rider_online_sessions (rider_profile_id, started_at);

CREATE INDEX rider_online_sessions_started_idx
  ON rider_online_sessions (started_at);

COMMENT ON TABLE rider_online_sessions IS
  'Completed and active rider Online sessions. Open sessions have ended_at NULL. Presence timeout closes them at last_seen_at.';
