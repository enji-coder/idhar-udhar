import { Injectable } from '@nestjs/common';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';
import { GstBasis } from './gst-math';
import { taxConfigEffectiveAtSql } from './gst-sql';

export type TaxConfigRow = {
  tax_config_version_id: string;
  version: number;
  status: 'DRAFT' | 'ACTIVE' | 'SUPERSEDED';
  gst_rate: string;
  gst_calculation_basis: GstBasis;
  applies_to: string;
  notes: string | null;
  effective_from: Date;
  effective_until: Date | null;
  created_by_admin_profile_id: string;
  created_at: Date;
};

const CONFIG_COLUMNS = `
  tax_config_version_id,
  version,
  status,
  gst_rate::text AS gst_rate,
  gst_calculation_basis,
  applies_to,
  notes,
  effective_from,
  effective_until,
  created_by_admin_profile_id,
  created_at
`;

@Injectable()
export class TaxConfigRepository {
  constructor(private readonly postgres: PostgresService) {}

  async findActive(db: Queryable = this.postgres): Promise<TaxConfigRow | null> {
    const result = await db.query<TaxConfigRow>(
      `
      SELECT ${CONFIG_COLUMNS}
      FROM tax_config_versions
      WHERE status = 'ACTIVE'
      `,
    );
    return result.rows[0] ?? null;
  }

  /**
   * The version published for the instant a financial record was frozen.
   * Used so historical reports keep their original rate and basis.
   */
  async findEffectiveAt(
    at: Date,
    db: Queryable = this.postgres,
  ): Promise<Pick<
    TaxConfigRow,
    'tax_config_version_id' | 'version' | 'gst_rate' | 'gst_calculation_basis'
  > | null> {
    const result = await db.query<
      Pick<
        TaxConfigRow,
        'tax_config_version_id' | 'version' | 'gst_rate' | 'gst_calculation_basis'
      >
    >(
      `
      SELECT
        tax_config_version_id,
        version,
        gst_rate::text AS gst_rate,
        gst_calculation_basis
      FROM (
        ${taxConfigEffectiveAtSql('$1::timestamptz')}
      ) resolved
      `,
      [at.toISOString()],
    );
    return result.rows[0] ?? null;
  }

  async listVersions(db: Queryable = this.postgres): Promise<TaxConfigRow[]> {
    const result = await db.query<TaxConfigRow>(
      `
      SELECT ${CONFIG_COLUMNS}
      FROM tax_config_versions
      ORDER BY version DESC
      `,
    );
    return result.rows;
  }

  /**
   * Publishes version N+1 and supersedes the previous ACTIVE row, mirroring
   * FarePublishRepository. The published payload of the old row is never edited;
   * only its status and effective_until move, which the
   * protect_published_config() trigger permits.
   */
  async publish(
    input: {
      adminProfileId: string;
      gstRate: string;
      gstCalculationBasis: GstBasis;
      effectiveFrom: Date;
      notes: string | null;
    },
    db: Queryable,
  ): Promise<TaxConfigRow> {
    const active = await db.query<{ tax_config_version_id: string }>(
      `
      SELECT tax_config_version_id
      FROM tax_config_versions
      WHERE status = 'ACTIVE'
      FOR UPDATE
      `,
    );
    const maxVersion = await db.query<{ version: string }>(
      `SELECT COALESCE(MAX(version), 0)::text AS version FROM tax_config_versions`,
    );
    const nextVersion = Number.parseInt(maxVersion.rows[0].version, 10) + 1;
    const previousId = active.rows[0]?.tax_config_version_id ?? null;

    const inserted = await db.query<TaxConfigRow>(
      `
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
      VALUES ($1, 'DRAFT', $2::numeric, $3, 'COMPANY_COMMISSION', $4, $5::timestamptz, $6)
      RETURNING ${CONFIG_COLUMNS}
      `,
      [
        nextVersion,
        input.gstRate,
        input.gstCalculationBasis,
        input.notes,
        input.effectiveFrom.toISOString(),
        input.adminProfileId,
      ],
    );
    const newVersionId = inserted.rows[0].tax_config_version_id;

    if (previousId) {
      await db.query(
        `
        UPDATE tax_config_versions
        SET status = 'SUPERSEDED', effective_until = $2::timestamptz
        WHERE tax_config_version_id = $1
          AND status = 'ACTIVE'
        `,
        [previousId, input.effectiveFrom.toISOString()],
      );
    }

    const activated = await db.query<TaxConfigRow>(
      `
      UPDATE tax_config_versions
      SET status = 'ACTIVE'
      WHERE tax_config_version_id = $1
      RETURNING ${CONFIG_COLUMNS}
      `,
      [newVersionId],
    );
    return activated.rows[0];
  }
}

export function serializeTaxConfig(row: TaxConfigRow) {
  return {
    tax_config_version_id: row.tax_config_version_id,
    version: row.version,
    status: row.status,
    gst_rate: row.gst_rate,
    gst_calculation_basis: row.gst_calculation_basis,
    applies_to: row.applies_to,
    notes: row.notes,
    effective_from: row.effective_from.toISOString(),
    effective_until: row.effective_until
      ? row.effective_until.toISOString()
      : null,
    created_by_admin_profile_id: row.created_by_admin_profile_id,
    created_at: row.created_at.toISOString(),
  };
}
