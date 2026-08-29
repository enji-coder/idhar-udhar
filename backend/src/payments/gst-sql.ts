/**
 * The single SQL definition of the company-commission GST split.
 *
 * PostgreSQL NUMERIC is the financial authority, so these fragments are the real
 * calculation. gst-math.ts mirrors them in exact BigInt paise purely so the
 * formulas can be unit-tested; gst-reports.e2e-spec.ts asserts the two agree.
 *
 * Both the freeze (order_tax_snapshots insert) and the report read these, so the
 * stored snapshot and a recomputed figure can never diverge.
 *
 * ROUND(numeric, 2) in PostgreSQL rounds half away from zero, matching
 * roundedDiv() in gst-math.ts.
 */

/**
 * Builds the taxable / GST expressions for a commission column and a rate+basis
 * source. Returns raw SQL, so `commission`, `rate` and `basis` must be trusted
 * column references, never user input.
 */
export function gstSplitSql(args: {
  commission: string;
  rate: string;
  basis: string;
}): { taxable: string; gst: string } {
  const { commission, rate, basis } = args;
  const inclusiveTaxable = `ROUND(${commission} * 100 / (100 + ${rate}), 2)`;
  return {
    taxable: `
      CASE
        WHEN ${basis} = 'INCLUSIVE' THEN ${inclusiveTaxable}
        WHEN ${basis} IN ('NONE', 'EXCLUSIVE') THEN ${commission}
        ELSE NULL
      END`,
    gst: `
      CASE
        WHEN ${basis} = 'INCLUSIVE' THEN ${commission} - ${inclusiveTaxable}
        WHEN ${basis} = 'EXCLUSIVE' THEN ROUND(${commission} * ${rate} / 100, 2)
        WHEN ${basis} = 'NONE' THEN 0::numeric(12,2)
        ELSE NULL
      END`,
  };
}

/**
 * Resolves the tax config version in force at a given instant.
 *
 * Only published (ACTIVE or SUPERSEDED) versions are considered, and published
 * payloads are immutable by trigger, so a report over a past period returns the
 * same rate no matter what is published later.
 */
export const TAX_CONFIG_EFFECTIVE_AT_SQL = `
  SELECT
    v.tax_config_version_id,
    v.version,
    v.gst_rate,
    v.gst_calculation_basis
  FROM tax_config_versions v
  WHERE v.status IN ('ACTIVE', 'SUPERSEDED')
    AND v.applies_to = 'COMPANY_COMMISSION'
    AND v.effective_from <= $AT$
    AND (v.effective_until IS NULL OR v.effective_until > $AT$)
  ORDER BY v.effective_from DESC, v.version DESC
  LIMIT 1
`;

/** Substitutes the instant expression into TAX_CONFIG_EFFECTIVE_AT_SQL. */
export function taxConfigEffectiveAtSql(atExpression: string): string {
  return TAX_CONFIG_EFFECTIVE_AT_SQL.replaceAll('$AT$', atExpression);
}
