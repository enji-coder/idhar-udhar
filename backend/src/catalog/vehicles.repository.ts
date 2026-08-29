import { Injectable } from '@nestjs/common';
import { PostgresService } from '../database/postgres.service';
import { Queryable } from '../database/queryable';

export type VehicleRow = {
  vehicle_id: string;
  vehicle_category_id: string;
  category_name: string;
  rider_profile_id: string | null;
  rider_phone: string | null;
  registration: string | null;
  two_wheeler_subtype: string | null;
  active: boolean;
  created_at: Date;
  updated_at: Date;
  order_count: number;
};

@Injectable()
export class VehiclesRepository {
  constructor(private readonly postgres: PostgresService) {}

  async list(db: Queryable = this.postgres): Promise<VehicleRow[]> {
    const result = await db.query<VehicleRow>(
      `
      SELECT
        v.vehicle_id,
        v.vehicle_category_id,
        c.name AS category_name,
        v.rider_profile_id,
        i.phone_normalized AS rider_phone,
        v.registration,
        v.two_wheeler_subtype,
        v.active,
        v.created_at,
        v.updated_at,
        (SELECT count(*)::int FROM orders o WHERE o.vehicle_id = v.vehicle_id) AS order_count
      FROM vehicles v
      JOIN vehicle_categories c ON c.vehicle_category_id = v.vehicle_category_id
      LEFT JOIN rider_profiles r ON r.rider_profile_id = v.rider_profile_id
      LEFT JOIN identities i ON i.identity_id = r.identity_id
      ORDER BY v.created_at ASC
      `,
    );
    return result.rows;
  }

  async findById(id: string, db: Queryable = this.postgres): Promise<VehicleRow | null> {
    const result = await db.query<VehicleRow>(
      `
      SELECT
        v.vehicle_id,
        v.vehicle_category_id,
        c.name AS category_name,
        v.rider_profile_id,
        i.phone_normalized AS rider_phone,
        v.registration,
        v.two_wheeler_subtype,
        v.active,
        v.created_at,
        v.updated_at,
        (SELECT count(*)::int FROM orders o WHERE o.vehicle_id = v.vehicle_id) AS order_count
      FROM vehicles v
      JOIN vehicle_categories c ON c.vehicle_category_id = v.vehicle_category_id
      LEFT JOIN rider_profiles r ON r.rider_profile_id = v.rider_profile_id
      LEFT JOIN identities i ON i.identity_id = r.identity_id
      WHERE v.vehicle_id = $1
      `,
      [id],
    );
    return result.rows[0] ?? null;
  }

  async findByRegistration(
    registration: string,
    excludeId: string | null,
    db: Queryable = this.postgres,
  ): Promise<{ vehicle_id: string } | null> {
    const result = await db.query<{ vehicle_id: string }>(
      `
      SELECT vehicle_id
      FROM vehicles
      WHERE regexp_replace(upper(coalesce(registration, '')), '\\s+', '', 'g')
          = regexp_replace(upper($1), '\\s+', '', 'g')
        AND ($2::uuid IS NULL OR vehicle_id <> $2)
      LIMIT 1
      `,
      [registration, excludeId],
    );
    return result.rows[0] ?? null;
  }

  async insert(
    input: {
      vehicleCategoryId: string;
      riderProfileId: string | null;
      registration: string;
      twoWheelerSubtype: string | null;
      active: boolean;
    },
    db: Queryable = this.postgres,
  ): Promise<{ vehicle_id: string }> {
    const result = await db.query<{ vehicle_id: string }>(
      `
      INSERT INTO vehicles (
        vehicle_category_id, rider_profile_id, registration, two_wheeler_subtype, active
      )
      VALUES ($1, $2, $3, $4, $5)
      RETURNING vehicle_id
      `,
      [
        input.vehicleCategoryId,
        input.riderProfileId,
        input.registration,
        input.twoWheelerSubtype,
        input.active,
      ],
    );
    return result.rows[0];
  }

  async update(
    id: string,
    input: {
      vehicleCategoryId: string;
      riderProfileId: string | null;
      registration: string;
      twoWheelerSubtype: string | null;
      active: boolean;
    },
    db: Queryable = this.postgres,
  ): Promise<void> {
    await db.query(
      `
      UPDATE vehicles
      SET vehicle_category_id = $2,
          rider_profile_id = $3,
          registration = $4,
          two_wheeler_subtype = $5,
          active = $6
      WHERE vehicle_id = $1
      `,
      [
        id,
        input.vehicleCategoryId,
        input.riderProfileId,
        input.registration,
        input.twoWheelerSubtype,
        input.active,
      ],
    );
  }

  async delete(id: string, db: Queryable = this.postgres): Promise<void> {
    await db.query(`DELETE FROM vehicles WHERE vehicle_id = $1`, [id]);
  }
}
