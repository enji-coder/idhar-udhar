import { existsSync, readFileSync } from 'node:fs';
import { execSync } from 'node:child_process';
import { resolve } from 'node:path';
import pg from 'pg';

function load(path) {
  if (!existsSync(path)) return;
  for (const line of readFileSync(path, 'utf8').split(/\r?\n/)) {
    const t = line.trim();
    if (!t || t.startsWith('#') || !t.includes('=')) continue;
    const i = t.indexOf('=');
    const k = t.slice(0, i).trim();
    let v = t.slice(i + 1).trim();
    if (
      (v.startsWith('"') && v.endsWith('"')) ||
      (v.startsWith("'") && v.endsWith("'"))
    ) {
      v = v.slice(1, -1);
    }
    if (process.env[k] === undefined) process.env[k] = v;
  }
}

load(resolve(process.cwd(), '.env'));

const filePass = process.env.DATABASE_PASSWORD || '';
const host = process.env.DATABASE_HOST || '127.0.0.1';
const port = Number(process.env.DATABASE_PORT || 5432);
const database = process.env.DATABASE_NAME || 'idhar_udhar';
const user = process.env.DATABASE_USER || 'idhar_admin';
const containerPass = execSync(
  'docker exec idhar_udhar_postgres printenv POSTGRES_PASSWORD',
  { encoding: 'utf8' },
).trim();

async function tryConnect(label, password) {
  const client = new pg.Client({
    host,
    port,
    database,
    user,
    password,
    ssl: false,
    connectionTimeoutMillis: 5000,
  });
  try {
    await client.connect();
    const result = await client.query(`
      SELECT
        current_database() AS db,
        inet_server_addr()::text AS server_addr,
        (SELECT count(*)::int FROM schema_migrations
          WHERE version = '0025_states_and_city_state') AS has_0025,
        (SELECT count(*)::int FROM schema_migrations
          WHERE version = '0026_rider_wallet_topup_withdrawals') AS has_0026,
        (SELECT count(*)::int FROM information_schema.tables
          WHERE table_schema='public' AND table_name='rider_wallet_withdrawals') AS has_withdrawals
    `);
    await client.end();
    return { label, ok: true, ...result.rows[0] };
  } catch (err) {
    try {
      await client.end();
    } catch {
      /* ignore */
    }
    return { label, ok: false, code: err.code, message: err.message };
  }
}

console.log(
  JSON.stringify(
    {
      target: { host, port, database, user },
      pass_meta: {
        file_len: filePass.length,
        container_len: containerPass.length,
        equal: filePass === containerPass,
      },
      results: [
        await tryConnect('env_file_pass', filePass),
        await tryConnect('container_pass', containerPass),
      ],
    },
    null,
    2,
  ),
);
