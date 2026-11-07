/**
 * Applies records_database SQL migrations in filename order.
 * Same rules as records_database/migrate.ps1:
 * a version already present in schema_migrations is skipped, even when a
 * later version is already applied. Missing versions are applied in order.
 * Each file runs in one transaction and is recorded with its SHA-256.
 *
 * Does not print passwords, SQL, or connection strings.
 * Apply mode requires MIGRATE_CONFIRM=apply-missing.
 * MIGRATE_DRY_RUN=1 prints SKIP/APPLY only and never creates schema objects
 * (including schema_migrations).
 *
 * Duplicate numeric prefixes (e.g. two 0026_*.sql files) are refused before
 * any database connection. Production-applied 0026 and 0027 files must match
 * their recorded checksums. 0028_payout_provider_references was applied in
 * production, but its exact bytes are not in this repository: that version is
 * not reapplied, and a different file under that name is refused.
 */
import { createHash } from 'node:crypto';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import pg from 'pg';

const FILENAME_PATTERN = /^(\d{4}_.+)\.sql$/;

/** Checksums of production-applied files restored from commit 5ce4d74. */
export const PRODUCTION_FILE_CHECKSUMS = Object.freeze({
  '0026_rider_wallet_topup_withdrawal':
    '24e2ce4c19916df8049c578bebb95d5821cf2a5951b4c93147e433ac934756e8',
  '0027_wallet_idempotency_scopes':
    'b635b1f8d34217eb08e930acf88dbb97fc086f2b469b39ff046405ef9f09583e',
});

/**
 * Applied in production. The exact file bytes are not in this repository.
 * Leave the filename absent unless those bytes are restored.
 */
export const HISTORICAL_APPLIED_WITHOUT_BYTES = Object.freeze({
  '0028_payout_provider_references':
    '87731dfe7527925d9c98a92baef24abd9788a849e19d931e8515c896f3a082ba',
});

/**
 * Present in the repository but not launched. apply-missing must not select
 * these files. They are not marked applied.
 */
export const DEFERRED_MIGRATIONS = Object.freeze({
  '0038_rider_online_sessions.sql':
    'Rider Online Time is not launched',
});

export function withoutDeferredMigrations(plan) {
  const deferred = [];
  const apply = [];
  for (const item of plan.apply) {
    if (DEFERRED_MIGRATIONS[item.filename]) {
      deferred.push(item);
    } else {
      apply.push(item);
    }
  }
  return { skip: plan.skip, apply, deferred };
}

export function migrationVersion(filename) {
  const match = FILENAME_PATTERN.exec(filename);
  return match ? match[1] : null;
}

export function migrationNumericPrefix(filename) {
  const version = migrationVersion(filename);
  return version ? version.slice(0, 4) : null;
}

/**
 * Refuses ambiguous migration sets where two files share the same 4-digit
 * prefix. Version identity is the full stem, so both would otherwise apply.
 */
export function assertUniqueNumericPrefixes(filenames) {
  const byPrefix = new Map();
  for (const filename of filenames) {
    const prefix = migrationNumericPrefix(filename);
    if (!prefix) {
      continue;
    }
    const list = byPrefix.get(prefix) ?? [];
    list.push(filename);
    byPrefix.set(prefix, list);
  }
  const conflicts = [...byPrefix.entries()]
    .filter(([, list]) => list.length > 1)
    .map(
      ([prefix, list]) =>
        `${prefix}: ${list.sort((a, b) => (a < b ? -1 : a > b ? 1 : 0)).join(', ')}`,
    );
  if (conflicts.length > 0) {
    throw new Error(
      `Duplicate migration numeric prefixes (resolve after verifying production schema_migrations; do not rename applied files blindly):\n${conflicts.join('\n')}`,
    );
  }
}

export function listMigrationFiles(directory) {
  return readdirSync(directory)
    .filter((name) => migrationVersion(name))
    .sort((left, right) => (left < right ? -1 : left > right ? 1 : 0));
}

/**
 * @param {string[]} filenames sorted migration filenames
 * @param {Iterable<string>} appliedVersions versions already in schema_migrations
 */
export function planMigrations(filenames, appliedVersions) {
  const applied = new Set(appliedVersions);
  const skip = [];
  const apply = [];
  const ordered = [...filenames].sort((left, right) =>
    left < right ? -1 : left > right ? 1 : 0,
  );
  for (const filename of ordered) {
    const version = migrationVersion(filename);
    if (!version) {
      continue;
    }
    if (applied.has(version)) {
      skip.push({ version, filename });
    } else {
      apply.push({ version, filename });
    }
  }
  return { skip, apply };
}

/**
 * A recorded version whose file bytes changed must not be skipped.
 * Call this before any migration SQL runs.
 *
 * @param {Array<{ version: string, checksum: string }>} recorded
 * @param {Map<string, string>} localChecksumByVersion lowercase sha256 of the current file
 */
/**
 * Refuses a drifted production file before any database connection.
 * A historical version with no local file is allowed only when its bytes
 * were never recovered. A different file under that version name is refused.
 *
 * @param {Map<string, string>} localChecksumByVersion
 */
export function assertProductionMigrationIdentity(localChecksumByVersion) {
  for (const [version, expected] of Object.entries(PRODUCTION_FILE_CHECKSUMS)) {
    const local = localChecksumByVersion.get(version);
    if (!local) {
      throw new Error(`Production-applied migration file is missing: ${version}`);
    }
    if (local !== expected) {
      throw new Error(
        `Production-applied migration checksum does not match the file: ${version}`,
      );
    }
  }
  for (const [version, expected] of Object.entries(HISTORICAL_APPLIED_WITHOUT_BYTES)) {
    const local = localChecksumByVersion.get(version);
    if (!local) {
      continue;
    }
    if (local !== expected) {
      throw new Error(
        `Unrecovered production migration is present with a different checksum. Refusing to skip or apply: ${version}`,
      );
    }
  }
}

export function assertRecordedChecksums(recorded, localChecksumByVersion) {
  const mismatches = [];
  const missing = [];
  for (const row of recorded) {
    const version = String(row.version);
    const stored = String(row.checksum || '').trim().toLowerCase();
    const local = localChecksumByVersion.get(version);
    const pinned = HISTORICAL_APPLIED_WITHOUT_BYTES[version];
    if (!local) {
      if (pinned && stored === pinned) {
        continue;
      }
      if (pinned) {
        mismatches.push(version);
      } else {
        missing.push(version);
      }
      continue;
    }
    if (!stored || stored !== local) {
      mismatches.push(version);
    }
  }
  if (mismatches.length > 0) {
    throw new Error(
      `Recorded migration checksum does not match the file. Refusing to skip or apply: ${mismatches.join(', ')}`,
    );
  }
  if (missing.length > 0) {
    throw new Error(
      `Recorded migration has no local file. Refusing to continue: ${missing.join(', ')}`,
    );
  }
}

export const PRODUCTION_DATABASE_HOST =
  'idhar-udhar-prod-db.crc48wu0snqv.ap-south-1.rds.amazonaws.com';
export const STAGING_DATABASE_HOST =
  'iu-staging-db.crc48wu0snqv.ap-south-1.rds.amazonaws.com';
export const STAGING_DATABASE_NAME = 'idhar_udhar_staging';

/**
 * Refuses the production RDS endpoint before any connection.
 * Staging tier must use the staging host, staging database name, and
 * Cashfree sandbox. Local runs that leave IU_DEPLOYMENT_TIER unset are unchanged.
 */
export function assertMigrationTarget(env = process.env) {
  const host = (env.DATABASE_HOST || '').trim().toLowerCase();
  const name = (env.DATABASE_NAME || '').trim();
  const tier = (env.IU_DEPLOYMENT_TIER || '').trim().toLowerCase();
  const cashfree = (env.CASHFREE_ENVIRONMENT || '').trim().toLowerCase();
  if (host === PRODUCTION_DATABASE_HOST) {
    throw new Error('Refusing production database host');
  }
  if (tier === 'production') {
    throw new Error('Refusing IU_DEPLOYMENT_TIER=production');
  }
  if (cashfree === 'production') {
    throw new Error('Refusing CASHFREE_ENVIRONMENT=production');
  }
  if (tier === 'staging') {
    if (host !== STAGING_DATABASE_HOST) {
      throw new Error(
        'IU_DEPLOYMENT_TIER=staging requires the staging database host',
      );
    }
    if (name !== STAGING_DATABASE_NAME) {
      throw new Error(
        'IU_DEPLOYMENT_TIER=staging requires DATABASE_NAME=idhar_udhar_staging',
      );
    }
    if (cashfree !== 'sandbox') {
      throw new Error(
        'IU_DEPLOYMENT_TIER=staging requires CASHFREE_ENVIRONMENT=sandbox',
      );
    }
  }
}

export function sha256Hex(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
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

function migrationsDirectory() {
  const configured = (process.env.MIGRATIONS_DIR || '').trim();
  if (configured) {
    return configured;
  }
  const scriptDir = dirname(fileURLToPath(import.meta.url));
  // Image layout: /app/scripts → /app/records_database/migrations
  const inImage = resolve(scriptDir, '..', 'records_database', 'migrations');
  if (existsSync(inImage)) {
    return inImage;
  }
  // Monorepo layout: backend/scripts → ../../records_database/migrations
  return resolve(scriptDir, '..', '..', 'records_database', 'migrations');
}

async function ensureSchemaMigrationsTable(client) {
  await client.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version     TEXT PRIMARY KEY,
      filename    TEXT NOT NULL,
      checksum    TEXT NOT NULL,
      applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
}

async function appliedVersions(client, { allowCreate }) {
  if (allowCreate) {
    await ensureSchemaMigrationsTable(client);
  }
  try {
    const result = await client.query(
      'SELECT version, checksum FROM schema_migrations',
    );
    return result.rows.map((row) => ({
      version: String(row.version),
      checksum: row.checksum == null ? '' : String(row.checksum),
    }));
  } catch (error) {
    const code = error && typeof error === 'object' ? error.code : null;
    // undefined_table — dry-run must not CREATE; treat as empty history.
    if (!allowCreate && code === '42P01') {
      return [];
    }
    throw error;
  }
}

async function applyFile(client, directory, item) {
  const path = join(directory, item.filename);
  const bytes = readFileSync(path);
  const checksum = sha256Hex(bytes);
  const sql = bytes.toString('utf8');
  try {
    await client.query('BEGIN');
    await client.query(sql);
    await client.query(
      `INSERT INTO schema_migrations (version, filename, checksum)
       VALUES ($1, $2, $3)`,
      [item.version, item.filename, checksum],
    );
    await client.query('COMMIT');
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch {
      // The connection may already have aborted the transaction.
    }
    const message = error instanceof Error ? error.message : 'migration failed';
    throw new Error(`Migration ${item.filename} failed: ${message}`);
  }
  return checksum;
}

export async function runMigrations({ dryRun }) {
  const directory = migrationsDirectory();
  if (!existsSync(directory)) {
    throw new Error('Migrations directory was not found');
  }
  const filenames = listMigrationFiles(directory);
  if (filenames.length === 0) {
    throw new Error('No SQL migrations were found');
  }
  assertUniqueNumericPrefixes(filenames);
  const localChecksums = new Map();
  for (const filename of filenames) {
    const version = migrationVersion(filename);
    if (!version) {
      continue;
    }
    localChecksums.set(
      version,
      sha256Hex(readFileSync(join(directory, filename))),
    );
  }
  assertProductionMigrationIdentity(localChecksums);

  const port = Number.parseInt(requireEnv('DATABASE_PORT'), 10);
  if (!Number.isInteger(port)) {
    throw new Error('DATABASE_PORT must be a number');
  }
  assertMigrationTarget();

  const client = new pg.Client({
    host: requireEnv('DATABASE_HOST'),
    port,
    database: requireEnv('DATABASE_NAME'),
    user: requireEnv('DATABASE_USER'),
    password: requireEnv('DATABASE_PASSWORD'),
    ssl: sslConfig(),
    connectionTimeoutMillis: 10_000,
  });
  await client.connect();
  try {
    const applied = await appliedVersions(client, { allowCreate: !dryRun });
    assertRecordedChecksums(applied, localChecksums);
    for (const row of applied) {
      const version = String(row.version);
      if (!localChecksums.has(version) && HISTORICAL_APPLIED_WITHOUT_BYTES[version]) {
        process.stdout.write(`SKIP already applied without local file: ${version}.sql\n`);
      }
    }
    const plan = withoutDeferredMigrations(
      planMigrations(
        filenames,
        applied.map((row) => row.version),
      ),
    );
    for (const item of plan.skip) {
      process.stdout.write(`SKIP already applied: ${item.filename}\n`);
    }
    for (const item of plan.deferred) {
      process.stdout.write(`DEFER ${item.filename}\n`);
    }
    for (const item of plan.apply) {
      if (dryRun) {
        process.stdout.write(`WOULD APPLY ${item.filename}\n`);
        continue;
      }
      process.stdout.write(`APPLY ${item.filename}\n`);
      await applyFile(client, directory, item);
      process.stdout.write(`  OK ${item.version}\n`);
    }
    if (dryRun) {
      process.stdout.write(`Dry run: ${plan.apply.length} missing, ${plan.deferred.length} deferred, ${plan.skip.length} already applied.\n`);
    } else {
      process.stdout.write('All migrations applied.\n');
    }
    return plan;
  } finally {
    await client.end();
  }
}

function isMainModule() {
  const entry = process.argv[1];
  if (!entry) {
    return false;
  }
  return import.meta.url === pathToFileURL(entry).href;
}

if (isMainModule()) {
  const dryRun = (process.env.MIGRATE_DRY_RUN || '').trim() === '1';
  const confirm = (process.env.MIGRATE_CONFIRM || '').trim();
  if (!dryRun && confirm !== 'apply-missing') {
    process.stderr.write(
      'Refusing to apply migrations. Set MIGRATE_CONFIRM=apply-missing, or MIGRATE_DRY_RUN=1 to list missing versions only.\n',
    );
    process.exitCode = 2;
  } else {
    runMigrations({ dryRun }).catch((error) => {
      const message = error instanceof Error ? error.message : 'migration failed';
      process.stderr.write(`${message}\n`);
      process.exitCode = 1;
    });
  }
}
