import { Injectable } from '@nestjs/common';
import { Queryable } from '../../database/queryable';
import { PostgresService } from '../../database/postgres.service';

export const PROVISIONAL_CUSTOMER_DISPLAY_NAME = 'Customer';

export type IdentityRow = {
  identity_id: string;
  phone_normalized: string;
  email: string | null;
  auth_status: string;
};

export type CustomerProfileRow = {
  customer_profile_id: string;
  identity_id: string;
  display_name: string;
  email: string | null;
  invoice_email: string | null;
  status: string;
  default_city_id: string | null;
};

export type RiderProfileRow = {
  rider_profile_id: string;
  identity_id: string;
  onboarding_kyc_status: string;
  approval_status: string;
  online_status: string;
  home_city_id: string | null;
  home_zone_id: string | null;
  cod_operational_status: string;
  preferred_language: string | null;
  profile_picture_file_id: string | null;
  last_seen_at?: Date | string | null;
};

export type AdminProfileRow = {
  admin_profile_id: string;
  identity_id: string;
  role: string;
  modules: unknown;
  finance_access: boolean;
  payout_approve: boolean;
  city_scope_id: string | null;
  password_hash: string;
  active: boolean;
  email: string | null;
  auth_status: string;
};

@Injectable()
export class IdentityRepository {
  constructor(private readonly postgres: PostgresService) {}

  async findByPhone(
    phoneNormalized: string,
    db: Queryable = this.postgres,
  ): Promise<IdentityRow | null> {
    const result = await db.query<IdentityRow>(
      `
      SELECT identity_id, phone_normalized, email, auth_status
      FROM identities
      WHERE phone_normalized = $1
      `,
      [phoneNormalized],
    );
    return result.rows[0] ?? null;
  }

  async findById(
    identityId: string,
    db: Queryable = this.postgres,
  ): Promise<IdentityRow | null> {
    const result = await db.query<IdentityRow>(
      `
      SELECT identity_id, phone_normalized, email, auth_status
      FROM identities
      WHERE identity_id = $1
      `,
      [identityId],
    );
    return result.rows[0] ?? null;
  }

  async insertPhoneIdentity(
    phoneNormalized: string,
    db: Queryable,
  ): Promise<IdentityRow> {
    const inserted = await db.query<IdentityRow>(
      `
      INSERT INTO identities (phone_normalized, auth_status)
      VALUES ($1, 'ACTIVE')
      ON CONFLICT (phone_normalized) DO NOTHING
      RETURNING identity_id, phone_normalized, email, auth_status
      `,
      [phoneNormalized],
    );
    if (inserted.rows[0]) {
      return inserted.rows[0];
    }
    const existing = await this.findByPhone(phoneNormalized, db);
    if (!existing) {
      throw new Error('Identity insert conflict but row was not found');
    }
    return existing;
  }

  async findCustomerProfile(
    identityId: string,
    db: Queryable = this.postgres,
  ): Promise<CustomerProfileRow | null> {
    const result = await db.query<CustomerProfileRow>(
      `
      SELECT
        customer_profile_id,
        identity_id,
        display_name,
        email,
        invoice_email,
        status,
        default_city_id
      FROM customer_profiles
      WHERE identity_id = $1
      `,
      [identityId],
    );
    return result.rows[0] ?? null;
  }

  async ensureCustomerProfile(
    identityId: string,
    db: Queryable,
  ): Promise<CustomerProfileRow> {
    const existing = await this.findCustomerProfile(identityId, db);
    if (existing) {
      return existing;
    }
    const inserted = await db.query<CustomerProfileRow>(
      `
      INSERT INTO customer_profiles (identity_id, display_name)
      VALUES ($1, $2)
      ON CONFLICT (identity_id) DO NOTHING
      RETURNING
        customer_profile_id,
        identity_id,
        display_name,
        email,
        invoice_email,
        status,
        default_city_id
      `,
      [identityId, PROVISIONAL_CUSTOMER_DISPLAY_NAME],
    );
    if (inserted.rows[0]) {
      return inserted.rows[0];
    }
    const raced = await this.findCustomerProfile(identityId, db);
    if (!raced) {
      throw new Error('Customer profile insert conflict but row was not found');
    }
    return raced;
  }

  async updateCustomerProfile(
    input: {
      identityId: string;
      customerProfileId: string;
      displayName: string;
      email?: string | null;
      updateEmail: boolean;
    },
    db: Queryable = this.postgres,
  ): Promise<CustomerProfileRow | null> {
    const result = input.updateEmail
      ? await db.query<CustomerProfileRow>(
          `
          UPDATE customer_profiles
          SET
            display_name = $3,
            email = $4,
            invoice_email = $4
          WHERE identity_id = $1
            AND customer_profile_id = $2
          RETURNING
            customer_profile_id,
            identity_id,
            display_name,
            email,
            invoice_email,
            status,
            default_city_id
          `,
          [
            input.identityId,
            input.customerProfileId,
            input.displayName,
            input.email,
          ],
        )
      : await db.query<CustomerProfileRow>(
          `
          UPDATE customer_profiles
          SET display_name = $3
          WHERE identity_id = $1
            AND customer_profile_id = $2
          RETURNING
            customer_profile_id,
            identity_id,
            display_name,
            email,
            invoice_email,
            status,
            default_city_id
          `,
          [input.identityId, input.customerProfileId, input.displayName],
        );
    return result.rows[0] ?? null;
  }

  async findRiderProfile(
    identityId: string,
    db: Queryable = this.postgres,
  ): Promise<RiderProfileRow | null> {
    const result = await db.query<RiderProfileRow>(
      `
      SELECT
        rider_profile_id,
        identity_id,
        onboarding_kyc_status,
        approval_status,
        online_status,
        home_city_id,
        home_zone_id,
        cod_operational_status,
        preferred_language,
        profile_picture_file_id
      FROM rider_profiles
      WHERE identity_id = $1
      `,
      [identityId],
    );
    return result.rows[0] ?? null;
  }

  async ensureRiderProfile(
    identityId: string,
    db: Queryable,
  ): Promise<RiderProfileRow> {
    const existing = await this.findRiderProfile(identityId, db);
    if (existing) {
      return existing;
    }
    const inserted = await db.query<RiderProfileRow>(
      `
      INSERT INTO rider_profiles (identity_id)
      VALUES ($1)
      ON CONFLICT (identity_id) DO NOTHING
      RETURNING
        rider_profile_id,
        identity_id,
        onboarding_kyc_status,
        approval_status,
        online_status,
        home_city_id,
        home_zone_id,
        cod_operational_status,
        preferred_language,
        profile_picture_file_id
      `,
      [identityId],
    );
    if (inserted.rows[0]) {
      return inserted.rows[0];
    }
    const raced = await this.findRiderProfile(identityId, db);
    if (!raced) {
      throw new Error('Rider profile insert conflict but row was not found');
    }
    return raced;
  }

  async findAdminByEmail(email: string): Promise<AdminProfileRow | null> {
    const result = await this.postgres.query<AdminProfileRow>(
      `
      SELECT
        a.admin_profile_id,
        a.identity_id,
        a.role,
        a.modules,
        a.finance_access,
        a.payout_approve,
        a.city_scope_id,
        a.password_hash,
        a.active,
        i.email,
        i.auth_status
      FROM admin_profiles a
      JOIN identities i ON i.identity_id = a.identity_id
      WHERE lower(i.email) = lower($1)
      `,
      [email],
    );
    return result.rows[0] ?? null;
  }

  async findAdminProfile(
    identityId: string,
  ): Promise<Omit<AdminProfileRow, 'password_hash'> | null> {
    const result = await this.postgres.query<Omit<AdminProfileRow, 'password_hash'>>(
      `
      SELECT
        a.admin_profile_id,
        a.identity_id,
        a.role,
        a.modules,
        a.finance_access,
        a.payout_approve,
        a.city_scope_id,
        a.active,
        i.email,
        i.auth_status
      FROM admin_profiles a
      JOIN identities i ON i.identity_id = a.identity_id
      WHERE a.identity_id = $1
      `,
      [identityId],
    );
    return result.rows[0] ?? null;
  }

  async listRiders(db: Queryable = this.postgres): Promise<
    (RiderProfileRow & {
      phone_normalized: string;
      city_code: string | null;
      zone_name: string | null;
        name: string | null;
        email: string | null;
        date_of_birth: string | null;
        driving_licence: string | null;
        vehicle_category_id: string | null;
        vehicle_category_name: string | null;
        vehicle_registration: string | null;
        vehicle_model: string | null;
        vehicle_color: string | null;
        manufacturing_year: number | null;
      })[]
  > {
    const result = await db.query<
      RiderProfileRow & {
        phone_normalized: string;
        city_code: string | null;
        zone_name: string | null;
        name: string | null;
        email: string | null;
        date_of_birth: string | null;
        driving_licence: string | null;
        vehicle_category_id: string | null;
        vehicle_category_name: string | null;
        vehicle_registration: string | null;
        vehicle_model: string | null;
        vehicle_color: string | null;
        manufacturing_year: number | null;
      }
    >(
      `
      SELECT
        r.rider_profile_id,
        r.identity_id,
        r.onboarding_kyc_status,
        r.approval_status,
        r.online_status,
        r.home_city_id,
        r.home_zone_id,
        r.cod_operational_status,
        r.preferred_language,
        r.profile_picture_file_id,
        r.last_seen_at,
        i.phone_normalized,
        i.email,
        d.name,
        d.date_of_birth::text AS date_of_birth,
        d.licence_encrypted_or_token AS driving_licence,
        veh.vehicle_category_id,
        veh.vehicle_category_name,
        veh.vehicle_registration,
        veh.vehicle_model,
        veh.vehicle_color,
        veh.manufacturing_year,
        c.city_code,
        z.name AS zone_name
      FROM rider_profiles r
      JOIN identities i ON i.identity_id = r.identity_id
      LEFT JOIN rider_drivers d ON d.rider_profile_id = r.rider_profile_id
      LEFT JOIN LATERAL (
        SELECT
          v.vehicle_category_id,
          vc.name AS vehicle_category_name,
          v.registration AS vehicle_registration,
          v.model AS vehicle_model,
          v.color AS vehicle_color,
          v.manufacturing_year
        FROM vehicles v
        JOIN vehicle_categories vc ON vc.vehicle_category_id = v.vehicle_category_id
        WHERE v.rider_profile_id = r.rider_profile_id
          AND v.active = TRUE
        ORDER BY v.updated_at DESC
        LIMIT 1
      ) veh ON TRUE
      LEFT JOIN cities c ON c.city_id = r.home_city_id
      LEFT JOIN zones z ON z.zone_id = r.home_zone_id
      ORDER BY r.created_at DESC
      LIMIT 200
      `,
    );
    return result.rows;
  }

  async findRiderDirectory(
    riderProfileId: string,
    db: Queryable = this.postgres,
  ): Promise<
    | (RiderProfileRow & {
        phone_normalized: string;
        city_code: string | null;
        zone_name: string | null;
        name: string | null;
        email: string | null;
        date_of_birth: string | null;
        driving_licence: string | null;
        vehicle_category_id: string | null;
        vehicle_category_name: string | null;
        vehicle_registration: string | null;
        vehicle_model: string | null;
        vehicle_color: string | null;
        manufacturing_year: number | null;
      })
    | null
  > {
    const result = await db.query<
      RiderProfileRow & {
        phone_normalized: string;
        city_code: string | null;
        zone_name: string | null;
        name: string | null;
        email: string | null;
        date_of_birth: string | null;
        driving_licence: string | null;
        vehicle_category_id: string | null;
        vehicle_category_name: string | null;
        vehicle_registration: string | null;
        vehicle_model: string | null;
        vehicle_color: string | null;
        manufacturing_year: number | null;
      }
    >(
      `
      SELECT
        r.rider_profile_id,
        r.identity_id,
        r.onboarding_kyc_status,
        r.approval_status,
        r.online_status,
        r.home_city_id,
        r.home_zone_id,
        r.cod_operational_status,
        r.preferred_language,
        r.profile_picture_file_id,
        r.last_seen_at,
        i.phone_normalized,
        i.email,
        d.name,
        d.date_of_birth::text AS date_of_birth,
        d.licence_encrypted_or_token AS driving_licence,
        veh.vehicle_category_id,
        veh.vehicle_category_name,
        veh.vehicle_registration,
        veh.vehicle_model,
        veh.vehicle_color,
        veh.manufacturing_year,
        c.city_code,
        z.name AS zone_name
      FROM rider_profiles r
      JOIN identities i ON i.identity_id = r.identity_id
      LEFT JOIN rider_drivers d ON d.rider_profile_id = r.rider_profile_id
      LEFT JOIN LATERAL (
        SELECT
          v.vehicle_category_id,
          vc.name AS vehicle_category_name,
          v.registration AS vehicle_registration,
          v.model AS vehicle_model,
          v.color AS vehicle_color,
          v.manufacturing_year
        FROM vehicles v
        JOIN vehicle_categories vc ON vc.vehicle_category_id = v.vehicle_category_id
        WHERE v.rider_profile_id = r.rider_profile_id
          AND v.active = TRUE
        ORDER BY v.updated_at DESC
        LIMIT 1
      ) veh ON TRUE
      LEFT JOIN cities c ON c.city_id = r.home_city_id
      LEFT JOIN zones z ON z.zone_id = r.home_zone_id
      WHERE r.rider_profile_id = $1
      `,
      [riderProfileId],
    );
    return result.rows[0] ?? null;
  }

  async listCustomers(db: Queryable = this.postgres): Promise<
    (CustomerProfileRow & { phone_normalized: string; city_code: string | null })[]
  > {
    const result = await db.query<
      CustomerProfileRow & { phone_normalized: string; city_code: string | null }
    >(
      `
      SELECT
        p.customer_profile_id,
        p.identity_id,
        p.display_name,
        p.email,
        p.invoice_email,
        p.status,
        p.default_city_id,
        i.phone_normalized,
        c.city_code
      FROM customer_profiles p
      JOIN identities i ON i.identity_id = p.identity_id
      LEFT JOIN cities c ON c.city_id = p.default_city_id
      ORDER BY p.created_at DESC
      LIMIT 200
      `,
    );
    return result.rows;
  }

  async findCustomerDirectory(
    customerProfileId: string,
    db: Queryable = this.postgres,
  ): Promise<
    | (CustomerProfileRow & { phone_normalized: string; city_code: string | null })
    | null
  > {
    const result = await db.query<
      CustomerProfileRow & { phone_normalized: string; city_code: string | null }
    >(
      `
      SELECT
        p.customer_profile_id,
        p.identity_id,
        p.display_name,
        p.email,
        p.invoice_email,
        p.status,
        p.default_city_id,
        i.phone_normalized,
        c.city_code
      FROM customer_profiles p
      JOIN identities i ON i.identity_id = p.identity_id
      LEFT JOIN cities c ON c.city_id = p.default_city_id
      WHERE p.customer_profile_id = $1
      `,
      [customerProfileId],
    );
    return result.rows[0] ?? null;
  }

  async findRiderGate(riderProfileId: string): Promise<{
    rider_profile_id: string;
    approval_status: string;
    online_status: string;
    deactivated_at: Date | null;
  } | null> {
    const result = await this.postgres.query<{
      rider_profile_id: string;
      approval_status: string;
      online_status: string;
      deactivated_at: Date | null;
    }>(
      `
      SELECT rider_profile_id, approval_status, online_status, deactivated_at
      FROM rider_profiles
      WHERE rider_profile_id = $1
      `,
      [riderProfileId],
    );
    return result.rows[0] ?? null;
  }

  async updateRiderOnlineStatus(
    riderProfileId: string,
    onlineStatus: 'ONLINE' | 'OFFLINE',
    db: Queryable = this.postgres,
  ): Promise<{ approval_status: string; online_status: string } | null> {
    const result = await db.query<{
      approval_status: string;
      online_status: string;
    }>(
      `
      UPDATE rider_profiles
      SET
        online_status = $2,
        last_seen_at = CASE WHEN $2 = 'ONLINE' THEN now() ELSE last_seen_at END
      WHERE rider_profile_id = $1
      RETURNING approval_status, online_status
      `,
      [riderProfileId, onlineStatus],
    );
    return result.rows[0] ?? null;
  }

  async touchRiderLastSeen(
    riderProfileId: string,
    db: Queryable = this.postgres,
  ): Promise<void> {
    await db.query(
      `
      UPDATE rider_profiles
      SET last_seen_at = now()
      WHERE rider_profile_id = $1
        AND online_status = 'ONLINE'
      `,
      [riderProfileId],
    );
  }

  async updateRiderLanguage(
    riderProfileId: string,
    preferredLanguage: string,
  ): Promise<{ preferred_language: string; approval_status: string; online_status: string } | null> {
    const result = await this.postgres.query<{
      preferred_language: string;
      approval_status: string;
      online_status: string;
    }>(
      `
      UPDATE rider_profiles
      SET preferred_language = $2
      WHERE rider_profile_id = $1
      RETURNING preferred_language, approval_status, online_status
      `,
      [riderProfileId, preferredLanguage],
    );
    return result.rows[0] ?? null;
  }

  async updateIdentityEmail(
    identityId: string,
    email: string | null,
    db: Queryable = this.postgres,
  ): Promise<IdentityRow | null> {
    const result = await db.query<IdentityRow>(
      `
      UPDATE identities
      SET email = $2
      WHERE identity_id = $1
      RETURNING identity_id, phone_normalized, email, auth_status
      `,
      [identityId, email],
    );
    return result.rows[0] ?? null;
  }

  async findRiderDriver(
    riderProfileId: string,
    db: Queryable = this.postgres,
  ): Promise<{
    rider_driver_id: string;
    name: string | null;
    date_of_birth: string | null;
    driving_licence: string | null;
  } | null> {
    const result = await db.query<{
      rider_driver_id: string;
      name: string | null;
      date_of_birth: string | null;
      driving_licence: string | null;
    }>(
      `
      SELECT
        rider_driver_id,
        name,
        date_of_birth::text AS date_of_birth,
        licence_encrypted_or_token AS driving_licence
      FROM rider_drivers
      WHERE rider_profile_id = $1
      `,
      [riderProfileId],
    );
    return result.rows[0] ?? null;
  }

  async upsertRiderDriverDetails(
    input: {
      riderProfileId: string;
      name?: string;
      dateOfBirth?: string | null;
      drivingLicence?: string | null;
      updateName: boolean;
      updateDob: boolean;
      updateLicence?: boolean;
    },
    db: Queryable = this.postgres,
  ): Promise<{
    rider_driver_id: string;
    name: string | null;
    date_of_birth: string | null;
    driving_licence: string | null;
  }> {
    const updateLicence = input.updateLicence === true;
    const existing = await this.findRiderDriver(input.riderProfileId, db);
    if (!existing) {
      const inserted = await db.query<{
        rider_driver_id: string;
        name: string | null;
        date_of_birth: string | null;
        driving_licence: string | null;
      }>(
        `
        INSERT INTO rider_drivers (
          rider_profile_id, name, date_of_birth, licence_encrypted_or_token
        )
        VALUES ($1, $2, $3::date, $4)
        RETURNING
          rider_driver_id,
          name,
          date_of_birth::text AS date_of_birth,
          licence_encrypted_or_token AS driving_licence
        `,
        [
          input.riderProfileId,
          input.updateName ? input.name ?? null : null,
          input.updateDob ? input.dateOfBirth ?? null : null,
          updateLicence ? input.drivingLicence ?? null : null,
        ],
      );
      return inserted.rows[0];
    }
    const result = await db.query<{
      rider_driver_id: string;
      name: string | null;
      date_of_birth: string | null;
      driving_licence: string | null;
    }>(
      `
      UPDATE rider_drivers
      SET
        name = CASE WHEN $3::boolean THEN $2 ELSE name END,
        date_of_birth = CASE WHEN $5::boolean THEN $4::date ELSE date_of_birth END,
        licence_encrypted_or_token = CASE WHEN $7::boolean THEN $6 ELSE licence_encrypted_or_token END
      WHERE rider_profile_id = $1
      RETURNING
        rider_driver_id,
        name,
        date_of_birth::text AS date_of_birth,
        licence_encrypted_or_token AS driving_licence
      `,
      [
        input.riderProfileId,
        input.name ?? null,
        input.updateName,
        input.dateOfBirth ?? null,
        input.updateDob,
        input.drivingLicence ?? null,
        updateLicence,
      ],
    );
    return result.rows[0];
  }

  async findActiveRiderVehicle(
    riderProfileId: string,
    db: Queryable = this.postgres,
  ): Promise<{
    vehicle_id: string;
    vehicle_category_id: string;
    vehicle_category_name: string;
    registration: string | null;
    model: string | null;
    color: string | null;
    manufacturing_year: number | null;
  } | null> {
    const result = await db.query<{
      vehicle_id: string;
      vehicle_category_id: string;
      vehicle_category_name: string;
      registration: string | null;
      model: string | null;
      color: string | null;
      manufacturing_year: number | null;
    }>(
      `
      SELECT
        v.vehicle_id,
        v.vehicle_category_id,
        vc.name AS vehicle_category_name,
        v.registration,
        v.model,
        v.color,
        v.manufacturing_year
      FROM vehicles v
      JOIN vehicle_categories vc ON vc.vehicle_category_id = v.vehicle_category_id
      WHERE v.rider_profile_id = $1
        AND v.active = TRUE
      ORDER BY v.updated_at DESC
      LIMIT 1
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

  async upsertRiderVehicle(
    input: {
      riderProfileId: string;
      vehicleCategoryId: string;
      registration: string;
      model: string;
      color: string;
      manufacturingYear: number;
    },
    db: Queryable = this.postgres,
  ): Promise<void> {
    const category = await db.query<{ name: string }>(
      `
      SELECT name
      FROM vehicle_categories
      WHERE vehicle_category_id = $1
        AND active = TRUE
      `,
      [input.vehicleCategoryId],
    );
    if (!category.rows[0]) {
      throw new Error('VEHICLE_CATEGORY_NOT_FOUND');
    }
    const subtype = twoWheelerSubtype(category.rows[0].name);
    const current = await this.findActiveRiderVehicle(input.riderProfileId, db);
    let vehicleId: string;
    if (!current) {
      const inserted = await db.query<{ vehicle_id: string }>(
        `
        INSERT INTO vehicles (
          vehicle_category_id,
          rider_profile_id,
          registration,
          two_wheeler_subtype,
          active,
          model,
          color,
          manufacturing_year
        )
        VALUES ($1, $2, $3, $4, TRUE, $5, $6, $7)
        RETURNING vehicle_id
        `,
        [
          input.vehicleCategoryId,
          input.riderProfileId,
          input.registration,
          subtype,
          input.model,
          input.color,
          input.manufacturingYear,
        ],
      );
      vehicleId = inserted.rows[0].vehicle_id;
    } else {
      vehicleId = current.vehicle_id;
      await db.query(
        `
        UPDATE vehicles
        SET vehicle_category_id = $2,
            registration = $3,
            two_wheeler_subtype = $4,
            model = $5,
            color = $6,
            manufacturing_year = $7,
            active = TRUE
        WHERE vehicle_id = $1
        `,
        [
          vehicleId,
          input.vehicleCategoryId,
          input.registration,
          subtype,
          input.model,
          input.color,
          input.manufacturingYear,
        ],
      );
    }
    await db.query(
      `
      UPDATE vehicles
      SET active = FALSE
      WHERE rider_profile_id = $1
        AND vehicle_id <> $2
        AND active = TRUE
      `,
      [input.riderProfileId, vehicleId],
    );
  }
}

function twoWheelerSubtype(categoryName: string): 'BIKE' | 'SCOOTER' | null {
  const name = categoryName.trim().toLowerCase();
  if (name.includes('scoot')) return 'SCOOTER';
  if (name === 'bike' || name.includes('bike') || name.includes('motorcycle')) {
    return 'BIKE';
  }
  return null;
}
