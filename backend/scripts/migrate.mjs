/**
 * Applies records_database SQL migrations in filename order.
 * Same rules as records_database/migrate.ps1:
 * a version already present in schema_migrations is skipped, even when a
 * later version is already applied. Missing versions are applied in order.
 * Each file runs in one transaction and is recorded with its SHA-256.
 *
 * Does not print passwords, SQL, or connection strings.
 * Apply mode requires MIGRATE_CONFIRM=apply-missing.
 * MIGRATE_DRY_RUN=1 prints SKIP/APPLY only.
 */
import { createHash } from 'node:crypto';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import pg from 'pg';

const FILENAME_PATTERN = /^(\d{4}_.+)\.sql$/;

export function migrationVersion(filename) {
  const match = FILENAME_PATTERN.exec(filename);
  return match ? match[1] : null;
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
  return resolve(dirname(fileURLToPath(import.meta.url)), '..', '..', 'records_database', 'migrations');
}

async function appliedVersions(client) {
  await client.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version     TEXT PRIMARY KEY,
      filename    TEXT NOT NULL,
      checksum    TEXT NOT NULL,
      applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
  const result = await client.query('SELECT version FROM schema_migrations');
  return result.rows.map((row) => String(row.version));
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

  const port = Number.parseInt(requireEnv('DATABASE_PORT'), 10);
  if (!Number.isInteger(port)) {
    throw new Error('DATABASE_PORT must be a number');
  }

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
    const applied = await appliedVersions(client);
    const plan = planMigrations(filenames, applied);
    for (const item of plan.skip) {
      process.stdout.write(`SKIP already applied: ${item.filename}\n`);
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
      process.stdout.write(`Dry run: ${plan.apply.length} missing, ${plan.skip.length} already applied.\n`);
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
