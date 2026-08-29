import { Injectable } from '@nestjs/common';
import { PostgresService } from '../database/postgres.service';
import { Queryable } from '../database/queryable';

@Injectable()
export class FarePublishRepository {
  constructor(private readonly postgres: PostgresService) {}

  async publishCategoryRates(
    input: {
      adminProfileId: string;
      vehicleCategoryId: string;
      base_fare: string;
      per_km: string;
      initial_minimum: string;
      waiting: string;
      surge: string;
      toll: string;
      parking: string;
    },
    db: Queryable = this.postgres,
  ): Promise<string> {
    const active = await db.query<{
      fare_config_version_id: string;
      version: number;
    }>(
      `
      SELECT fare_config_version_id, version
      FROM fare_config_versions
      WHERE status = 'ACTIVE'
      `,
    );
    const maxVersion = await db.query<{ version: string }>(
      `SELECT COALESCE(MAX(version), 0)::text AS version FROM fare_config_versions`,
    );
    const nextVersion = Number.parseInt(maxVersion.rows[0].version, 10) + 1;
    const inserted = await db.query<{ fare_config_version_id: string }>(
      `
      INSERT INTO fare_config_versions (
        version, status, effective_from, created_by_admin_profile_id
      )
      VALUES ($1, 'DRAFT', now(), $2)
      RETURNING fare_config_version_id
      `,
      [nextVersion, input.adminProfileId],
    );
    const newVersionId = inserted.rows[0].fare_config_version_id;
    const previousId = active.rows[0]?.fare_config_version_id ?? null;

    if (previousId) {
      await db.query(
        `
        INSERT INTO fare_config_version_rates (
          fare_config_version_id, vehicle_category_id,
          base_fare, per_km, initial_minimum, waiting, surge, toll, parking
        )
        SELECT
          $1, vehicle_category_id,
          base_fare, per_km, initial_minimum, waiting, surge, toll, parking
        FROM fare_config_version_rates
        WHERE fare_config_version_id = $2
          AND vehicle_category_id <> $3
        `,
        [newVersionId, previousId, input.vehicleCategoryId],
      );
    }

    await db.query(
      `
      INSERT INTO fare_config_version_rates (
        fare_config_version_id, vehicle_category_id,
        base_fare, per_km, initial_minimum, waiting, surge, toll, parking
      )
      VALUES ($1, $2, $3::numeric, $4::numeric, $5::numeric, $6::numeric, $7::numeric, $8::numeric, $9::numeric)
      `,
      [
        newVersionId,
        input.vehicleCategoryId,
        input.base_fare,
        input.per_km,
        input.initial_minimum,
        input.waiting,
        input.surge,
        input.toll,
        input.parking,
      ],
    );

    if (previousId) {
      await db.query(
        `
        UPDATE fare_config_versions
        SET status = 'SUPERSEDED', effective_until = now()
        WHERE fare_config_version_id = $1
          AND status = 'ACTIVE'
        `,
        [previousId],
      );
    }

    await db.query(
      `
      UPDATE fare_config_versions
      SET status = 'ACTIVE'
      WHERE fare_config_version_id = $1
      `,
      [newVersionId],
    );

    return newVersionId;
  }
}
