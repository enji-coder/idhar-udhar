-- Separate immutable shipment reference. Display id stays IU-{CITY}-{10 digits}.
-- CRN is derived once from that display id: IU-CRN-{CITY}-{10 digits}.

CREATE OR REPLACE FUNCTION crn_from_display_id(p_display_id TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_display_id ~ '^IU-[A-Z]{2,5}-[0-9]{10}$'
      THEN regexp_replace(p_display_id, '^IU-', 'IU-CRN-')
    ELSE NULL
  END;
$$;

ALTER TABLE orders ADD COLUMN IF NOT EXISTS crn TEXT;

UPDATE orders
SET crn = crn_from_display_id(display_id)
WHERE crn IS NULL;

ALTER TABLE orders
  ALTER COLUMN crn SET NOT NULL;

ALTER TABLE orders
  DROP CONSTRAINT IF EXISTS orders_crn_unique;

ALTER TABLE orders
  ADD CONSTRAINT orders_crn_unique UNIQUE (crn);

ALTER TABLE orders
  DROP CONSTRAINT IF EXISTS orders_crn_format_chk;

ALTER TABLE orders
  ADD CONSTRAINT orders_crn_format_chk
  CHECK (crn ~ '^IU-CRN-[A-Z]{2,5}-[0-9]{10}$');

CREATE OR REPLACE FUNCTION orders_reject_crn_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.crn IS DISTINCT FROM OLD.crn THEN
    RAISE EXCEPTION 'orders.crn is immutable'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS orders_crn_immutable ON orders;

CREATE TRIGGER orders_crn_immutable
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION orders_reject_crn_change();

COMMENT ON COLUMN orders.crn IS
  'Immutable shipment reference. Unique. Generated once from display_id. Not the primary key.';
