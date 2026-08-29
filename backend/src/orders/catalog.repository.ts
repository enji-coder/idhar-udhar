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
      SELECT vehicle_category_id, code, name, active
      FROM vehicle_categories
      WHERE vehicle_category_id = $1
      `,
      [vehicleCategoryId],
    );
    return result.rows[0] ?? null;
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
}
