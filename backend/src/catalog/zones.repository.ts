import { Injectable } from '@nestjs/common';
import { PostgresService } from '../database/postgres.service';
import { Queryable } from '../database/queryable';

export type ZoneRow = {
  zone_id: string;
  city_id: string;
  city_code: string;
  city_name: string;
  name: string;
  active: boolean;
  created_at: Date;
  rider_count: number;
};

@Injectable()
export class ZonesRepository {
  constructor(private readonly postgres: PostgresService) {}

  async list(db: Queryable = this.postgres): Promise<ZoneRow[]> {
    const result = await db.query<ZoneRow>(
      `
      SELECT
        z.zone_id,
        z.city_id,
        c.city_code,
        c.name AS city_name,
        z.name,
        z.active,
        z.created_at,
        (
          SELECT count(*)::int
          FROM rider_profiles r
          WHERE r.home_zone_id = z.zone_id
            AND r.deactivated_at IS NULL
        ) AS rider_count
      FROM zones z
      JOIN cities c ON c.city_id = z.city_id
      ORDER BY z.created_at ASC, z.name ASC
      `,
    );
    return result.rows;
  }

  async findById(id: string, db: Queryable = this.postgres): Promise<ZoneRow | null> {
    const result = await db.query<ZoneRow>(
      `
      SELECT
        z.zone_id,
        z.city_id,
        c.city_code,
        c.name AS city_name,
        z.name,
        z.active,
        z.created_at,
        (
          SELECT count(*)::int
          FROM rider_profiles r
          WHERE r.home_zone_id = z.zone_id
            AND r.deactivated_at IS NULL
        ) AS rider_count
      FROM zones z
      JOIN cities c ON c.city_id = z.city_id
      WHERE z.zone_id = $1
      `,
      [id],
    );
    return result.rows[0] ?? null;
  }

  async findLaunchCity(db: Queryable = this.postgres): Promise<{
    city_id: string;
    city_code: string;
  } | null> {
    const result = await db.query<{ city_id: string; city_code: string }>(
      `
      SELECT city_id, city_code
      FROM cities
      WHERE city_code = 'AMD' AND active = TRUE
      LIMIT 1
      `,
    );
    return result.rows[0] ?? null;
  }

  async findByName(
    cityId: string,
    name: string,
    excludeId: string | null,
    db: Queryable = this.postgres,
  ): Promise<{ zone_id: string } | null> {
    const result = await db.query<{ zone_id: string }>(
      `
      SELECT zone_id
      FROM zones
      WHERE city_id = $1
        AND lower(btrim(name)) = lower(btrim($2))
        AND ($3::uuid IS NULL OR zone_id <> $3)
      LIMIT 1
      `,
      [cityId, name, excludeId],
    );
    return result.rows[0] ?? null;
  }

  async insert(
    input: { cityId: string; name: string; active: boolean },
    db: Queryable = this.postgres,
  ): Promise<{ zone_id: string }> {
    const result = await db.query<{ zone_id: string }>(
      `
      INSERT INTO zones (city_id, name, active)
      VALUES ($1, $2, $3)
      RETURNING zone_id
      `,
      [input.cityId, input.name, input.active],
    );
    return result.rows[0];
  }

  async update(
    id: string,
    input: { name: string; active: boolean },
    db: Queryable = this.postgres,
  ): Promise<void> {
    await db.query(
      `UPDATE zones SET name = $2, active = $3 WHERE zone_id = $1`,
      [id, input.name, input.active],
    );
  }

  async riderCount(id: string, db: Queryable = this.postgres): Promise<number> {
    const result = await db.query<{ count: number }>(
      `SELECT count(*)::int AS count FROM rider_profiles WHERE home_zone_id = $1`,
      [id],
    );
    return result.rows[0]?.count ?? 0;
  }

  async delete(id: string, db: Queryable = this.postgres): Promise<void> {
    await db.query(`DELETE FROM zones WHERE zone_id = $1`, [id]);
  }
}
