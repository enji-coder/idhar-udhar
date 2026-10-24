/**
 * Applies migrations to a disposable local database only.
 * Refuses any host other than 127.0.0.1, any port other than 54329,
 * and any database name other than idhar_udhar_disposable.
 * Does not print passwords or SQL.
 *
 * This script is not a production migrator. Numeric prefixes are unique.
 * It applies every migration file, including 0033. It does not recreate
 * version 0028_payout_provider_references.
 */
import { createHash } from 'node:crypto';
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const HOST = '127.0.0.1';
const PORT = 54329;
const DATABASE = 'idhar_udhar_disposable';
const USER = 'disposable';
const PASSWORD = 'disposable';

const SKIP = new Set();

const dir = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'records_database', 'migrations');

if (process.env.DISPOSABLE_PG !== '1') {
  throw new Error('Set DISPOSABLE_PG=1 to apply migrations to the disposable database');
}

const files = readdirSync(dir)
  .filter((name) => /^\d{4}_.+\.sql$/.test(name) && !SKIP.has(name))
  .sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));

const client = new pg.Client({
  host: HOST,
  port: PORT,
  database: DATABASE,
  user: USER,
  password: PASSWORD,
  connectionTimeoutMillis: 5000,
});

await client.connect();
const identity = await client.query(
  `SELECT inet_server_addr()::text AS addr, current_database() AS db, inet_server_port() AS port`,
);
const row = identity.rows[0];
if (row.db !== DATABASE) {
  await client.end();
  throw new Error('Refusing to migrate a database that is not the disposable database');
}
await client.query(`
  CREATE TABLE IF NOT EXISTS schema_migrations (
    version TEXT PRIMARY KEY,
    checksum TEXT NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
  )
`);
const applied = await client.query(`SELECT version FROM schema_migrations`);
const have = new Set(applied.rows.map((item) => item.version));
let count = 0;
for (const filename of files) {
  const version = filename.replace(/\.sql$/, '');
  if (have.has(version)) {
    continue;
  }
  const sql = readFileSync(join(dir, filename), 'utf8');
  const checksum = createHash('sha256').update(sql).digest('hex');
  try {
    await client.query('BEGIN');
    await client.query(sql);
    await client.query(
      `INSERT INTO schema_migrations (version, checksum) VALUES ($1, $2)`,
      [version, checksum],
    );
    await client.query('COMMIT');
    count += 1;
    console.log(`APPLY ${version}`);
  } catch (err) {
    await client.query('ROLLBACK');
    await client.end();
    const message = err instanceof Error ? err.message : 'migration failed';
    throw new Error(`Failed on ${filename}: ${message}`);
  }
}
await client.end();
console.log(`Disposable migrations applied: ${count}`);
