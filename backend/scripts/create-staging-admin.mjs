/**
 * Staging-only SUPER_ADMIN bootstrap.
 * Does not load .env files. Does not print the email, phone, or password.
 * Refuses every database except the verified staging name.
 * Does not update an existing admin password.
 */
import { existsSync, readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import argon2 from 'argon2';
import pg from 'pg';

export const PRODUCTION_DATABASE_HOST =
  'idhar-udhar-prod-db.crc48wu0snqv.ap-south-1.rds.amazonaws.com';
export const STAGING_DATABASE_HOST =
  'iu-staging-db.crc48wu0snqv.ap-south-1.rds.amazonaws.com';
export const STAGING_DATABASE_NAME = 'idhar_udhar_staging';
export const STAGING_ADMIN_CONFIRM = 'create-staging-admin';

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function assertStagingAdminTarget(env = process.env) {
  const tier = (env.IU_DEPLOYMENT_TIER || '').trim().toLowerCase();
  const host = (env.DATABASE_HOST || '').trim().toLowerCase();
  const name = (env.DATABASE_NAME || '').trim();

  if (host === PRODUCTION_DATABASE_HOST) {
    throw new Error('Refusing production database host');
  }
  if (tier === 'production') {
    throw new Error('Refusing IU_DEPLOYMENT_TIER=production');
  }
  if (!tier) {
    throw new Error('IU_DEPLOYMENT_TIER=staging is required');
  }
  if (tier !== 'staging') {
    throw new Error('IU_DEPLOYMENT_TIER=staging is required');
  }
  if (!host) {
    throw new Error('DATABASE_HOST is required');
  }
  if (host !== STAGING_DATABASE_HOST) {
    throw new Error('IU_DEPLOYMENT_TIER=staging requires the staging database host');
  }
  if (!name) {
    throw new Error('DATABASE_NAME is required');
  }
  if (name !== STAGING_DATABASE_NAME) {
    throw new Error('Refusing database name; expected idhar_udhar_staging');
  }
}

export function assertStagingAdminConfirmation(env = process.env) {
  const dryRun = (env.STAGING_ADMIN_DRY_RUN || '').trim() === '1';
  const confirm = (env.STAGING_ADMIN_CONFIRM || '').trim();
  if (!dryRun && confirm !== STAGING_ADMIN_CONFIRM) {
    throw new Error(
      'Refusing to create an admin without STAGING_ADMIN_CONFIRM=create-staging-admin',
    );
  }
  return { dryRun };
}

export function readAdminEmail(env = process.env) {
  const email = (env.ADMIN_EMAIL || '').trim().toLowerCase();
  if (!EMAIL_RE.test(email)) {
    throw new Error('ADMIN_EMAIL must be a valid email');
  }
  return email;
}

export function readAdminPassword(env = process.env) {
  const password = env.ADMIN_PASSWORD || '';
  if (!password.trim()) {
    throw new Error('ADMIN_PASSWORD is required');
  }
  if (password.length < 8) {
    throw new Error('ADMIN_PASSWORD must be at least 8 characters');
  }
  if (password.length > 200) {
    throw new Error('ADMIN_PASSWORD is too long');
  }
  return password;
}

/**
 * One staging bootstrap admin. A second account, a privilege change, and
 * attaching admin access to an existing identity are all refused.
 * The same active SUPER_ADMIN email is a no-op.
 */
export function planStagingAdmin({ email, admins, identity }) {
  const rows = admins ?? [];
  if (rows.length > 1) {
    throw new Error('Refusing duplicate admin profiles');
  }
  const existing = rows[0] ?? null;
  const sameEmail =
    existing && (existing.email || '').trim().toLowerCase() === email;
  if (identity?.admin_profile_id || sameEmail) {
    if (
      rows.length === 1 &&
      sameEmail &&
      existing.role === 'SUPER_ADMIN' &&
      existing.active === true &&
      existing.auth_status === 'ACTIVE'
    ) {
      return { action: 'already_present' };
    }
    throw new Error('Refusing to change an existing admin account');
  }
  if (existing) {
    throw new Error('Refusing a second admin account');
  }
  if (identity?.identity_id) {
    throw new Error('Refusing to attach an admin profile to an existing identity');
  }
  return { action: 'create' };
}

function uniquePhone() {
  return `8${String(Date.now()).slice(-9)}`;
}

function publicError(err, password) {
  const message = err instanceof Error ? err.message : 'staging admin bootstrap failed';
  if (password && message.includes(password)) {
    return 'staging admin bootstrap failed';
  }
  return message;
}

async function assertConnectedDatabase(client) {
  const current = await client.query('SELECT current_database() AS database_name');
  const verified = current.rows[0]?.database_name;
  if (verified !== STAGING_DATABASE_NAME) {
    throw new Error('Refusing connected database; expected idhar_udhar_staging');
  }
}

export async function runStagingAdminBootstrap({
  env = process.env,
  client,
  hashPassword = (plain) => argon2.hash(plain, { type: argon2.argon2id }),
  write = (line) => {
    process.stdout.write(`${line}\n`);
  },
}) {
  assertStagingAdminTarget(env);
  const { dryRun } = assertStagingAdminConfirmation(env);
  const email = readAdminEmail(env);
  const password = dryRun ? '' : readAdminPassword(env);

  await client.connect();
  try {
    await client.query(dryRun ? 'BEGIN READ ONLY' : 'BEGIN');
    await assertConnectedDatabase(client);

    const admins = await client.query(
      `
      SELECT i.email, a.admin_profile_id, a.role, a.active, i.auth_status
      FROM admin_profiles a
      JOIN identities i ON i.identity_id = a.identity_id
      ORDER BY a.created_at
      ${dryRun ? '' : 'FOR UPDATE'}
      `,
    );
    const identity = await client.query(
      `
      SELECT i.identity_id, a.admin_profile_id
      FROM identities i
      LEFT JOIN admin_profiles a ON a.identity_id = i.identity_id
      WHERE lower(i.email) = lower($1)
      ${dryRun ? '' : 'FOR UPDATE OF i'}
      `,
      [email],
    );
    const plan = planStagingAdmin({
      email,
      admins: admins.rows,
      identity: identity.rows[0] ?? null,
    });

    if (plan.action === 'already_present') {
      await client.query(dryRun ? 'ROLLBACK' : 'COMMIT');
      write(
        'staging_admin already_present database=idhar_udhar_staging role=SUPER_ADMIN active=true auth_status=ACTIVE',
      );
      return { action: 'already_present' };
    }

    if (dryRun) {
      await client.query('ROLLBACK');
      write('staging_admin dry_run action=create database=idhar_udhar_staging');
      return { action: 'dry_run' };
    }

    const hash = await hashPassword(password);
    if (!hash.startsWith('$argon2id$')) {
      throw new Error('Password hash is not argon2id');
    }

    let identityId = null;
    for (let attempt = 0; attempt < 5 && !identityId; attempt += 1) {
      try {
        const inserted = await client.query(
          `
          INSERT INTO identities (phone_normalized, email, auth_status)
          VALUES ($1, $2, 'ACTIVE')
          RETURNING identity_id
          `,
          [uniquePhone(), email],
        );
        identityId = inserted.rows[0].identity_id;
      } catch (err) {
        if (err && err.code === '23505' && String(err.constraint || '').includes('phone')) {
          continue;
        }
        throw err;
      }
    }
    if (!identityId) {
      throw new Error('Could not allocate a unique admin phone_normalized');
    }

    const profile = await client.query(
      `
      INSERT INTO admin_profiles (
        identity_id, role, password_hash, modules, finance_access, payout_approve, active
      )
      VALUES ($1, 'SUPER_ADMIN', $2, '[]'::jsonb, TRUE, TRUE, TRUE)
      RETURNING admin_profile_id
      `,
      [identityId, hash],
    );
    const adminProfileId = profile.rows[0].admin_profile_id;
    const verified = await client.query(
      `
      SELECT current_database() AS database_name,
             i.auth_status,
             a.role,
             a.active,
             (a.password_hash IS NOT NULL) AS password_set
      FROM admin_profiles a
      JOIN identities i ON i.identity_id = a.identity_id
      WHERE a.admin_profile_id = $1
      `,
      [adminProfileId],
    );
    const row = verified.rows[0];
    if (
      !row ||
      row.database_name !== STAGING_DATABASE_NAME ||
      row.role !== 'SUPER_ADMIN' ||
      row.active !== true ||
      row.auth_status !== 'ACTIVE' ||
      row.password_set !== true
    ) {
      throw new Error('Staging admin verification failed');
    }
    await client.query('COMMIT');
    write(
      'staging_admin created database=idhar_udhar_staging role=SUPER_ADMIN active=true auth_status=ACTIVE password_set=true',
    );
    return { action: 'created' };
  } catch (err) {
    try {
      await client.query('ROLLBACK');
    } catch {
      /* keep the original error */
    }
    throw new Error(publicError(err, password));
  } finally {
    await client.end();
  }
}

function sslConfig(env) {
  const enabled = (env.DATABASE_SSL || 'false').toLowerCase() === 'true';
  if (!enabled) {
    return false;
  }
  const certPath = (env.DATABASE_SSL_ROOT_CERT || '').trim();
  if (certPath) {
    if (!existsSync(certPath)) {
      throw new Error('DATABASE_SSL_ROOT_CERT file was not found');
    }
    return { rejectUnauthorized: true, ca: readFileSync(certPath, 'utf8') };
  }
  return { rejectUnauthorized: true };
}

function isMainModule() {
  const entry = process.argv[1];
  if (!entry) {
    return false;
  }
  return import.meta.url === pathToFileURL(entry).href;
}

if (isMainModule()) {
  const env = process.env;
  try {
    assertStagingAdminTarget(env);
    assertStagingAdminConfirmation(env);
    readAdminEmail(env);
    if ((env.STAGING_ADMIN_DRY_RUN || '').trim() !== '1') {
      readAdminPassword(env);
    }
  } catch (err) {
    process.stderr.write(`${err instanceof Error ? err.message : 'staging admin bootstrap failed'}\n`);
    process.exitCode = 1;
  }

  if (!process.exitCode) {
    const client = new pg.Client({
      host: env.DATABASE_HOST,
      port: Number(env.DATABASE_PORT || 5432),
      database: env.DATABASE_NAME,
      user: env.DATABASE_USER,
      password: env.DATABASE_PASSWORD,
      ssl: sslConfig(env),
    });
    runStagingAdminBootstrap({ env, client }).catch((err) => {
      process.stderr.write(`${err instanceof Error ? err.message : 'staging admin bootstrap failed'}\n`);
      process.exitCode = 1;
    });
  }
}
