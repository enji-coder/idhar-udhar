/**
 * One-time production SUPER_ADMIN bootstrap.
 * Reads ADMIN_EMAIL and ADMIN_PASSWORD from the process environment only.
 * Does not print secrets. Does not create migrations. Does not load Admin .env.
 */
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'path';
import argon2 from 'argon2';
import pg from 'pg';

const DB_KEYS = new Set([
  'DATABASE_HOST',
  'DATABASE_PORT',
  'DATABASE_NAME',
  'DATABASE_USER',
  'DATABASE_PASSWORD',
  'DATABASE_SSL',
  'DATABASE_SSL_ROOT_CERT',
]);

function loadDatabaseEnv(path) {
  if (!existsSync(path)) {
    return;
  }
  for (const line of readFileSync(path, 'utf8').split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq < 1) continue;
    const key = trimmed.slice(0, eq).trim();
    if (!DB_KEYS.has(key) || process.env[key] !== undefined) continue;
    let value = trimmed.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    process.env[key] = value;
  }
}

function requireEnv(name) {
  const value = (process.env[name] || '').trim();
  if (!value) {
    throw new Error(`${name} is required`);
  }
  return value;
}

function sslConfig() {
  const enabled = (process.env.DATABASE_SSL || 'false').toLowerCase() === 'true';
  if (!enabled) {
    return false;
  }
  const certPath = (process.env.DATABASE_SSL_ROOT_CERT || '').trim();
  if (certPath) {
    if (!existsSync(certPath)) {
      throw new Error('DATABASE_SSL_ROOT_CERT file was not found');
    }
    return { rejectUnauthorized: true, ca: readFileSync(certPath, 'utf8') };
  }
  return { rejectUnauthorized: true };
}

function assertAllowed() {
  const nodeEnv = (process.env.NODE_ENV || '').trim().toLowerCase();
  const allow = (process.env.ALLOW_PROD_ADMIN_BOOTSTRAP || '').trim().toLowerCase();
  if (nodeEnv !== 'production' && allow !== 'yes') {
    throw new Error(
      'Refusing to run: set NODE_ENV=production or ALLOW_PROD_ADMIN_BOOTSTRAP=yes',
    );
  }
}

function uniquePhone() {
  return `8${String(Date.now()).slice(-9)}`;
}

const root = resolve(import.meta.dirname, '..');
const repo = resolve(root, '..');
loadDatabaseEnv(resolve(root, '.env'));
loadDatabaseEnv(resolve(repo, 'records_database', '.env'));

assertAllowed();

const email = (process.env.ADMIN_EMAIL || '').trim().toLowerCase();
const password = process.env.ADMIN_PASSWORD || '';
if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
  throw new Error('ADMIN_EMAIL must be a valid email');
}
if (!password || !password.trim()) {
  throw new Error('ADMIN_PASSWORD is required and must not be empty');
}
if (password.length < 8) {
  throw new Error('ADMIN_PASSWORD must be at least 8 characters (matches Admin login validation)');
}

const dbHost = requireEnv('DATABASE_HOST');
const dbPort = Number(process.env.DATABASE_PORT || 5432);
const dbName = requireEnv('DATABASE_NAME');
const dbUser = requireEnv('DATABASE_USER');
const dbPassword = requireEnv('DATABASE_PASSWORD');

const client = new pg.Client({
  host: dbHost,
  port: dbPort,
  database: dbName,
  user: dbUser,
  password: dbPassword,
  ssl: sslConfig(),
});

const hash = await argon2.hash(password, { type: argon2.argon2id });

await client.connect();
try {
  await client.query('BEGIN');

  const found = await client.query(
    `
    SELECT i.identity_id, a.admin_profile_id, i.auth_status, a.active, a.role
    FROM identities i
    LEFT JOIN admin_profiles a ON a.identity_id = i.identity_id
    WHERE lower(i.email) = lower($1)
    FOR UPDATE OF i
    `,
    [email],
  );

  let action;
  if (found.rows[0]?.admin_profile_id) {
    await client.query(
      `
      UPDATE identities
      SET auth_status = 'ACTIVE'
      WHERE identity_id = $1
      `,
      [found.rows[0].identity_id],
    );
    await client.query(
      `
      UPDATE admin_profiles
      SET password_hash = $2,
          role = 'SUPER_ADMIN',
          finance_access = TRUE,
          payout_approve = TRUE,
          active = TRUE
      WHERE admin_profile_id = $1
      `,
      [found.rows[0].admin_profile_id, hash],
    );
    action = 'updated';
  } else if (found.rows[0]?.identity_id) {
    await client.query(
      `
      UPDATE identities
      SET auth_status = 'ACTIVE'
      WHERE identity_id = $1
      `,
      [found.rows[0].identity_id],
    );
    await client.query(
      `
      INSERT INTO admin_profiles (
        identity_id, role, password_hash, modules, finance_access, payout_approve, active
      )
      VALUES ($1, 'SUPER_ADMIN', $2, '[]'::jsonb, TRUE, TRUE, TRUE)
      `,
      [found.rows[0].identity_id, hash],
    );
    action = 'linked';
  } else {
    let identityId = null;
    for (let attempt = 0; attempt < 5 && !identityId; attempt += 1) {
      const phone = uniquePhone();
      try {
        const identity = await client.query(
          `
          INSERT INTO identities (phone_normalized, email, auth_status)
          VALUES ($1, $2, 'ACTIVE')
          RETURNING identity_id
          `,
          [phone, email],
        );
        identityId = identity.rows[0].identity_id;
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
    await client.query(
      `
      INSERT INTO admin_profiles (
        identity_id, role, password_hash, modules, finance_access, payout_approve, active
      )
      VALUES ($1, 'SUPER_ADMIN', $2, '[]'::jsonb, TRUE, TRUE, TRUE)
      `,
      [identityId, hash],
    );
    action = 'created';
  }

  await client.query('COMMIT');
  console.log(
    `Production admin ${action}: email_set=yes role=SUPER_ADMIN active=true auth_status=ACTIVE`,
  );
} catch (err) {
  try {
    await client.query('ROLLBACK');
  } catch {
    /* keep original */
  }
  console.error(err instanceof Error ? err.message : 'create-production-admin failed');
  process.exitCode = 1;
} finally {
  await client.end();
}
