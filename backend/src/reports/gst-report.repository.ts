import { Injectable } from '@nestjs/common';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';
import { GstBasis } from '../payments/gst-math';
import { gstSplitSql, taxConfigEffectiveAtSql } from '../payments/gst-sql';
import { GroupBy } from './dto/gst-report-query.dto';
import { ResolvedRange } from './date-range';

export type GstReportFilters = {
  order_id?: string;
  display_id?: string;
  customer_profile_id?: string;
  rider_profile_id?: string;
  city_id?: string;
  vehicle_category_id?: string;
  order_status?: string;
  payment_status?: 'UNPAID' | 'PARTIALLY_PAID' | 'PAID';
  payment_method?: 'ONLINE' | 'CASH';
};

export type GstSummaryRow = {
  order_count: string;
  unconfigured_order_count: string;
  total_trip_fare: string;
  total_rider_share: string;
  total_company_commission: string;
  total_taxable_company_amount: string;
  total_gst: string;
  total_operational_cost: string;
  total_company_profit: string;
};

export type GstGroupRow = {
  period: string;
  order_count: string;
  trip_fare: string;
  rider_share: string;
  company_commission: string;
  taxable_company_amount: string;
  gst_amount: string;
  operational_cost: string;
  company_profit: string;
};

export type GstDetailRow = {
  report_date: string;
  frozen_at: Date;
  order_id: string;
  display_id: string;
  finance_snapshot_id: string;
  customer_profile_id: string;
  customer_name: string | null;
  rider_profile_id: string | null;
  rider_phone: string | null;
  city_code: string | null;
  city_name: string | null;
  vehicle_category_name: string;
  order_status: string;
  payment_status: string | null;
  trip_fare: string;
  rider_percentage: string;
  rider_amount: string;
  company_commission_percentage: string;
  company_commission_amount: string;
  operational_cost_percentage_of_commission: string;
  operational_cost_amount: string;
  gst_rate: string | null;
  gst_basis: GstBasis | null;
  gst_amount: string | null;
  taxable_company_amount: string | null;
  company_profit_amount: string | null;
  tax_frozen: boolean;
  tax_config_version_id: string | null;
};

export type GstRateBreakdownRow = {
  gst_rate: string | null;
  gst_basis: GstBasis | null;
  order_count: string;
  company_commission: string;
  gst_amount: string;
};

/** Guards report memory. The export flags truncation rather than lying by omission. */
export const EXPORT_MAX_ROWS = 50_000;

const FALLBACK_SPLIT = gstSplitSql({
  commission: 'b.company_commission_amount',
  rate: 'tcv.gst_rate',
  basis: 'tcv.gst_calculation_basis',
});

type Scope = { cte: string; params: unknown[] };

@Injectable()
export class GstReportRepository {
  constructor(private readonly postgres: PostgresService) {}

  /**
   * Builds the shared CTE that every report query reads from.
   *
   * Revenue basis: exactly one ORIGINAL order_finance_snapshots row per order,
   * guaranteed unique by finance_snap_one_original. Payment transactions, wallet
   * ledger entries and the COD ledger are deliberately NOT summed as revenue;
   * payments appear only as a derived collection status. That is what keeps COD
   * settlement and partial payments from being double counted.
   */
  private buildScope(range: ResolvedRange, filters: GstReportFilters): Scope {
    const params: unknown[] = [
      range.from_instant,
      range.to_instant,
      range.time_zone,
    ];
    const conditions: string[] = [];

    const add = (sql: string, value: unknown) => {
      params.push(value);
      conditions.push(sql.replace('$?', `$${params.length}`));
    };

    if (filters.order_id) add('o.order_id = $?', filters.order_id);
    if (filters.display_id) {
      add('o.display_id ILIKE $?', `%${filters.display_id}%`);
    }
    if (filters.customer_profile_id) {
      add('o.customer_profile_id = $?', filters.customer_profile_id);
    }
    if (filters.rider_profile_id) {
      add('o.rider_profile_id = $?', filters.rider_profile_id);
    }
    if (filters.city_id) add('o.city_id = $?', filters.city_id);
    if (filters.vehicle_category_id) {
      add('o.vehicle_category_id = $?', filters.vehicle_category_id);
    }
    if (filters.order_status) {
      add('o.canonical_status = $?', filters.order_status);
    }

    const outer: string[] = [];
    if (filters.payment_status) {
      params.push(filters.payment_status);
      outer.push(`e.payment_status = $${params.length}`);
    }
    if (filters.payment_method) {
      params.push(filters.payment_method);
      outer.push(
        `((($${params.length} = 'CASH') AND e.has_cash_paid)
          OR (($${params.length} = 'ONLINE') AND e.has_online_paid))`,
      );
    }

    const cte = `
      WITH base AS (
        SELECT
          s.finance_snapshot_id,
          s.order_id,
          s.frozen_at,
          s.trip_fare,
          s.rider_percentage,
          s.company_commission_percentage,
          s.operational_cost_percentage_of_commission,
          s.rider_amount,
          s.company_commission_amount,
          s.operational_cost_amount,
          o.display_id,
          o.canonical_status,
          o.city_id,
          o.vehicle_category_id,
          o.vehicle_category_name_snapshot,
          o.customer_profile_id,
          o.rider_profile_id
        FROM order_finance_snapshots s
        JOIN orders o ON o.order_id = s.order_id
        WHERE s.snapshot_kind = 'ORIGINAL'
          AND s.frozen_at >= $1::timestamptz
          AND s.frozen_at < $2::timestamptz
          ${conditions.length ? `AND ${conditions.join('\n          AND ')}` : ''}
      ),
      enriched AS (
        SELECT
          b.*,
          (b.frozen_at AT TIME ZONE $3::text)::date AS report_date,
          (ots.order_tax_snapshot_id IS NOT NULL) AS tax_frozen,
          COALESCE(ots.tax_config_version_id, tcv.tax_config_version_id) AS tax_config_version_id,
          COALESCE(ots.gst_rate, tcv.gst_rate) AS gst_rate,
          COALESCE(ots.gst_calculation_basis, tcv.gst_calculation_basis) AS gst_basis,
          CASE
            WHEN ots.order_tax_snapshot_id IS NOT NULL THEN ots.taxable_company_amount
            ELSE (${FALLBACK_SPLIT.taxable})
          END AS taxable_company_amount,
          CASE
            WHEN ots.order_tax_snapshot_id IS NOT NULL THEN ots.gst_amount
            ELSE (${FALLBACK_SPLIT.gst})
          END AS gst_amount,
          cust.display_name AS customer_name,
          rid.phone_normalized AS rider_phone,
          city.city_code,
          city.name AS city_name,
          CASE
            WHEN owed.amount = 0 THEN 'PAID'
            WHEN pay.paid_amount = 0 THEN 'UNPAID'
            WHEN pay.paid_amount = owed.amount THEN 'PAID'
            ELSE 'PARTIALLY_PAID'
          END AS payment_status,
          pay.has_cash_paid,
          pay.has_online_paid
        FROM base b
        LEFT JOIN order_tax_snapshots ots
          ON ots.finance_snapshot_id = b.finance_snapshot_id
        LEFT JOIN LATERAL (
          ${taxConfigEffectiveAtSql('b.frozen_at')}
        ) tcv ON TRUE
        LEFT JOIN customer_profiles cust
          ON cust.customer_profile_id = b.customer_profile_id
        LEFT JOIN rider_profiles rp
          ON rp.rider_profile_id = b.rider_profile_id
        LEFT JOIN identities rid ON rid.identity_id = rp.identity_id
        LEFT JOIN cities city ON city.city_id = b.city_id
        LEFT JOIN order_payment_responsibilities resp
          ON resp.order_id = b.order_id
        LEFT JOIN order_fare_snapshots fare
          ON fare.order_id = b.order_id
        -- Same owed basis the payments module uses: the responsibility split
        -- when it exists, otherwise the confirmed bill.
        LEFT JOIN LATERAL (
          SELECT COALESCE(resp.applicable_bill_total, fare.net_payable, 0)::numeric(12,2) AS amount
        ) owed ON TRUE
        LEFT JOIN LATERAL (
          SELECT
            COALESCE(SUM(CASE
              WHEN t.direction = 'CHARGE' AND t.transaction_status = 'PAID' THEN t.amount
              WHEN t.direction = 'REFUND' AND t.transaction_status = 'REFUNDED' THEN -t.amount
              ELSE 0
            END), 0) AS paid_amount,
            COALESCE(bool_or(t.method = 'CASH' AND t.transaction_status = 'PAID'), FALSE) AS has_cash_paid,
            COALESCE(bool_or(t.method = 'ONLINE' AND t.transaction_status = 'PAID'), FALSE) AS has_online_paid
          FROM payment_transactions t
          WHERE t.order_id = b.order_id
        ) pay ON TRUE
      ),
      scoped AS (
        SELECT
          e.*,
          CASE
            WHEN e.gst_amount IS NULL THEN NULL
            ELSE e.company_commission_amount - e.gst_amount - e.operational_cost_amount
          END AS company_profit_amount
        FROM enriched e
        ${outer.length ? `WHERE ${outer.join('\n          AND ')}` : ''}
      )
    `;

    return { cte, params };
  }

  async summary(
    range: ResolvedRange,
    filters: GstReportFilters,
    db: Queryable = this.postgres,
  ): Promise<GstSummaryRow> {
    const scope = this.buildScope(range, filters);
    const result = await db.query<GstSummaryRow>(
      `
      ${scope.cte}
      SELECT
        count(*)::text AS order_count,
        count(*) FILTER (WHERE gst_basis IS NULL)::text AS unconfigured_order_count,
        COALESCE(SUM(trip_fare), 0)::text AS total_trip_fare,
        COALESCE(SUM(rider_amount), 0)::text AS total_rider_share,
        COALESCE(SUM(company_commission_amount), 0)::text AS total_company_commission,
        COALESCE(SUM(taxable_company_amount), 0)::text AS total_taxable_company_amount,
        COALESCE(SUM(gst_amount), 0)::text AS total_gst,
        COALESCE(SUM(operational_cost_amount), 0)::text AS total_operational_cost,
        COALESCE(SUM(company_profit_amount), 0)::text AS total_company_profit
      FROM scoped
      `,
      scope.params,
    );
    return result.rows[0];
  }

  async grouped(
    range: ResolvedRange,
    filters: GstReportFilters,
    groupBy: GroupBy,
    db: Queryable = this.postgres,
  ): Promise<GstGroupRow[]> {
    const scope = this.buildScope(range, filters);
    const periodExpr =
      groupBy === 'month'
        ? `to_char(date_trunc('month', report_date), 'YYYY-MM')`
        : `to_char(report_date, 'YYYY-MM-DD')`;
    const result = await db.query<GstGroupRow>(
      `
      ${scope.cte}
      SELECT
        ${periodExpr} AS period,
        count(*)::text AS order_count,
        COALESCE(SUM(trip_fare), 0)::text AS trip_fare,
        COALESCE(SUM(rider_amount), 0)::text AS rider_share,
        COALESCE(SUM(company_commission_amount), 0)::text AS company_commission,
        COALESCE(SUM(taxable_company_amount), 0)::text AS taxable_company_amount,
        COALESCE(SUM(gst_amount), 0)::text AS gst_amount,
        COALESCE(SUM(operational_cost_amount), 0)::text AS operational_cost,
        COALESCE(SUM(company_profit_amount), 0)::text AS company_profit
      FROM scoped
      GROUP BY 1
      ORDER BY 1 ASC
      `,
      scope.params,
    );
    return result.rows;
  }

  /** Which rates and bases actually produced the numbers in this period. */
  async rateBreakdown(
    range: ResolvedRange,
    filters: GstReportFilters,
    db: Queryable = this.postgres,
  ): Promise<GstRateBreakdownRow[]> {
    const scope = this.buildScope(range, filters);
    const result = await db.query<GstRateBreakdownRow>(
      `
      ${scope.cte}
      SELECT
        gst_rate::text AS gst_rate,
        gst_basis,
        count(*)::text AS order_count,
        COALESCE(SUM(company_commission_amount), 0)::text AS company_commission,
        COALESCE(SUM(gst_amount), 0)::text AS gst_amount
      FROM scoped
      GROUP BY gst_rate, gst_basis
      ORDER BY gst_basis NULLS LAST, gst_rate
      `,
      scope.params,
    );
    return result.rows;
  }

  async detail(
    range: ResolvedRange,
    filters: GstReportFilters,
    page: { limit: number; offset: number },
    db: Queryable = this.postgres,
  ): Promise<GstDetailRow[]> {
    const scope = this.buildScope(range, filters);
    const limitParam = scope.params.length + 1;
    const offsetParam = scope.params.length + 2;
    const result = await db.query<GstDetailRow>(
      `
      ${scope.cte}
      SELECT
        to_char(report_date, 'YYYY-MM-DD') AS report_date,
        frozen_at,
        order_id,
        display_id,
        finance_snapshot_id,
        customer_profile_id,
        customer_name,
        rider_profile_id,
        rider_phone,
        city_code,
        city_name,
        vehicle_category_name_snapshot AS vehicle_category_name,
        canonical_status AS order_status,
        payment_status,
        trip_fare::text AS trip_fare,
        rider_percentage::text AS rider_percentage,
        rider_amount::text AS rider_amount,
        company_commission_percentage::text AS company_commission_percentage,
        company_commission_amount::text AS company_commission_amount,
        operational_cost_percentage_of_commission::text AS operational_cost_percentage_of_commission,
        operational_cost_amount::text AS operational_cost_amount,
        gst_rate::text AS gst_rate,
        gst_basis,
        gst_amount::text AS gst_amount,
        taxable_company_amount::text AS taxable_company_amount,
        company_profit_amount::text AS company_profit_amount,
        tax_frozen,
        tax_config_version_id
      FROM scoped
      ORDER BY frozen_at DESC, finance_snapshot_id DESC
      LIMIT $${limitParam} OFFSET $${offsetParam}
      `,
      [...scope.params, page.limit, page.offset],
    );
    return result.rows;
  }
}
