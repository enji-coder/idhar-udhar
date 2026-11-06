import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Queryable } from '../../database/queryable';
import { PostgresService } from '../../database/postgres.service';
import { AppConfig } from '../../config/configuration';
import { isRiderPresenceFresh, onlineSessionAction } from '../../profiles/rider-online-time';

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
  constructor(
    private readonly postgres: PostgresService,
    private readonly configService: ConfigService,
  ) {}

  /** False unless RIDER_ONLINE_TIME_ENABLED=true. Session SQL stays behind this. */
  private onlineTimeEnabled(): boolean {
    return (
      this.configService.getOrThrow<AppConfig['location']>('location')
        .onlineTimeEnabled === true
    );
  }

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
    db: Queryable = this.postgres,
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
      WHERE r.deactivated_at IS NULL
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
        AND r.deactivated_at IS NULL
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

  async deactivateRider(
    riderProfileId: string,
  ): Promise<{
    rider_profile_id: string;
    deactivated_at: Date;
    online_status: string;
  } | null> {
    return this.postgres.transaction(async (tx) => {
      const updated = await tx.query<{
        rider_profile_id: string;
        deactivated_at: Date;
        online_status: string;
      }>(
        `
        UPDATE rider_profiles
        SET
          deactivated_at = now(),
          online_status = 'OFFLINE'
        WHERE rider_profile_id = $1
          AND deactivated_at IS NULL
        RETURNING rider_profile_id, deactivated_at, online_status
        `,
        [riderProfileId],
      );
      const row = updated.rows[0];
      if (!row) {
        return null;
      }
      await tx.query(
        `
        UPDATE sessions
        SET revoked_at = now()
        WHERE rider_profile_id = $1
          AND revoked_at IS NULL
        `,
        [riderProfileId],
      );
      await this.closeOpenOnlineSessions(riderProfileId, 'DEACTIVATED', tx);
      return row;
    });
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
    staleMs = 180_000,
    db: Queryable = this.postgres,
  ): Promise<{ approval_status: string; online_status: string } | null> {
    if (!this.onlineTimeEnabled()) {
      return this.writeOnlineStatus(db, riderProfileId, onlineStatus);
    }
    const run = (tx: Queryable) =>
      this.applyOnlineStatus(tx, riderProfileId, onlineStatus, staleMs);
    if (db === this.postgres) {
      return this.postgres.transaction(run);
    }
    return run(db);
  }

  /** Availability only. Does not read or write rider_online_sessions. */
  private async writeOnlineStatus(
    db: Queryable,
    riderProfileId: string,
    onlineStatus: 'ONLINE' | 'OFFLINE',
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

  private async applyOnlineStatus(
    tx: Queryable,
    riderProfileId: string,
    onlineStatus: 'ONLINE' | 'OFFLINE',
    staleMs: number,
  ): Promise<{ approval_status: string; online_status: string } | null> {
    const locked = await tx.query<{
      approval_status: string;
      online_status: string;
      last_seen_at: Date | null;
    }>(
      `
      SELECT approval_status, online_status, last_seen_at
      FROM rider_profiles
      WHERE rider_profile_id = $1
      FOR UPDATE
      `,
      [riderProfileId],
    );
    const current = locked.rows[0];
    if (!current) {
      return null;
    }
    const open = await tx.query(
      `
      SELECT session_id
      FROM rider_online_sessions
      WHERE rider_profile_id = $1
        AND ended_at IS NULL
      FOR UPDATE
      `,
      [riderProfileId],
    );
    const goingOnline = onlineStatus === 'ONLINE';
    const action = onlineSessionAction({
      currentlyOnline: current.online_status === 'ONLINE',
      goingOnline,
      hasOpenSession: open.rows.length > 0,
      presenceFresh: isRiderPresenceFresh(
        current.last_seen_at,
        Date.now(),
        staleMs,
      ),
    });
    const updated = await tx.query<{
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
    const row = updated.rows[0] ?? null;
    if (!row) {
      return null;
    }
    if (action === 'close' || action === 'close_then_open') {
      if (goingOnline) {
        await tx.query(
          `
          UPDATE rider_online_sessions
          SET
            ended_at = GREATEST(started_at, COALESCE($2::timestamptz, started_at)),
            close_reason = 'PRESENCE_STALE'
          WHERE rider_profile_id = $1
            AND ended_at IS NULL
          `,
          [riderProfileId, current.last_seen_at],
        );
      } else {
        await tx.query(
          `
          UPDATE rider_online_sessions
          SET
            ended_at = GREATEST(started_at, now()),
            close_reason = 'OFFLINE'
          WHERE rider_profile_id = $1
            AND ended_at IS NULL
          `,
          [riderProfileId],
        );
      }
    }
    if (action === 'open' || action === 'close_then_open') {
      await tx.query(
        `
        INSERT INTO rider_online_sessions (rider_profile_id, started_at)
        VALUES ($1, now())
        ON CONFLICT (rider_profile_id) WHERE ended_at IS NULL DO NOTHING
        `,
        [riderProfileId],
      );
    }
    return row;
  }

  async closeOpenOnlineSessions(
    riderProfileId: string,
    reason: 'OFFLINE' | 'PRESENCE_STALE' | 'DEACTIVATED',
    db: Queryable = this.postgres,
  ): Promise<void> {
    if (!this.onlineTimeEnabled()) {
      return;
    }
    await db.query(
      `
      UPDATE rider_online_sessions
      SET
        ended_at = GREATEST(started_at, now()),
        close_reason = $2
      WHERE rider_profile_id = $1
        AND ended_at IS NULL
      `,
      [riderProfileId, reason],
    );
  }

  async touchRiderLastSeen(
    riderProfileId: string,
    db: Queryable = this.postgres,
  ): Promise<void> {
    if (!this.onlineTimeEnabled()) {
      await db.query(
        `
        UPDATE rider_profiles
        SET last_seen_at = now()
        WHERE rider_profile_id = $1
          AND online_status = 'ONLINE'
        `,
        [riderProfileId],
      );
      return;
    }
    await db.query(
      `
      WITH seen AS (
        UPDATE rider_profiles
        SET last_seen_at = now()
        WHERE rider_profile_id = $1
          AND online_status = 'ONLINE'
        RETURNING rider_profile_id
      )
      INSERT INTO rider_online_sessions (rider_profile_id, started_at)
      SELECT rider_profile_id, now()
      FROM seen
      WHERE NOT EXISTS (
        SELECT 1
        FROM rider_online_sessions
        WHERE rider_profile_id = $1
          AND ended_at IS NULL
      )
      ON CONFLICT (rider_profile_id) WHERE ended_at IS NULL DO NOTHING
      `,
      [riderProfileId],
    );
  }

  /**
   * Persist Offline for riders whose last_seen is past the presence window.
   * Admin display already treats them Offline; this keeps DB + dispatch aligned
   * so permanently disconnected sessions do not stay ONLINE forever.
   */
  async expireStaleOnlineRiders(
    staleMs: number,
    db: Queryable = this.postgres,
  ): Promise<number> {
    if (!this.onlineTimeEnabled()) {
      const result = await db.query<{ rider_profile_id: string }>(
        `
        UPDATE rider_profiles
        SET online_status = 'OFFLINE'
        WHERE online_status = 'ONLINE'
          AND (
            last_seen_at IS NULL
            OR last_seen_at < now() - ($1::bigint * interval '1 millisecond')
          )
        RETURNING rider_profile_id
        `,
        [staleMs],
      );
      return result.rows.length;
    }
    const result = await db.query<{ rider_profile_id: string }>(
      `
      WITH expired AS (
        UPDATE rider_profiles
        SET online_status = 'OFFLINE'
        WHERE online_status = 'ONLINE'
          AND (
            last_seen_at IS NULL
            OR last_seen_at < now() - ($1::bigint * interval '1 millisecond')
          )
        RETURNING rider_profile_id, last_seen_at
      ),
      closed AS (
        UPDATE rider_online_sessions AS s
        SET
          ended_at = GREATEST(s.started_at, COALESCE(e.last_seen_at, s.started_at)),
          close_reason = 'PRESENCE_STALE'
        FROM expired AS e
        WHERE s.rider_profile_id = e.rider_profile_id
          AND s.ended_at IS NULL
        RETURNING s.session_id
      )
      SELECT rider_profile_id FROM expired
      `,
      [staleMs],
    );
    return result.rows.length;
  }

  async listOnlineSessionsOverlapping(
    fromIso: string,
    toIso: string,
    riderProfileId: string | null,
    search: string,
  ): Promise<
    Array<{
      session_id: string;
      rider_profile_id: string;
      started_at: Date;
      ended_at: Date | null;
      name: string | null;
      phone_normalized: string;
    }>
  > {
    if (!this.onlineTimeEnabled()) {
      return [];
    }
    const term = search.trim();
    const result = await this.postgres.query<{
      session_id: string;
      rider_profile_id: string;
      started_at: Date;
      ended_at: Date | null;
      name: string | null;
      phone_normalized: string;
    }>(
      `
      SELECT
        s.session_id,
        s.rider_profile_id,
        s.started_at,
        s.ended_at,
        d.name,
        i.phone_normalized
      FROM rider_online_sessions s
      JOIN rider_profiles r ON r.rider_profile_id = s.rider_profile_id
      JOIN identities i ON i.identity_id = r.identity_id
      LEFT JOIN rider_drivers d ON d.rider_profile_id = r.rider_profile_id
      WHERE s.started_at < $2::timestamptz
        AND COALESCE(s.ended_at, now()) > $1::timestamptz
        AND ($3::uuid IS NULL OR s.rider_profile_id = $3::uuid)
        AND (
          $4::text = ''
          OR COALESCE(d.name, '') ILIKE '%' || $4 || '%'
          OR i.phone_normalized ILIKE '%' || $4 || '%'
        )
      ORDER BY d.name NULLS LAST, s.started_at
      `,
      [fromIso, toIso, riderProfileId, term],
    );
    return result.rows;
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
