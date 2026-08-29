import { Injectable } from '@nestjs/common';
import { formatInr } from '../fare/money';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';
import { GstBasis } from './gst-math';
import { gstSplitSql, taxConfigEffectiveAtSql } from './gst-sql';

export type OrderTaxSnapshotRow = {
  order_tax_snapshot_id: string;
  finance_snapshot_id: string;
  order_id: string;
  tax_config_version_id: string;
  gst_rate: string;
  gst_calculation_basis: GstBasis;
  company_commission_amount: string;
  taxable_company_amount: string;
  gst_amount: string;
  operational_cost_amount: string;
  company_profit_amount: string;
  frozen_at: Date;
};

const TAX_SNAP_COLUMNS = `
  order_tax_snapshot_id,
  finance_snapshot_id,
  order_id,
  tax_config_version_id,
  gst_rate::text AS gst_rate,
  gst_calculation_basis,
  company_commission_amount::text AS company_commission_amount,
  taxable_company_amount::text AS taxable_company_amount,
  gst_amount::text AS gst_amount,
  operational_cost_amount::text AS operational_cost_amount,
  company_profit_amount::text AS company_profit_amount,
  frozen_at
`;

const SPLIT = gstSplitSql({
  commission: 's.company_commission_amount',
  rate: 't.gst_rate',
  basis: 't.gst_calculation_basis',
});

@Injectable()
export class OrderTaxSnapshotRepository {
  constructor(private readonly postgres: PostgresService) {}

  async findByFinanceSnapshot(
    financeSnapshotId: string,
    db: Queryable = this.postgres,
  ): Promise<OrderTaxSnapshotRow | null> {
    const result = await db.query<OrderTaxSnapshotRow>(
      `
      SELECT ${TAX_SNAP_COLUMNS}
      FROM order_tax_snapshots
      WHERE finance_snapshot_id = $1
      `,
      [financeSnapshotId],
    );
    return result.rows[0] ?? null;
  }

  /**
   * Freezes the GST treatment for an already-frozen finance snapshot.
   *
   * Amounts come from the immutable order_finance_snapshots row, and the rate
   * and basis come from the tax config published for that row's frozen_at.
   * Nothing about the 85/15 split or the operational cost is recomputed here.
   *
   * Returns null when no tax config version covers frozen_at, so the caller can
   * report TAX_CONFIG_UNAVAILABLE rather than assume a rate.
   */
  async insertForFinanceSnapshot(
    financeSnapshotId: string,
    db: Queryable,
  ): Promise<OrderTaxSnapshotRow | null> {
    const result = await db.query<OrderTaxSnapshotRow>(
      `
      INSERT INTO order_tax_snapshots (
        finance_snapshot_id,
        order_id,
        tax_config_version_id,
        gst_rate,
        gst_calculation_basis,
        company_commission_amount,
        taxable_company_amount,
        gst_amount,
        operational_cost_amount,
        company_profit_amount
      )
      SELECT
        s.finance_snapshot_id,
        s.order_id,
        t.tax_config_version_id,
        t.gst_rate,
        t.gst_calculation_basis,
        s.company_commission_amount,
        ${SPLIT.taxable},
        ${SPLIT.gst},
        s.operational_cost_amount,
        s.company_commission_amount - (${SPLIT.gst}) - s.operational_cost_amount
      FROM order_finance_snapshots s
      CROSS JOIN LATERAL (
        ${taxConfigEffectiveAtSql('s.frozen_at')}
      ) t
      WHERE s.finance_snapshot_id = $1
      RETURNING ${TAX_SNAP_COLUMNS}
      `,
      [financeSnapshotId],
    );
    return result.rows[0] ?? null;
  }
}

export function serializeOrderTaxSnapshot(row: OrderTaxSnapshotRow) {
  return {
    order_tax_snapshot_id: row.order_tax_snapshot_id,
    finance_snapshot_id: row.finance_snapshot_id,
    order_id: row.order_id,
    tax_config_version_id: row.tax_config_version_id,
    gst_rate: row.gst_rate,
    gst_calculation_basis: row.gst_calculation_basis,
    company_commission_amount: formatInr(row.company_commission_amount),
    taxable_company_amount: formatInr(row.taxable_company_amount),
    gst_amount: formatInr(row.gst_amount),
    operational_cost_amount: formatInr(row.operational_cost_amount),
    company_profit_amount: formatInr(row.company_profit_amount),
    frozen_at: row.frozen_at.toISOString(),
  };
}
