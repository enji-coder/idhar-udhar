-- Invoice is a financial document, not the trip id reprint.
-- Header is money authority; lines are display copies. GST on fare = 0.

CREATE TABLE invoices (
  invoice_id                  UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  invoice_number              TEXT NOT NULL,
  order_id                    UUID NOT NULL,
  status                      TEXT NOT NULL DEFAULT 'DRAFT',
  issued_at                   TIMESTAMPTZ NULL,
  trip_fare                   money_inr NOT NULL,
  discount                    money_inr NOT NULL DEFAULT 0,
  additional_locked_charges   money_inr NOT NULL DEFAULT 0,
  rounding                    money_inr NOT NULL DEFAULT 0,
  billed_total                money_inr NOT NULL,
  customer_paid               money_inr NOT NULL DEFAULT 0,
  receiver_paid               money_inr NOT NULL DEFAULT 0,
  gst_on_fare                 money_inr NOT NULL DEFAULT 0,
  payment_status_snapshot     TEXT NULL,
  pdf_file_id                 UUID NULL,
  emailed_to                  TEXT NULL,
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT invoices_number_unique UNIQUE (invoice_number),
  CONSTRAINT invoices_order_fk FOREIGN KEY (order_id) REFERENCES orders (order_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT invoices_order_unique UNIQUE (order_id),
  CONSTRAINT invoices_pdf_fk FOREIGN KEY (pdf_file_id) REFERENCES stored_files (file_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT invoices_status_chk CHECK (status IN ('DRAFT', 'ISSUED', 'CANCELLED')),
  CONSTRAINT invoices_nonneg_chk CHECK (
    trip_fare >= 0 AND discount >= 0 AND additional_locked_charges >= 0
    AND billed_total >= 0 AND customer_paid >= 0 AND receiver_paid >= 0
  ),
  CONSTRAINT invoices_gst_zero_chk CHECK (gst_on_fare = 0),
  CONSTRAINT invoices_pay_status_chk CHECK (
    payment_status_snapshot IS NULL
    OR payment_status_snapshot IN ('UNPAID', 'PARTIALLY_PAID', 'PAID')
  )
);

CREATE INDEX invoices_issued_idx ON invoices (issued_at);

COMMENT ON TABLE invoices IS
  'Financial document. invoice_number != display_id. billed_total is the full bill, not one payer share. GST on fare = 0. No GSTIN/SAC columns.';
COMMENT ON COLUMN invoices.trip_fare IS 'Copied Trip Fare for display. 85/15 is NOT computed from billed_total.';
COMMENT ON COLUMN invoices.billed_total IS 'Full customer/receiver bill. Never print one payer share as the invoice total.';
COMMENT ON COLUMN invoices.gst_on_fare IS 'Locked 0.';

CREATE TABLE invoice_lines (
  invoice_line_id UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  invoice_id      UUID NOT NULL,
  sequence        INTEGER NOT NULL,
  line_type       TEXT NOT NULL,
  label           TEXT NOT NULL,
  amount          money_inr NOT NULL,
  CONSTRAINT invoice_lines_invoice_fk FOREIGN KEY (invoice_id) REFERENCES invoices (invoice_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT invoice_lines_seq_unique UNIQUE (invoice_id, sequence),
  CONSTRAINT invoice_lines_seq_chk CHECK (sequence >= 0)
);

COMMENT ON TABLE invoice_lines IS 'Copied display lines. Not a second money authority. Header columns are truth.';

CREATE TABLE order_ratings (
  order_rating_id           UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  order_id                  UUID NOT NULL,
  direction                 TEXT NOT NULL,
  from_customer_profile_id  UUID NULL,
  from_rider_profile_id     UUID NULL,
  to_customer_profile_id    UUID NULL,
  to_rider_profile_id       UUID NULL,
  stars                     INTEGER NOT NULL,
  comment                   TEXT NULL,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT order_ratings_order_fk FOREIGN KEY (order_id) REFERENCES orders (order_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_ratings_direction_unique UNIQUE (order_id, direction),
  CONSTRAINT order_ratings_direction_chk CHECK (direction IN ('CUSTOMER_TO_RIDER', 'RIDER_TO_CUSTOMER')),
  CONSTRAINT order_ratings_stars_chk CHECK (stars BETWEEN 1 AND 5),
  CONSTRAINT order_ratings_from_customer_fk FOREIGN KEY (from_customer_profile_id) REFERENCES customer_profiles (customer_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_ratings_from_rider_fk FOREIGN KEY (from_rider_profile_id) REFERENCES rider_profiles (rider_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_ratings_to_customer_fk FOREIGN KEY (to_customer_profile_id) REFERENCES customer_profiles (customer_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_ratings_to_rider_fk FOREIGN KEY (to_rider_profile_id) REFERENCES rider_profiles (rider_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_ratings_parties_chk CHECK (
    (
      direction = 'CUSTOMER_TO_RIDER'
      AND from_customer_profile_id IS NOT NULL
      AND from_rider_profile_id IS NULL
      AND to_rider_profile_id IS NOT NULL
      AND to_customer_profile_id IS NULL
    )
    OR (
      direction = 'RIDER_TO_CUSTOMER'
      AND from_rider_profile_id IS NOT NULL
      AND from_customer_profile_id IS NULL
      AND to_customer_profile_id IS NOT NULL
      AND to_rider_profile_id IS NULL
    )
  )
);

CREATE INDEX order_ratings_order_idx ON order_ratings (order_id);
