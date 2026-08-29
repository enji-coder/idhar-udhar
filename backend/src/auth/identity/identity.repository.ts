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
        cod_operational_status
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
        cod_operational_status
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
    })[]
  > {
    const result = await db.query<
      RiderProfileRow & {
        phone_normalized: string;
        city_code: string | null;
        zone_name: string | null;
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
        i.phone_normalized,
        c.city_code,
        z.name AS zone_name
      FROM rider_profiles r
      JOIN identities i ON i.identity_id = r.identity_id
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
      })
    | null
  > {
    const result = await db.query<
      RiderProfileRow & {
        phone_normalized: string;
        city_code: string | null;
        zone_name: string | null;
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
        i.phone_normalized,
        c.city_code,
        z.name AS zone_name
      FROM rider_profiles r
      JOIN identities i ON i.identity_id = r.identity_id
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
}
