import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/app.setup';
import { AuthService } from '../src/auth/auth.service';
import { PasswordService } from '../src/auth/password.service';
import { PostgresService } from '../src/database/postgres.service';
import { ProfileRole, TokenPair } from '../src/auth/types/auth-context';

export async function createTestApp(): Promise<INestApplication> {
  const moduleRef = await Test.createTestingModule({
    imports: [AppModule],
  }).compile();
  const app = moduleRef.createNestApplication();
  configureApp(app);
  await app.init();
  return app;
}

export function uniquePhone(): string {
  return `8${Math.floor(100000000 + Math.random() * 899999999)}`;
}

export async function insertCustomerFixture(
  postgres: PostgresService,
): Promise<{ identityId: string; profileId: string; phone: string }> {
  const phone = uniquePhone();
  const identity = await postgres.query<{ identity_id: string }>(
    `
    INSERT INTO identities (phone_normalized, auth_status)
    VALUES ($1, 'ACTIVE')
    RETURNING identity_id
    `,
    [phone],
  );
  const identityId = identity.rows[0].identity_id;
  const profile = await postgres.query<{ customer_profile_id: string }>(
    `
    INSERT INTO customer_profiles (identity_id, display_name)
    VALUES ($1, 'Phase 1 Test Customer')
    RETURNING customer_profile_id
    `,
    [identityId],
  );
  return {
    identityId,
    profileId: profile.rows[0].customer_profile_id,
    phone,
  };
}

export async function issueCustomerSession(
  app: INestApplication,
): Promise<{
  identityId: string;
  profileId: string;
  tokens: TokenPair;
}> {
  const postgres = app.get(PostgresService);
  const auth = app.get(AuthService);
  const fixture = await insertCustomerFixture(postgres);
  const tokens = await auth.createSession({
    identityId: fixture.identityId,
    role: 'CUSTOMER' satisfies ProfileRole,
    profileId: fixture.profileId,
  });
  return { identityId: fixture.identityId, profileId: fixture.profileId, tokens };
}

export async function insertAdminFixture(
  app: INestApplication,
  password: string,
  options?: { financeAccess?: boolean; role?: string },
): Promise<{ identityId: string; profileId: string; email: string }> {
  const postgres = app.get(PostgresService);
  const passwords = app.get(PasswordService);
  const phone = uniquePhone();
  const email = `p2-admin-${Date.now()}-${Math.floor(Math.random() * 10000)}@example.test`;
  const hash = await passwords.hash(password);
  const identity = await postgres.query<{ identity_id: string }>(
    `
    INSERT INTO identities (phone_normalized, email, auth_status)
    VALUES ($1, $2, 'ACTIVE')
    RETURNING identity_id
    `,
    [phone, email],
  );
  const identityId = identity.rows[0].identity_id;
  const financeAccess = options?.financeAccess !== false;
  const role = options?.role ?? 'SUPER_ADMIN';
  const profile = await postgres.query<{ admin_profile_id: string }>(
    `
    INSERT INTO admin_profiles (
      identity_id, role, password_hash, modules, finance_access, payout_approve, active
    )
    VALUES ($1, $2, $3, '[]'::jsonb, $4, true, true)
    RETURNING admin_profile_id
    `,
    [identityId, role, hash, financeAccess],
  );
  return {
    identityId,
    profileId: profile.rows[0].admin_profile_id,
    email,
  };
}

export async function deleteIdentity(
  postgres: PostgresService,
  identityId: string,
): Promise<void> {
  const ident = await postgres.query<{ phone_normalized: string }>(
    'SELECT phone_normalized FROM identities WHERE identity_id = $1',
    [identityId],
  );
  const phone = ident.rows[0]?.phone_normalized;
  await postgres.query('DELETE FROM sessions WHERE identity_id = $1', [
    identityId,
  ]);
  await postgres.query('DELETE FROM otp_challenges WHERE identity_id = $1', [
    identityId,
  ]);
  if (phone) {
    await postgres.query(
      'DELETE FROM otp_challenges WHERE phone_normalized = $1',
      [phone],
    );
  }
  await postgres.query(
    `
    DELETE FROM notification_deliveries
    WHERE notification_id IN (
      SELECT notification_id FROM notifications WHERE recipient_identity_id = $1
    )
    `,
    [identityId],
  );
  await postgres.query(
    'DELETE FROM notifications WHERE recipient_identity_id = $1',
    [identityId],
  );
  await postgres.query(
    'DELETE FROM notification_preferences WHERE identity_id = $1',
    [identityId],
  );
  await postgres.query(
    'DELETE FROM customer_profiles WHERE identity_id = $1',
    [identityId],
  );
  await postgres.query(
    'DELETE FROM rider_profiles WHERE identity_id = $1',
    [identityId],
  );
  await postgres.query(
    'DELETE FROM admin_profiles WHERE identity_id = $1',
    [identityId],
  );
  await postgres.query('DELETE FROM identities WHERE identity_id = $1', [
    identityId,
  ]);
}

export async function deleteByPhone(
  postgres: PostgresService,
  phone: string,
): Promise<void> {
  const ident = await postgres.query<{ identity_id: string }>(
    'SELECT identity_id FROM identities WHERE phone_normalized = $1',
    [phone],
  );
  if (ident.rows[0]) {
    await deleteIdentity(postgres, ident.rows[0].identity_id);
    return;
  }
  await postgres.query(
    'DELETE FROM otp_challenges WHERE phone_normalized = $1',
    [phone],
  );
}

export function assertNoSecrets(body: unknown): void {
  const raw = JSON.stringify(body);
  expect(raw).not.toMatch(/code_hash/);
  expect(raw).not.toMatch(/password_hash/);
  expect(raw).not.toMatch(/refresh_token_hash/);
}

const CATALOG_ADMIN_EMAIL = 'phase3-catalog-owner@example.test';

export type OrderCatalog = {
  cityId: string;
  cityCode: string;
  zoneId: string;
  secondCityId: string;
  secondCityCode: string;
  secondZoneId: string;
  vehicleCategoryId: string;
  vehicleCategoryName: string;
  fareConfigVersionId: string;
  rates: {
    base_fare: string;
    per_km: string;
    initial_minimum: string;
    waiting: string;
    surge: string;
    toll: string;
    parking: string;
  };
};

export type SampleStop = {
  sequence: number;
  stop_type: 'PICKUP' | 'DROP';
  address_text: string;
  latitude: number;
  longitude: number;
  zone_id?: string;
};

export function sampleStops(zoneId?: string, extraDrops = 0): SampleStop[] {
  const stops: SampleStop[] = [
    {
      sequence: 0,
      stop_type: 'PICKUP',
      address_text: 'Pickup, Navrangpura',
      latitude: 23.0225,
      longitude: 72.5714,
      zone_id: zoneId,
    },
    {
      sequence: 1,
      stop_type: 'DROP',
      address_text: 'Drop 1, SG Highway',
      latitude: 23.04,
      longitude: 72.52,
      zone_id: zoneId,
    },
  ];
  for (let i = 0; i < extraDrops; i += 1) {
    stops.push({
      sequence: 2 + i,
      stop_type: 'DROP',
      address_text: `Drop ${2 + i}, extra`,
      latitude: Number((23.05 + i * 0.01).toFixed(6)),
      longitude: 72.51,
      zone_id: zoneId,
    });
  }
  return stops;
}

export function uniqueIdempotencyKey(): string {
  return `p3-${Date.now()}-${Math.floor(Math.random() * 1_000_000)}`;
}

export async function ensureOrderCatalog(
  postgres: PostgresService,
): Promise<OrderCatalog> {
  const city = await upsertCity(postgres, 'AMD', 'Ahmedabad');
  const zone = await upsertZone(postgres, city.city_id, 'Phase 3 AMD Zone');
  const second = await upsertCity(postgres, 'TST', 'Phase 3 Sequence City');
  const secondZone = await upsertZone(postgres, second.city_id, 'Phase 3 TST Zone');
  const category = await resolveVehicleCategory(postgres);
  const fare = await ensureActiveFare(postgres, category.vehicle_category_id);
  return {
    cityId: city.city_id,
    cityCode: city.city_code,
    zoneId: zone.zone_id,
    secondCityId: second.city_id,
    secondCityCode: second.city_code,
    secondZoneId: secondZone.zone_id,
    vehicleCategoryId: category.vehicle_category_id,
    vehicleCategoryName: category.name,
    fareConfigVersionId: fare.fare_config_version_id,
    rates: fare.rates,
  };
}

async function upsertCity(
  postgres: PostgresService,
  cityCode: string,
  name: string,
): Promise<{ city_id: string; city_code: string }> {
  const existing = await postgres.query<{ city_id: string; city_code: string }>(
    `SELECT city_id, city_code FROM cities WHERE city_code = $1`,
    [cityCode],
  );
  if (existing.rows[0]) {
    return existing.rows[0];
  }
  const inserted = await postgres.query<{ city_id: string; city_code: string }>(
    `
    INSERT INTO cities (name, city_code, active)
    VALUES ($1, $2, TRUE)
    RETURNING city_id, city_code
    `,
    [name, cityCode],
  );
  return inserted.rows[0];
}

async function upsertZone(
  postgres: PostgresService,
  cityId: string,
  name: string,
): Promise<{ zone_id: string }> {
  const existing = await postgres.query<{ zone_id: string }>(
    `SELECT zone_id FROM zones WHERE city_id = $1 AND name = $2`,
    [cityId, name],
  );
  if (existing.rows[0]) {
    return existing.rows[0];
  }
  const inserted = await postgres.query<{ zone_id: string }>(
    `
    INSERT INTO zones (city_id, name, active)
    VALUES ($1, $2, TRUE)
    RETURNING zone_id
    `,
    [cityId, name],
  );
  return inserted.rows[0];
}

/**
 * A published fare version is immutable, so its priced categories cannot be
 * extended. Adopt one of them when an ACTIVE version already exists, and only
 * create the BIKE fixture when there is nothing to adopt.
 */
async function resolveVehicleCategory(postgres: PostgresService): Promise<{
  vehicle_category_id: string;
  name: string;
}> {
  const priced = await postgres.query<{
    vehicle_category_id: string;
    name: string;
  }>(
    `
    SELECT v.vehicle_category_id, v.name
    FROM fare_config_versions f
    JOIN fare_config_version_rates r
      ON r.fare_config_version_id = f.fare_config_version_id
    JOIN vehicle_categories v
      ON v.vehicle_category_id = r.vehicle_category_id
    WHERE f.status = 'ACTIVE'
      AND v.active
    ORDER BY (v.code IS NOT DISTINCT FROM 'BIKE') DESC, v.name
    LIMIT 1
    `,
  );
  if (priced.rows[0]) {
    return priced.rows[0];
  }
  return upsertVehicleCategory(postgres);
}

async function upsertVehicleCategory(postgres: PostgresService): Promise<{
  vehicle_category_id: string;
  name: string;
}> {
  const existing = await postgres.query<{
    vehicle_category_id: string;
    name: string;
  }>(
    `SELECT vehicle_category_id, name FROM vehicle_categories WHERE code = 'BIKE'`,
  );
  if (existing.rows[0]) {
    return existing.rows[0];
  }
  const inserted = await postgres.query<{
    vehicle_category_id: string;
    name: string;
  }>(
    `
    INSERT INTO vehicle_categories (code, name, active)
    VALUES ('BIKE', 'Bike', TRUE)
    RETURNING vehicle_category_id, name
    `,
  );
  return inserted.rows[0];
}

async function ensureCatalogAdmin(
  postgres: PostgresService,
): Promise<string> {
  const existing = await postgres.query<{ admin_profile_id: string }>(
    `
    SELECT a.admin_profile_id
    FROM admin_profiles a
    JOIN identities i ON i.identity_id = a.identity_id
    WHERE lower(i.email) = lower($1)
    `,
    [CATALOG_ADMIN_EMAIL],
  );
  if (existing.rows[0]) {
    return existing.rows[0].admin_profile_id;
  }
  const phone = uniquePhone();
  const identity = await postgres.query<{ identity_id: string }>(
    `
    INSERT INTO identities (phone_normalized, email, auth_status)
    VALUES ($1, $2, 'ACTIVE')
    RETURNING identity_id
    `,
    [phone, CATALOG_ADMIN_EMAIL],
  );
  const profile = await postgres.query<{ admin_profile_id: string }>(
    `
    INSERT INTO admin_profiles (
      identity_id, role, password_hash, modules, finance_access, payout_approve, active
    )
    VALUES ($1, 'SUPER_ADMIN', 'phase3-catalog-not-a-login-hash', '[]'::jsonb, true, true, true)
    RETURNING admin_profile_id
    `,
    [identity.rows[0].identity_id],
  );
  return profile.rows[0].admin_profile_id;
}

async function ensureActiveFare(
  postgres: PostgresService,
  vehicleCategoryId: string,
): Promise<{
  fare_config_version_id: string;
  rates: OrderCatalog['rates'];
}> {
  const active = await postgres.query<{ fare_config_version_id: string }>(
    `SELECT fare_config_version_id FROM fare_config_versions WHERE status = 'ACTIVE'`,
  );
  let versionId = active.rows[0]?.fare_config_version_id;
  if (!versionId) {
    const adminId = await ensureCatalogAdmin(postgres);
    const version = await postgres.query<{ version: string }>(
      `SELECT COALESCE(MAX(version), 0)::text AS version FROM fare_config_versions`,
    );
    const nextVersion = Number.parseInt(version.rows[0].version, 10) + 1;
    const inserted = await postgres.query<{ fare_config_version_id: string }>(
      `
      INSERT INTO fare_config_versions (
        version, status, effective_from, created_by_admin_profile_id
      )
      VALUES ($1, 'DRAFT', now(), $2)
      RETURNING fare_config_version_id
      `,
      [nextVersion, adminId],
    );
    versionId = inserted.rows[0].fare_config_version_id;
    await postgres.query(
      `
      INSERT INTO fare_config_version_rates (
        fare_config_version_id, vehicle_category_id,
        base_fare, per_km, initial_minimum, waiting, surge, toll, parking
      )
      VALUES ($1, $2, 100.00, 10.00, 100.00, 0, 0, 0, 0)
      `,
      [versionId, vehicleCategoryId],
    );
    await postgres.query(
      `
      UPDATE fare_config_versions
      SET status = 'ACTIVE'
      WHERE fare_config_version_id = $1
      `,
      [versionId],
    );
  }

  const rates = await postgres.query<OrderCatalog['rates']>(
    `
    SELECT
      base_fare::text AS base_fare,
      per_km::text AS per_km,
      initial_minimum::text AS initial_minimum,
      waiting::text AS waiting,
      surge::text AS surge,
      toll::text AS toll,
      parking::text AS parking
    FROM fare_config_version_rates
    WHERE fare_config_version_id = $1
      AND vehicle_category_id = $2
    `,
    [versionId, vehicleCategoryId],
  );
  if (!rates.rows[0]) {
    throw new Error(
      'ACTIVE fare_config_versions has no rates for the BIKE category; cannot add rates to a published version',
    );
  }
  return { fare_config_version_id: versionId, rates: rates.rows[0] };
}

export async function ensureActivePaymentSettings(
  postgres: PostgresService,
): Promise<{
  payment_settings_version_id: string;
  rider_percentage: string;
  company_commission_percentage: string;
  operational_cost_percentage_of_commission: string;
}> {
  const active = await postgres.query<{
    payment_settings_version_id: string;
    rider_percentage: string;
    company_commission_percentage: string;
    operational_cost_percentage_of_commission: string;
  }>(
    `
    SELECT
      payment_settings_version_id,
      rider_percentage::text AS rider_percentage,
      company_commission_percentage::text AS company_commission_percentage,
      operational_cost_percentage_of_commission::text AS operational_cost_percentage_of_commission
    FROM payment_settings_versions
    WHERE status = 'ACTIVE'
    `,
  );
  if (active.rows[0]) {
    return active.rows[0];
  }
  const adminId = await ensureCatalogAdmin(postgres);
  const version = await postgres.query<{ version: string }>(
    `SELECT COALESCE(MAX(version), 0)::text AS version FROM payment_settings_versions`,
  );
  const nextVersion = Number.parseInt(version.rows[0].version, 10) + 1;
  const inserted = await postgres.query<{
    payment_settings_version_id: string;
    rider_percentage: string;
    company_commission_percentage: string;
    operational_cost_percentage_of_commission: string;
  }>(
    `
    INSERT INTO payment_settings_versions (
      version, status, rider_percentage, company_commission_percentage,
      operational_cost_percentage_of_commission, effective_from, created_by_admin_profile_id
    )
    VALUES ($1, 'ACTIVE', 85, 15, 50, now(), $2)
    RETURNING
      payment_settings_version_id,
      rider_percentage::text AS rider_percentage,
      company_commission_percentage::text AS company_commission_percentage,
      operational_cost_percentage_of_commission::text AS operational_cost_percentage_of_commission
    `,
    [nextVersion, adminId],
  );
  return inserted.rows[0];
}

export async function insertRiderFixture(
  postgres: PostgresService,
  options?: { approved?: boolean; online?: boolean },
): Promise<{ identityId: string; profileId: string; phone: string }> {
  const phone = uniquePhone();
  const identity = await postgres.query<{ identity_id: string }>(
    `
    INSERT INTO identities (phone_normalized, auth_status)
    VALUES ($1, 'ACTIVE')
    RETURNING identity_id
    `,
    [phone],
  );
  const identityId = identity.rows[0].identity_id;
  const approved = options?.approved !== false;
  const online = options?.online !== false;
  const profile = await postgres.query<{ rider_profile_id: string }>(
    `
    INSERT INTO rider_profiles (
      identity_id, onboarding_kyc_status, approval_status, online_status, cod_operational_status
    )
    VALUES ($1, $2, $3, $4, 'CLEAR')
    RETURNING rider_profile_id
    `,
    [
      identityId,
      approved ? 'APPROVED' : 'PENDING',
      approved ? 'APPROVED' : 'PENDING',
      online ? 'ONLINE' : 'OFFLINE',
    ],
  );
  return {
    identityId,
    profileId: profile.rows[0].rider_profile_id,
    phone,
  };
}

export async function issueRiderSession(
  app: INestApplication,
  options?: { approved?: boolean; online?: boolean },
): Promise<{
  identityId: string;
  profileId: string;
  tokens: TokenPair;
}> {
  const postgres = app.get(PostgresService);
  const auth = app.get(AuthService);
  const fixture = await insertRiderFixture(postgres, options);
  const tokens = await auth.createSession({
    identityId: fixture.identityId,
    role: 'RIDER' satisfies ProfileRole,
    profileId: fixture.profileId,
  });
  return { identityId: fixture.identityId, profileId: fixture.profileId, tokens };
}

export async function purgeIsolatedTestVehicleCatalog(
  postgres: PostgresService,
): Promise<void> {
  const dependents = await postgres.query<{ n: string }>(
    `
    SELECT (
      (SELECT count(*) FROM orders)
      + (SELECT count(*) FROM vehicles)
      + (SELECT count(*) FROM fare_quotes)
      + (SELECT count(*) FROM order_fare_snapshots)
      + (SELECT count(*) FROM resend_snapshots)
    )::text AS n
    `,
  );
  if (Number(dependents.rows[0]?.n || 0) > 0) {
    return;
  }
  const unexpected = await postgres.query<{ n: string }>(
    `
    SELECT count(*)::text AS n
    FROM vehicle_categories
    WHERE name NOT LIKE 'E2E Fare %'
      AND name NOT LIKE 'E2E Bike %'
    `,
  );
  if (Number(unexpected.rows[0]?.n || 0) > 0) {
    return;
  }
  await postgres.query('TRUNCATE fare_config_version_rates');
  await postgres.query('DELETE FROM fare_config_versions');
  await postgres.query(
    `
    DELETE FROM vehicle_categories
    WHERE name LIKE 'E2E Fare %'
       OR name LIKE 'E2E Bike %'
    `,
  );
}

export async function issueAdminSession(
  app: INestApplication,
  options?: { financeAccess?: boolean; role?: string },
): Promise<{
  identityId: string;
  profileId: string;
  tokens: TokenPair;
}> {
  const fixture = await insertAdminFixture(app, 'AdminPass#2026!!', options);
  const auth = app.get(AuthService);
  const tokens = await auth.createSession({
    identityId: fixture.identityId,
    role: 'ADMIN' satisfies ProfileRole,
    profileId: fixture.profileId,
  });
  return { identityId: fixture.identityId, profileId: fixture.profileId, tokens };
}

