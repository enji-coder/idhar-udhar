/**
 * DEVELOPMENT ONLY. Upserts one SUPER_ADMIN from IDHAR_UDHAR_ADMIN/.env
 * (ADMIN_EMAIL / ADMIN_PASSWORD) into the existing PostgreSQL database.
 * Does not print secrets. Does not create migrations.
 */
import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import argon2 from 'argon2';
import pg from 'pg';

function loadEnv(path) {
  if (!existsSync(path)) {
    return;
  }
  for (const line of readFileSync(path, 'utf8').split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq < 1) continue;
    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (process.env[key] === undefined) {
      process.env[key] = value;
    }
  }
}

const root = resolve(import.meta.dirname, '..');
const repo = resolve(root, '..');
loadEnv(resolve(root, '.env'));
loadEnv(resolve(repo, 'records_database', '.env'));
loadEnv(resolve(repo, 'IDHAR_UDHAR_ADMIN', '.env'));

const email = (process.env.ADMIN_EMAIL || '').trim().toLowerCase();
const password = process.env.ADMIN_PASSWORD || '';
if (!email || !password) {
  console.error('ADMIN_EMAIL and ADMIN_PASSWORD are required in IDHAR_UDHAR_ADMIN/.env');
  process.exit(1);
}

const client = new pg.Client({
  host: process.env.DATABASE_HOST,
  port: Number(process.env.DATABASE_PORT || 5432),
  database: process.env.DATABASE_NAME,
  user: process.env.DATABASE_USER,
  password: process.env.DATABASE_PASSWORD,
  ssl: (process.env.DATABASE_SSL || 'false').toLowerCase() === 'true',
});

const phone = `8${String(Date.now()).slice(-9)}`;
const hash = await argon2.hash(password, { type: argon2.argon2id });

await client.connect();
try {
  const existing = await client.query(
    `
    SELECT a.admin_profile_id, i.identity_id
    FROM admin_profiles a
    JOIN identities i ON i.identity_id = a.identity_id
    WHERE lower(i.email) = $1
    `,
    [email],
  );
  if (existing.rows[0]) {
    await client.query(
      `
      UPDATE admin_profiles
      SET password_hash = $2, role = 'SUPER_ADMIN', finance_access = TRUE,
          payout_approve = TRUE, active = TRUE, modules = '[]'::jsonb
      WHERE admin_profile_id = $1
      `,
      [existing.rows[0].admin_profile_id, hash],
    );
    console.log('Updated existing local SUPER_ADMIN password hash.');
  } else {
    await client.query('BEGIN');
    const identity = await client.query(
      `
      INSERT INTO identities (phone_normalized, email, auth_status)
      VALUES ($1, $2, 'ACTIVE')
      RETURNING identity_id
      `,
      [phone, email],
    );
    await client.query(
      `
      INSERT INTO admin_profiles (
        identity_id, role, password_hash, modules, finance_access, payout_approve, active
      )
      VALUES ($1, 'SUPER_ADMIN', $2, '[]'::jsonb, TRUE, TRUE, TRUE)
      `,
      [identity.rows[0].identity_id, hash],
    );
    await client.query('COMMIT');
    console.log('Created local SUPER_ADMIN for Admin login.');
  }
} catch (err) {
  try {
    await client.query('ROLLBACK');
  } catch {
    /* keep original */
  }
  console.error(err instanceof Error ? err.message : 'ensure-local-admin failed');
  process.exitCode = 1;
} finally {
  await client.end();
}
