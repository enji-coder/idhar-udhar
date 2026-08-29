import { Injectable } from '@nestjs/common';
import { PostgresService } from '../database/postgres.service';
import { Queryable } from '../database/queryable';

export type VehicleCategoryRow = {
  vehicle_category_id: string;
  code: string | null;
  name: string;
  active: boolean;
  weight_capacity: string | null;
  size: string | null;
  created_at: Date;
  updated_at: Date;
  base_fare: string | null;
  per_km: string | null;
  initial_minimum: string | null;
  waiting: string | null;
  surge: string | null;
  toll: string | null;
  parking: string | null;
  fare_config_version_id: string | null;
};

export type CategoryUsage = {
  vehicles: number;
  orders: number;
  fare_quotes: number;
  fare_snapshots: number;
  fare_rates: number;
};

const CATEGORY_SELECT = `
  c.vehicle_category_id,
  c.code,
  c.name,
  c.active,
  c.weight_capacity,
  c.size,
  c.created_at,
  c.updated_at,
  r.base_fare::text AS base_fare,
  r.per_km::text AS per_km,
  r.initial_minimum::text AS initial_minimum,
  r.waiting::text AS waiting,
  r.surge::text AS surge,
  r.toll::text AS toll,
  r.parking::text AS parking,
  r.fare_config_version_id
`;

@Injectable()
export class VehicleCategoriesRepository {
  constructor(private readonly postgres: PostgresService) {}

  async list(db: Queryable = this.postgres): Promise<VehicleCategoryRow[]> {
    const result = await db.query<VehicleCategoryRow>(
      `
      SELECT ${CATEGORY_SELECT}
      FROM vehicle_categories c
      LEFT JOIN fare_config_versions v
        ON v.status = 'ACTIVE'
      LEFT JOIN fare_config_version_rates r
        ON r.fare_config_version_id = v.fare_config_version_id
       AND r.vehicle_category_id = c.vehicle_category_id
      ORDER BY c.created_at ASC, c.name ASC
      `,
    );
    return result.rows;
  }

  async findById(
    id: string,
    db: Queryable = this.postgres,
  ): Promise<VehicleCategoryRow | null> {
    const result = await db.query<VehicleCategoryRow>(
      `
      SELECT ${CATEGORY_SELECT}
      FROM vehicle_categories c
      LEFT JOIN fare_config_versions v
        ON v.status = 'ACTIVE'
      LEFT JOIN fare_config_version_rates r
        ON r.fare_config_version_id = v.fare_config_version_id
       AND r.vehicle_category_id = c.vehicle_category_id
      WHERE c.vehicle_category_id = $1
      `,
      [id],
    );
    return result.rows[0] ?? null;
  }

  async findByName(
    name: string,
    excludeId: string | null,
    db: Queryable = this.postgres,
  ): Promise<{ vehicle_category_id: string } | null> {
    const result = await db.query<{ vehicle_category_id: string }>(
      `
      SELECT vehicle_category_id
      FROM vehicle_categories
      WHERE lower(btrim(name)) = lower(btrim($1))
        AND ($2::uuid IS NULL OR vehicle_category_id <> $2)
      LIMIT 1
      `,
      [name, excludeId],
    );
    return result.rows[0] ?? null;
  }

  async insert(
    input: {
      name: string;
      code: string | null;
      active: boolean;
      weight_capacity: string | null;
      size: string | null;
    },
    db: Queryable = this.postgres,
  ): Promise<{ vehicle_category_id: string }> {
    const result = await db.query<{ vehicle_category_id: string }>(
      `
      INSERT INTO vehicle_categories (name, code, active, weight_capacity, size)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING vehicle_category_id
      `,
      [input.name, input.code, input.active, input.weight_capacity, input.size],
    );
    return result.rows[0];
  }

  async update(
    id: string,
    input: {
      name: string;
      code: string | null;
      active: boolean;
      weight_capacity: string | null;
      size: string | null;
    },
    db: Queryable = this.postgres,
  ): Promise<void> {
    await db.query(
      `
      UPDATE vehicle_categories
      SET name = $2,
          code = $3,
          active = $4,
          weight_capacity = $5,
          size = $6
      WHERE vehicle_category_id = $1
      `,
      [id, input.name, input.code, input.active, input.weight_capacity, input.size],
    );
  }

  async usageByCategory(
    db: Queryable = this.postgres,
  ): Promise<Map<string, CategoryUsage>> {
    const result = await db.query<CategoryUsage & { vehicle_category_id: string }>(
      `
      SELECT
        c.vehicle_category_id,
        (SELECT count(*)::int FROM vehicles WHERE vehicle_category_id = c.vehicle_category_id) AS vehicles,
        (SELECT count(*)::int FROM orders WHERE vehicle_category_id = c.vehicle_category_id) AS orders,
        (SELECT count(*)::int FROM fare_quotes WHERE vehicle_category_id = c.vehicle_category_id) AS fare_quotes,
        (SELECT count(*)::int FROM order_fare_snapshots WHERE vehicle_category_id = c.vehicle_category_id) AS fare_snapshots,
        (SELECT count(*)::int FROM fare_config_version_rates WHERE vehicle_category_id = c.vehicle_category_id) AS fare_rates
      FROM vehicle_categories c
      `,
    );
    return new Map(
      result.rows.map(({ vehicle_category_id, ...usage }) => [vehicle_category_id, usage]),
    );
  }

  async usage(id: string, db: Queryable = this.postgres): Promise<CategoryUsage> {
    const result = await db.query<CategoryUsage>(
      `
      SELECT
        (SELECT count(*)::int FROM vehicles WHERE vehicle_category_id = $1) AS vehicles,
        (SELECT count(*)::int FROM orders WHERE vehicle_category_id = $1) AS orders,
        (SELECT count(*)::int FROM fare_quotes WHERE vehicle_category_id = $1) AS fare_quotes,
        (SELECT count(*)::int FROM order_fare_snapshots WHERE vehicle_category_id = $1) AS fare_snapshots,
        (SELECT count(*)::int FROM fare_config_version_rates WHERE vehicle_category_id = $1) AS fare_rates
      `,
      [id],
    );
    return result.rows[0];
  }

  async delete(id: string, db: Queryable = this.postgres): Promise<void> {
    await db.query(`DELETE FROM vehicle_categories WHERE vehicle_category_id = $1`, [id]);
  }
}
