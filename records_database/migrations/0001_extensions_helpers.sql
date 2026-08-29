-- IDHAR UDHAR V1 — extensions, domains, UUID helper
-- Money: NUMERIC(12,2) only. No FLOAT/DOUBLE.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

COMMENT ON EXTENSION pgcrypto IS 'gen_random_bytes for time-sortable UUID v7 defaults';

-- Exact INR amount (rupees, 2 decimal paise). Application stores already-rounded facts.
CREATE DOMAIN money_inr AS NUMERIC(12,2);

COMMENT ON DOMAIN money_inr IS
  'IDHAR UDHAR money: NUMERIC(12,2) INR. 85/15 uses Trip Fare, never this type as a hidden GST or invoice-total rule.';

-- Percents 0–100 inclusive (rider/company shares, ops % of commission).
CREATE DOMAIN percent_100 AS NUMERIC(5,2)
  CONSTRAINT percent_100_range CHECK (VALUE >= 0 AND VALUE <= 100);

-- Time-sortable UUID (RFC 9562 v7). Architecture example: UUID v7.
CREATE OR REPLACE FUNCTION uuid_generate_v7()
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
AS $$
DECLARE
  unix_ts_ms bytea;
  uuid_bytes bytea;
BEGIN
  unix_ts_ms := substring(int8send((extract(epoch FROM clock_timestamp()) * 1000)::bigint) FROM 3);
  uuid_bytes := unix_ts_ms || gen_random_bytes(10);
  uuid_bytes := set_byte(uuid_bytes, 6, (get_byte(uuid_bytes, 6) & 15) | 112);
  uuid_bytes := set_byte(uuid_bytes, 8, (get_byte(uuid_bytes, 8) & 63) | 128);
  RETURN encode(uuid_bytes, 'hex')::uuid;
END;
$$;

COMMENT ON FUNCTION uuid_generate_v7() IS
  'Default PK generator. Clients may supply UUID v7. Type is UUID either way.';

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION forbid_update_delete()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION '% is append-only/immutable and cannot be %', TG_TABLE_NAME, lower(TG_OP)
    USING ERRCODE = 'restrict_violation';
END;
$$;

COMMENT ON FUNCTION forbid_update_delete() IS
  'Financial and history protection: no silent overwrite or hard delete.';
