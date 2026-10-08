import { Injectable } from '@nestjs/common';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';

export type CityRow = {
  city_id: string;
  name: string;
  city_code: string;
  active: boolean;
};

export type ZoneRow = {
  zone_id: string;
  city_id: string;
  name: string;
  active: boolean;
};

export type VehicleCategoryRow = {
  vehicle_category_id: string;
  code: string | null;
  name: string;
  active: boolean;
  weight_capacity: string | null;
  size: string | null;
  vehicle_type: string | null;
  vehicle: string | null;
};

export type RiderEligibilityRow = {
  rider_profile_id: string;
  approval_status: string;
  online_status: string;
  cod_operational_status: string;
  deactivated_at: Date | null;
};

@Injectable()
export class CatalogRepository {
  constructor(private readonly postgres: PostgresService) {}

  async findActiveCity(
    cityId: string,
    db: Queryable = this.postgres,
  ): Promise<CityRow | null> {
    const result = await db.query<CityRow>(
      `
      SELECT city_id, name, city_code, active
      FROM cities
      WHERE city_id = $1
      `,
      [cityId],
    );
    return result.rows[0] ?? null;
  }

  async findZone(
    zoneId: string,
    db: Queryable = this.postgres,
  ): Promise<ZoneRow | null> {
    const result = await db.query<ZoneRow>(
      `
      SELECT zone_id, city_id, name, active
      FROM zones
      WHERE zone_id = $1
      `,
      [zoneId],
    );
    return result.rows[0] ?? null;
  }

  async findActiveVehicleCategory(
    vehicleCategoryId: string,
    db: Queryable = this.postgres,
  ): Promise<VehicleCategoryRow | null> {
    const result = await db.query<VehicleCategoryRow>(
      `
      SELECT
        vehicle_category_id, code, name, active, weight_capacity, size,
        vehicle_type, vehicle
      FROM vehicle_categories
      WHERE vehicle_category_id = $1
      `,
      [vehicleCategoryId],
    );
    return result.rows[0] ?? null;
  }

  /**
   * Identity owns one rider profile. Session profile id can lag that row.
   * Location writes and dispatch both use this id.
   */
  async findRiderProfileIdByIdentity(
    identityId: string,
    db: Queryable = this.postgres,
  ): Promise<string | null> {
    const result = await db.query<{ rider_profile_id: string }>(
      `
      SELECT rider_profile_id
      FROM rider_profiles
      WHERE identity_id = $1
      `,
      [identityId],
    );
    return result.rows[0]?.rider_profile_id ?? null;
  }

  async findRider(
    riderProfileId: string,
    db: Queryable = this.postgres,
  ): Promise<RiderEligibilityRow | null> {
    const result = await db.query<RiderEligibilityRow>(
      `
      SELECT
        rider_profile_id,
        approval_status,
        online_status,
        cod_operational_status,
        deactivated_at
      FROM rider_profiles
      WHERE rider_profile_id = $1
      `,
      [riderProfileId],
    );
    return result.rows[0] ?? null;
  }

  /**
   * Online, approved riders with an active vehicle in this category.
   * Distance ranking happens in dispatch using the location store; this query
   * only applies eligibility. The limit is a safety cap, not "first rider".
   */
  async listEligibleOnlineRidersForCategory(
    vehicleCategoryId: string,
    db: Queryable = this.postgres,
    limit = 200,
  ): Promise<string[]> {
    const result = await db.query<{ rider_profile_id: string }>(
      `
      SELECT DISTINCT r.rider_profile_id
      FROM rider_profiles r
      INNER JOIN vehicles v
        ON v.rider_profile_id = r.rider_profile_id
       AND v.active = TRUE
       AND v.vehicle_category_id = $1
      INNER JOIN identities i ON i.identity_id = r.identity_id
      INNER JOIN rider_drivers d ON d.rider_profile_id = r.rider_profile_id
      WHERE r.online_status = 'ONLINE'
        AND r.approval_status = 'APPROVED'
        AND r.deactivated_at IS NULL
        AND length(trim(d.name)) >= 2
        AND d.date_of_birth IS NOT NULL
        AND i.email IS NOT NULL
        AND position('@' IN i.email) > 1
        AND position('.' IN i.email) > position('@' IN i.email)
        AND length(trim(coalesce(v.registration, ''))) >= 6
        AND length(trim(coalesce(v.model, ''))) > 0
        AND length(trim(coalesce(v.color, ''))) > 0
        AND v.manufacturing_year IS NOT NULL
        AND length(trim(coalesce(d.licence_encrypted_or_token, ''))) >= 8
      ORDER BY r.rider_profile_id
      LIMIT $2
      `,
      [vehicleCategoryId, limit],
    );
    return result.rows.map((row) => row.rider_profile_id);
  }

  /** Customer trip card: name, vehicle, and the rider phone already stored on the identity. */
  async findAssignedRiderDisplay(
    riderProfileId: string,
    db: Queryable = this.postgres,
  ): Promise<{
    name: string | null;
    vehicle_registration: string | null;
    vehicle_category_name: string | null;
    phone: string | null;
  } | null> {
    const result = await db.query<{
      name: string | null;
      vehicle_registration: string | null;
      vehicle_category_name: string | null;
      phone: string | null;
    }>(
      `
      SELECT
        d.name,
        v.registration AS vehicle_registration,
        vc.name AS vehicle_category_name,
        i.phone_normalized AS phone
      FROM rider_profiles r
      LEFT JOIN identities i ON i.identity_id = r.identity_id
      LEFT JOIN rider_drivers d ON d.rider_profile_id = r.rider_profile_id
      LEFT JOIN LATERAL (
        SELECT registration, vehicle_category_id
        FROM vehicles
        WHERE rider_profile_id = r.rider_profile_id
          AND active = TRUE
        ORDER BY updated_at DESC NULLS LAST, created_at DESC
        LIMIT 1
      ) v ON TRUE
      LEFT JOIN vehicle_categories vc ON vc.vehicle_category_id = v.vehicle_category_id
      WHERE r.rider_profile_id = $1
      `,
      [riderProfileId],
    );
    return result.rows[0] ?? null;
  }

  /**
   * Same required fields as riderProfileGaps. Used to refuse accept
   * when registration data was never stored.
   */
  async findRiderOnboardingFacts(
    riderProfileId: string,
    db: Queryable = this.postgres,
  ): Promise<{
    name: string | null;
    email: string | null;
    date_of_birth: string | null;
    vehicle_category_name: string | null;
    vehicle_registration: string | null;
    vehicle_model: string | null;
    vehicle_color: string | null;
    manufacturing_year: number | null;
    driving_licence: string | null;
  } | null> {
    const result = await db.query<{
      name: string | null;
      email: string | null;
      date_of_birth: string | null;
      vehicle_category_name: string | null;
      vehicle_registration: string | null;
      vehicle_model: string | null;
      vehicle_color: string | null;
      manufacturing_year: number | null;
      driving_licence: string | null;
    }>(
      `
      SELECT
        d.name,
        i.email,
        d.date_of_birth::text AS date_of_birth,
        vc.name AS vehicle_category_name,
        v.registration AS vehicle_registration,
        v.model AS vehicle_model,
        v.color AS vehicle_color,
        v.manufacturing_year,
        d.licence_encrypted_or_token AS driving_licence
      FROM rider_profiles r
      JOIN identities i ON i.identity_id = r.identity_id
      LEFT JOIN rider_drivers d ON d.rider_profile_id = r.rider_profile_id
      LEFT JOIN LATERAL (
        SELECT registration, model, color, manufacturing_year, vehicle_category_id
        FROM vehicles
        WHERE rider_profile_id = r.rider_profile_id
          AND active = TRUE
        ORDER BY updated_at DESC
        LIMIT 1
      ) v ON TRUE
      LEFT JOIN vehicle_categories vc ON vc.vehicle_category_id = v.vehicle_category_id
      WHERE r.rider_profile_id = $1
      `,
      [riderProfileId],
    );
    const row = result.rows[0];
    if (!row) return null;
    return {
      ...row,
      manufacturing_year:
        row.manufacturing_year == null ? null : Number(row.manufacturing_year),
    };
  }
}
