import { Injectable } from '@nestjs/common';
import { formatInr } from '../fare/money';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';

export type PaymentSettingsRow = {
  payment_settings_version_id: string;
  version: number;
  status: string;
  rider_percentage: string;
  company_commission_percentage: string;
  operational_cost_percentage_of_commission: string;
};

export type FinanceSnapshotRow = {
  finance_snapshot_id: string;
  order_id: string;
  snapshot_kind: 'ORIGINAL' | 'REVERSAL' | 'ADJUSTMENT_FREEZE';
  trip_fare: string;
  rider_percentage: string;
  company_commission_percentage: string;
  operational_cost_percentage_of_commission: string;
  rider_amount: string;
  company_commission_amount: string;
  operational_cost_amount: string;
  profit_amount: string;
  payment_settings_version_id: string;
  frozen_at: Date;
};

export type FinanceAllocationRow = {
  trip_fare: string;
  rider_percentage: string;
  company_commission_percentage: string;
  operational_cost_percentage_of_commission: string;
  rider_amount: string;
  company_commission_amount: string;
  operational_cost_amount: string;
  profit_amount: string;
  payment_settings_version_id: string;
};

const SNAP_COLUMNS = `
  finance_snapshot_id,
  order_id,
  snapshot_kind,
  trip_fare::text AS trip_fare,
  rider_percentage::text AS rider_percentage,
  company_commission_percentage::text AS company_commission_percentage,
  operational_cost_percentage_of_commission::text AS operational_cost_percentage_of_commission,
  rider_amount::text AS rider_amount,
  company_commission_amount::text AS company_commission_amount,
  operational_cost_amount::text AS operational_cost_amount,
  profit_amount::text AS profit_amount,
  payment_settings_version_id,
  frozen_at
`;

/**
 * Locked 85/15/50 rounding (matches shared FinanceEngine):
 * rider = ROUND(trip_fare * rider% / 100, 2)
 * company = ROUND(trip_fare - rider, 2)
 * operations = ROUND(company * ops% / 100, 2)
 * profit = ROUND(company - operations, 2)
 *
 * Computed in PostgreSQL NUMERIC. Remainder paise after ROUND stay with
 * company (vs rider) and profit (vs operations). No new tie-break.
 */
const ALLOCATE_SELECT = `
  ROUND(s.trip_fare * s.rider_percentage / 100, 2) AS rider_amount,
  ROUND(
    s.trip_fare - ROUND(s.trip_fare * s.rider_percentage / 100, 2),
    2
  ) AS company_commission_amount,
  ROUND(
    ROUND(s.trip_fare - ROUND(s.trip_fare * s.rider_percentage / 100, 2), 2)
    * s.operational_cost_percentage_of_commission / 100,
    2
  ) AS operational_cost_amount,
  ROUND(
    ROUND(s.trip_fare - ROUND(s.trip_fare * s.rider_percentage / 100, 2), 2)
    - ROUND(
      ROUND(s.trip_fare - ROUND(s.trip_fare * s.rider_percentage / 100, 2), 2)
      * s.operational_cost_percentage_of_commission / 100,
      2
    ),
    2
  ) AS profit_amount
`;

@Injectable()
export class FinanceRepository {
  constructor(private readonly postgres: PostgresService) {}

  async findActiveSettings(
    db: Queryable = this.postgres,
  ): Promise<PaymentSettingsRow | null> {
    const result = await db.query<PaymentSettingsRow>(
      `
      SELECT
        payment_settings_version_id,
        version,
        status,
        rider_percentage::text AS rider_percentage,
        company_commission_percentage::text AS company_commission_percentage,
        operational_cost_percentage_of_commission::text AS operational_cost_percentage_of_commission
      FROM payment_settings_versions
      WHERE status = 'ACTIVE'
      `,
    );
    return result.rows[0] ?? null;
  }

  async allocate(
    tripFare: string,
    db: Queryable = this.postgres,
  ): Promise<FinanceAllocationRow | null> {
    const result = await db.query<FinanceAllocationRow>(
      `
      SELECT
        trip_fare::text AS trip_fare,
        rider_percentage::text AS rider_percentage,
        company_commission_percentage::text AS company_commission_percentage,
        operational_cost_percentage_of_commission::text AS operational_cost_percentage_of_commission,
        rider_amount::text AS rider_amount,
        company_commission_amount::text AS company_commission_amount,
        operational_cost_amount::text AS operational_cost_amount,
        profit_amount::text AS profit_amount,
        payment_settings_version_id
      FROM (
        SELECT
          s.trip_fare,
          s.rider_percentage,
          s.company_commission_percentage,
          s.operational_cost_percentage_of_commission,
          ${ALLOCATE_SELECT},
          s.payment_settings_version_id
        FROM (
          SELECT
            $1::numeric(12,2) AS trip_fare,
            v.rider_percentage,
            v.company_commission_percentage,
            v.operational_cost_percentage_of_commission,
            v.payment_settings_version_id
          FROM payment_settings_versions v
          WHERE v.status = 'ACTIVE'
        ) s
      ) calc
      `,
      [tripFare],
    );
    return result.rows[0] ?? null;
  }

  async insertOriginalFromFareSnapshot(
    orderId: string,
    db: Queryable,
  ): Promise<FinanceSnapshotRow | null> {
    const result = await db.query<FinanceSnapshotRow>(
      `
      INSERT INTO order_finance_snapshots (
        order_id,
        snapshot_kind,
        trip_fare,
        rider_percentage,
        company_commission_percentage,
        operational_cost_percentage_of_commission,
        rider_amount,
        company_commission_amount,
        operational_cost_amount,
        profit_amount,
        payment_settings_version_id
      )
      SELECT
        $1,
        'ORIGINAL',
        s.trip_fare,
        s.rider_percentage,
        s.company_commission_percentage,
        s.operational_cost_percentage_of_commission,
        ${ALLOCATE_SELECT},
        s.payment_settings_version_id
      FROM (
        SELECT
          f.trip_fare,
          v.rider_percentage,
          v.company_commission_percentage,
          v.operational_cost_percentage_of_commission,
          v.payment_settings_version_id
        FROM order_fare_snapshots f
        CROSS JOIN payment_settings_versions v
        WHERE f.order_id = $1
          AND v.status = 'ACTIVE'
      ) s
      RETURNING ${SNAP_COLUMNS}
      `,
      [orderId],
    );
    return result.rows[0] ?? null;
  }

  async listByOrder(
    orderId: string,
    db: Queryable = this.postgres,
  ): Promise<FinanceSnapshotRow[]> {
    const result = await db.query<FinanceSnapshotRow>(
      `
      SELECT ${SNAP_COLUMNS}
      FROM order_finance_snapshots
      WHERE order_id = $1
      ORDER BY frozen_at ASC, finance_snapshot_id ASC
      `,
      [orderId],
    );
    return result.rows;
  }

  async listOriginalsForAdmin(
    db: Queryable = this.postgres,
  ): Promise<
    (FinanceSnapshotRow & {
      display_id: string;
      rider_profile_id: string | null;
    })[]
  > {
    const result = await db.query<
      FinanceSnapshotRow & {
        display_id: string;
        rider_profile_id: string | null;
      }
    >(
      `
      SELECT
        s.finance_snapshot_id,
        s.order_id,
        s.snapshot_kind,
        s.trip_fare::text AS trip_fare,
        s.rider_percentage::text AS rider_percentage,
        s.company_commission_percentage::text AS company_commission_percentage,
        s.operational_cost_percentage_of_commission::text AS operational_cost_percentage_of_commission,
        s.rider_amount::text AS rider_amount,
        s.company_commission_amount::text AS company_commission_amount,
        s.operational_cost_amount::text AS operational_cost_amount,
        s.profit_amount::text AS profit_amount,
        s.payment_settings_version_id,
        s.frozen_at,
        o.display_id,
        o.rider_profile_id
      FROM order_finance_snapshots s
      JOIN orders o ON o.order_id = s.order_id
      WHERE s.snapshot_kind = 'ORIGINAL'
      ORDER BY s.frozen_at DESC
      LIMIT 200
      `,
    );
    return result.rows;
  }

  async findOriginal(
    orderId: string,
    db: Queryable = this.postgres,
  ): Promise<FinanceSnapshotRow | null> {
    const result = await db.query<FinanceSnapshotRow>(
      `
      SELECT ${SNAP_COLUMNS}
      FROM order_finance_snapshots
      WHERE order_id = $1 AND snapshot_kind = 'ORIGINAL'
      `,
      [orderId],
    );
    return result.rows[0] ?? null;
  }
}

export function serializeFinanceSnapshot(row: FinanceSnapshotRow) {
  return {
    finance_snapshot_id: row.finance_snapshot_id,
    order_id: row.order_id,
    snapshot_kind: row.snapshot_kind,
    trip_fare: formatInr(row.trip_fare),
    rider_percentage: formatInr(row.rider_percentage),
    company_commission_percentage: formatInr(row.company_commission_percentage),
    operational_cost_percentage_of_commission: formatInr(
      row.operational_cost_percentage_of_commission,
    ),
    rider_amount: formatInr(row.rider_amount),
    company_commission_amount: formatInr(row.company_commission_amount),
    operational_cost_amount: formatInr(row.operational_cost_amount),
    profit_amount: formatInr(row.profit_amount),
    payment_settings_version_id: row.payment_settings_version_id,
    frozen_at: row.frozen_at.toISOString(),
    tax: formatInr('0'),
  };
}

export function serializeAllocation(row: FinanceAllocationRow) {
  return {
    trip_fare: formatInr(row.trip_fare),
    rider_percentage: formatInr(row.rider_percentage),
    company_commission_percentage: formatInr(row.company_commission_percentage),
    operational_cost_percentage_of_commission: formatInr(
      row.operational_cost_percentage_of_commission,
    ),
    rider_amount: formatInr(row.rider_amount),
    company_commission_amount: formatInr(row.company_commission_amount),
    operational_cost_amount: formatInr(row.operational_cost_amount),
    profit_amount: formatInr(row.profit_amount),
    payment_settings_version_id: row.payment_settings_version_id,
    tax: formatInr('0'),
  };
}
