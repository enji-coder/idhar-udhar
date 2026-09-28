-- Customer package weight captured with the order.
-- Compared with vehicle_categories.weight_capacity when that value is numeric.
-- Fare amounts stay on fare_quotes / order_fare_snapshots. No second fare table.

ALTER TABLE orders
  ADD COLUMN package_weight_kg NUMERIC(10, 3) NULL;

ALTER TABLE orders
  ADD CONSTRAINT orders_package_weight_chk CHECK (
    package_weight_kg IS NULL OR package_weight_kg > 0
  );

COMMENT ON COLUMN orders.package_weight_kg IS
  'Package weight in kilograms for the selected vehicle. Null only for orders created before this column. A numeric vehicle weight_capacity rejects a missing or heavier package.';
