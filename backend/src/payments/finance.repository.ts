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
 * Rounding for whatever split is active (matches shared FinanceEngine):
 * rider = ROUND(trip_fare * rider% / 100, 2)
 * company = ROUND(trip_fare - rider, 2)
 * operations = ROUND(company * operational-cost% / 100, 2)
 * profit = ROUND(company - operations, 2)
 *
 * Operational cost is a percent of company commission, not of trip fare.
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

  /**
   * Freezes a new ORIGINAL row from the confirmed trip fare and the ACTIVE
   * payment-settings version. Does not update an existing snapshot row.
   */
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

  /**
   * Publishes the admin-supplied split as version N+1 and activates it.
   * The caller must pass the transaction client. The table lock, insert,
   * supersede, and activate all run on that client and commit together.
   * The previous ACTIVE row is superseded. Its percentages are not edited.
   * Existing order finance snapshots are not updated.
   */
  async publishVersion(
    adminProfileId: string,
    split: {
      riderPercentage: string;
      companyCommissionPercentage: string;
      operationalCostPercentageOfCommission: string;
    },
    db: Queryable,
  ): Promise<PaymentSettingsRow> {
    await db.query(`LOCK TABLE payment_settings_versions IN SHARE ROW EXCLUSIVE MODE`);
    const active = await db.query<{ payment_settings_version_id: string }>(
      `
      SELECT payment_settings_version_id
      FROM payment_settings_versions
      WHERE status = 'ACTIVE'
      FOR UPDATE
      `,
    );
    const maxVersion = await db.query<{ version: string }>(
      `SELECT COALESCE(MAX(version), 0)::text AS version FROM payment_settings_versions`,
    );
    const nextVersion = Number.parseInt(maxVersion.rows[0].version, 10) + 1;
    const previousId = active.rows[0]?.payment_settings_version_id ?? null;
    const inserted = await db.query<{ payment_settings_version_id: string }>(
      `
      INSERT INTO payment_settings_versions (
        version,
        status,
        rider_percentage,
        company_commission_percentage,
        operational_cost_percentage_of_commission,
        effective_from,
        created_by_admin_profile_id
      )
      VALUES ($1, 'DRAFT', $2, $3, $4, now(), $5)
      RETURNING payment_settings_version_id
      `,
      [
        nextVersion,
        split.riderPercentage,
        split.companyCommissionPercentage,
        split.operationalCostPercentageOfCommission,
        adminProfileId,
      ],
    );
    const newId = inserted.rows[0]?.payment_settings_version_id;
    if (!newId) {
      throw new Error('payment settings version was not inserted');
    }
    if (previousId) {
      await db.query(
        `
        UPDATE payment_settings_versions
        SET status = 'SUPERSEDED', effective_until = now()
        WHERE payment_settings_version_id = $1
          AND status = 'ACTIVE'
        `,
        [previousId],
      );
    }
    const activated = await db.query<PaymentSettingsRow>(
      `
      UPDATE payment_settings_versions
      SET status = 'ACTIVE'
      WHERE payment_settings_version_id = $1
      RETURNING
        payment_settings_version_id,
        version,
        status,
        rider_percentage::text AS rider_percentage,
        company_commission_percentage::text AS company_commission_percentage,
        operational_cost_percentage_of_commission::text AS operational_cost_percentage_of_commission
      `,
      [newId],
    );
    const row = activated.rows[0];
    if (!row || row.status !== 'ACTIVE') {
      throw new Error('payment settings version was not activated');
    }
    return row;
  }
}

const PERCENT_TEXT = /^(?:\d{1,3})(?:\.\d{1,2})?$/;

/** Percent points for the admin form. Not an INR amount. */
function percentageValue(raw: string): number {
  if (!PERCENT_TEXT.test(raw)) {
    throw new Error(`Invalid percentage text: ${raw}`);
  }
  const [whole, frac = ''] = raw.split('.');
  const cents = Number(whole) * 100 + Number((frac + '00').slice(0, 2));
  return cents / 100;
}

export function serializePaymentSettings(row: PaymentSettingsRow) {
  return {
    payment_settings_version_id: row.payment_settings_version_id,
    version: row.version,
    status: row.status,
    rider_percentage: percentageValue(row.rider_percentage),
    company_commission_percentage: percentageValue(row.company_commission_percentage),
    operational_cost_percentage_of_commission: percentageValue(
      row.operational_cost_percentage_of_commission,
    ),
  };
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
