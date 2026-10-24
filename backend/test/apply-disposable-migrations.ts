import { createHash } from 'node:crypto';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { Client } from 'pg';

const DISPOSABLE_NAME = 'idhar_udhar_disposable';
const DISPOSABLE_PORT = '54329';

/** Prefixes are unique. Apply every file, including the production 0026 and 0027. */
const SKIP_ON_EMPTY_DISPOSABLE = new Set<string>();

export function assertDisposableTarget(env: NodeJS.ProcessEnv = process.env): void {
  if (env.DATABASE_HOST !== '127.0.0.1' || env.DATABASE_PORT !== DISPOSABLE_PORT) {
    throw new Error('Disposable migration refused: host or port is not the local disposable database');
  }
  if (env.DATABASE_NAME !== DISPOSABLE_NAME) {
    throw new Error('Disposable migration refused: database name is not idhar_udhar_disposable');
  }
  if (env.DATABASE_SSL === 'true') {
    throw new Error('Disposable migration refused: SSL target is not the local container');
  }
}

export async function applyDisposableMigrations(migrationsDir: string): Promise<string[]> {
  assertDisposableTarget();
  const client = new Client({
    host: '127.0.0.1',
    port: Number(DISPOSABLE_PORT),
    database: DISPOSABLE_NAME,
    user: process.env.DATABASE_USER,
    password: process.env.DATABASE_PASSWORD,
  });
  await client.connect();
  try {
    const applied = await client.query<{ version: string }>(
      `
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = 'schema_migrations'
      `,
    );
    const have = new Set<string>();
    if ((applied.rowCount ?? 0) > 0) {
      const rows = await client.query<{ version: string }>(
        `SELECT version FROM schema_migrations`,
      );
      rows.rows.forEach((row) => have.add(row.version));
    }
    const filenames = readdirSync(migrationsDir)
      .filter((name) => /^\d{4}_.+\.sql$/.test(name) && !SKIP_ON_EMPTY_DISPOSABLE.has(name))
      .sort((left, right) => (left < right ? -1 : left > right ? 1 : 0));
    const ran: string[] = [];
    for (const filename of filenames) {
      const version = filename.replace(/\.sql$/, '');
      if (have.has(version)) {
        continue;
      }
      const sql = readFileSync(join(migrationsDir, filename), 'utf8');
      const checksum = createHash('sha256').update(sql).digest('hex');
      await client.query('BEGIN');
      try {
        await client.query(sql);
        await client.query(
          `
          CREATE TABLE IF NOT EXISTS schema_migrations (
            version TEXT PRIMARY KEY,
            checksum TEXT NOT NULL,
            applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
          )
          `,
        );
        await client.query(
          `INSERT INTO schema_migrations (version, checksum) VALUES ($1, $2)`,
          [version, checksum],
        );
        await client.query('COMMIT');
        ran.push(filename);
      } catch (err) {
        await client.query('ROLLBACK');
        const message = err instanceof Error ? err.message : 'migration failed';
        throw new Error(`${filename}: ${message}`);
      }
    }
    return ran;
  } finally {
    await client.end();
  }
}
