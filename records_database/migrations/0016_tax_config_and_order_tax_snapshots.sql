-- Versioned GST configuration for the COMPANY COMMISSION only, plus the per-order tax freeze.
-- Additive. Nothing existing is dropped, altered, or rewritten.
--
-- GST ON THE CUSTOMER FARE REMAINS 0 AND IS NOT TOUCHED BY THIS MIGRATION.
-- order_fare_snapshots.tax = 0, fare_quotes.tax = 0 and invoices.gst_on_fare = 0
-- keep their CHECK constraints. This migration adds a company-side tax treatment
-- of the 15% commission and never a customer-facing tax line.

CREATE TABLE tax_config_versions (
  tax_config_version_id         UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  version                       INTEGER NOT NULL,
  status                        TEXT NOT NULL DEFAULT 'DRAFT',
  gst_rate                      percent_100 NOT NULL,
  gst_calculation_basis         TEXT NOT NULL,
  applies_to                    TEXT NOT NULL DEFAULT 'COMPANY_COMMISSION',
  notes                         TEXT NULL,
  effective_from                TIMESTAMPTZ NOT NULL,
  effective_until               TIMESTAMPTZ NULL,
  created_by_admin_profile_id   UUID NOT NULL,
  created_at                    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT tax_config_version_unique UNIQUE (version),
  CONSTRAINT tax_config_version_positive_chk CHECK (version > 0),
  CONSTRAINT tax_config_status_chk CHECK (status IN ('DRAFT', 'ACTIVE', 'SUPERSEDED')),
  CONSTRAINT tax_config_basis_chk CHECK (gst_calculation_basis IN ('NONE', 'INCLUSIVE', 'EXCLUSIVE')),
  CONSTRAINT tax_config_applies_to_chk CHECK (applies_to IN ('COMPANY_COMMISSION')),
  CONSTRAINT tax_config_none_zero_rate_chk CHECK (
    gst_calculation_basis <> 'NONE' OR gst_rate = 0
  ),
  CONSTRAINT tax_config_created_by_fk FOREIGN KEY (created_by_admin_profile_id) REFERENCES admin_profiles (admin_profile_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
);

CREATE UNIQUE INDEX tax_config_one_active
  ON tax_config_versions ((TRUE))
  WHERE status = 'ACTIVE';

CREATE INDEX tax_config_effective_from_idx ON tax_config_versions (effective_from);
CREATE INDEX tax_config_created_by_idx ON tax_config_versions (created_by_admin_profile_id);

CREATE TRIGGER tax_config_protect_published
  BEFORE UPDATE ON tax_config_versions
  FOR EACH ROW EXECUTE FUNCTION protect_published_config();

COMMENT ON TABLE tax_config_versions IS
  'Versioned GST treatment of the company commission. Publish = INSERT N+1; never edit a used ACTIVE/SUPERSEDED payload. Does NOT authorise GST on the customer fare, which stays 0.';
COMMENT ON COLUMN tax_config_versions.applies_to IS
  'Locked to COMPANY_COMMISSION so this row can never be read as a customer fare tax.';
COMMENT ON COLUMN tax_config_versions.gst_calculation_basis IS
  'INCLUSIVE = commission already contains GST. EXCLUSIVE = GST computed on top of commission and funded from it. NONE = no GST. Basis is never assumed; it is reported alongside every amount.';

CREATE TABLE order_tax_snapshots (
  order_tax_snapshot_id       UUID PRIMARY KEY DEFAULT uuid_generate_v7(),
  finance_snapshot_id         UUID NOT NULL,
  order_id                    UUID NOT NULL,
  tax_config_version_id       UUID NOT NULL,
  gst_rate                    percent_100 NOT NULL,
  gst_calculation_basis       TEXT NOT NULL,
  company_commission_amount   money_inr NOT NULL,
  taxable_company_amount      money_inr NOT NULL,
  gst_amount                  money_inr NOT NULL,
  operational_cost_amount     money_inr NOT NULL,
  company_profit_amount       money_inr NOT NULL,
  frozen_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT order_tax_snap_finance_fk FOREIGN KEY (finance_snapshot_id) REFERENCES order_finance_snapshots (finance_snapshot_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_tax_snap_finance_unique UNIQUE (finance_snapshot_id),
  CONSTRAINT order_tax_snap_order_fk FOREIGN KEY (order_id) REFERENCES orders (order_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_tax_snap_version_fk FOREIGN KEY (tax_config_version_id) REFERENCES tax_config_versions (tax_config_version_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT order_tax_snap_basis_chk CHECK (gst_calculation_basis IN ('NONE', 'INCLUSIVE', 'EXCLUSIVE')),
  CONSTRAINT order_tax_snap_none_zero_chk CHECK (
    gst_calculation_basis <> 'NONE' OR gst_amount = 0
  ),
  CONSTRAINT order_tax_snap_nonneg_chk CHECK (
    company_commission_amount >= 0
    AND taxable_company_amount >= 0
    AND gst_amount >= 0
    AND operational_cost_amount >= 0
  ),
  -- The split invariant depends on the basis and is deliberately not uniform:
  -- INCLUSIVE  the commission is gross, so taxable + gst = commission.
  -- EXCLUSIVE  the commission is the taxable value and gst is notionally on top,
  --            funded out of the commission, so taxable = commission.
  -- NONE       no GST, so taxable = commission.
  CONSTRAINT order_tax_snap_split_chk CHECK (
    (
      gst_calculation_basis = 'INCLUSIVE'
      AND taxable_company_amount + gst_amount = company_commission_amount
    )
    OR (
      gst_calculation_basis IN ('NONE', 'EXCLUSIVE')
      AND taxable_company_amount = company_commission_amount
    )
  ),
  CONSTRAINT order_tax_snap_profit_chk CHECK (
    company_profit_amount = company_commission_amount - gst_amount - operational_cost_amount
  )
);

CREATE TRIGGER order_tax_snapshots_immutable
  BEFORE UPDATE OR DELETE ON order_tax_snapshots
  FOR EACH ROW EXECUTE FUNCTION forbid_update_delete();

CREATE INDEX order_tax_snapshots_order_idx ON order_tax_snapshots (order_id);
CREATE INDEX order_tax_snapshots_frozen_idx ON order_tax_snapshots (frozen_at);
CREATE INDEX order_tax_snapshots_version_idx ON order_tax_snapshots (tax_config_version_id);

COMMENT ON TABLE order_tax_snapshots IS
  'Insert-only GST freeze for one ORIGINAL finance snapshot. Retains the rate and basis that applied at freeze time so later config changes never move an old report.';
COMMENT ON COLUMN order_tax_snapshots.company_commission_amount IS
  'Copied from order_finance_snapshots so the split and profit CHECKs are self-proving without a cross-table lookup.';
COMMENT ON COLUMN order_tax_snapshots.taxable_company_amount IS
  'Under INCLUSIVE this is the commission net of GST. Under EXCLUSIVE and NONE it equals the commission. Always read together with gst_calculation_basis.';
COMMENT ON COLUMN order_tax_snapshots.operational_cost_amount IS
  'Copied unchanged from order_finance_snapshots. Still 50% of company commission, never recomputed on the taxable amount.';
COMMENT ON COLUMN order_tax_snapshots.company_profit_amount IS
  'Commission minus GST minus operational cost. Intentionally has no non-negative CHECK: a high EXCLUSIVE rate can legitimately exhaust the commission, and that must stay visible.';

-- Reporting index: the GST report reads ORIGINAL snapshots over a frozen_at range.
CREATE INDEX finance_snap_original_frozen_idx
  ON order_finance_snapshots (frozen_at)
  WHERE snapshot_kind = 'ORIGINAL';

-- Seed version 1. Inserts zero rows (rather than failing) when no SUPER_ADMIN exists yet;
-- the report then reports TAX_CONFIG_UNAVAILABLE instead of inventing a rate.
-- effective_from is backdated to the earliest existing freeze so pre-existing snapshots
-- resolve deterministically against an immutable published version.
INSERT INTO tax_config_versions (
  version,
  status,
  gst_rate,
  gst_calculation_basis,
  applies_to,
  notes,
  effective_from,
  created_by_admin_profile_id
)
SELECT
  1,
  'ACTIVE',
  18.00,
  'EXCLUSIVE',
  'COMPANY_COMMISSION',
  'Seeded default: 18% EXCLUSIVE on company commission. Pending CA verification. Publish version N+1 to change; this row then becomes SUPERSEDED and immutable.',
  COALESCE(
    (SELECT min(frozen_at) FROM order_finance_snapshots WHERE snapshot_kind = 'ORIGINAL'),
    now()
  ),
  a.admin_profile_id
FROM admin_profiles a
WHERE a.role = 'SUPER_ADMIN'
ORDER BY a.created_at ASC, a.admin_profile_id ASC
LIMIT 1;
