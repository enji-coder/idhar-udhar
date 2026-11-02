-- Booking-time package size and vehicle limit snapshots.
-- New orders copy the category size and weight text that were checked at insert.
-- Existing rows stay vehicle_limits_snapshotted = false. Their original limits
-- are unknown, so this migration does not copy vehicle_categories onto them.
-- Status, rider, and removal updates do not change these columns.

ALTER TABLE orders
  ADD COLUMN package_size_cm NUMERIC(10, 1) NULL,
  ADD COLUMN vehicle_size_limit_snapshot TEXT NULL,
  ADD COLUMN vehicle_weight_capacity_snapshot TEXT NULL,
  ADD COLUMN vehicle_limits_snapshotted BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE orders
  ADD CONSTRAINT orders_package_size_chk CHECK (
    package_size_cm IS NULL OR package_size_cm > 0
  );

COMMENT ON COLUMN orders.package_size_cm IS
  'Customer package size in centimetres accepted at order creation. Null when the customer sent none, or when the order predates this column.';
COMMENT ON COLUMN orders.vehicle_size_limit_snapshot IS
  'vehicle_categories.size copied at order creation. Null with vehicle_limits_snapshotted = true means the category had no size text. Null with the flag false means the original limit is unknown.';
COMMENT ON COLUMN orders.vehicle_weight_capacity_snapshot IS
  'vehicle_categories.weight_capacity copied at order creation. Null with vehicle_limits_snapshotted = true means the category had no weight text. Null with the flag false means the original limit is unknown.';
COMMENT ON COLUMN orders.vehicle_limits_snapshotted IS
  'True when package size and both category limit strings were stored at insert, including when a limit string was null. False for orders created before this column.';

CREATE OR REPLACE FUNCTION orders_reject_vehicle_limit_snapshot_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.package_size_cm IS DISTINCT FROM OLD.package_size_cm
    OR NEW.vehicle_size_limit_snapshot IS DISTINCT FROM OLD.vehicle_size_limit_snapshot
    OR NEW.vehicle_weight_capacity_snapshot IS DISTINCT FROM OLD.vehicle_weight_capacity_snapshot
    OR NEW.vehicle_limits_snapshotted IS DISTINCT FROM OLD.vehicle_limits_snapshotted
  THEN
    RAISE EXCEPTION 'orders vehicle limit snapshots are immutable'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS orders_vehicle_limit_snapshots_immutable ON orders;

CREATE TRIGGER orders_vehicle_limit_snapshots_immutable
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION orders_reject_vehicle_limit_snapshot_change();
