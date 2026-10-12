/**
 * Applies exactly one SQL migration file and records it in schema_migrations.
 * Does not scan or apply any other pending file.
 *
 * Required:
 *   MIGRATION_ONLY=0031_payment_failed_to_paid.sql
 *   MIGRATE_CONFIRM=apply-one
 *
 * Does not print passwords, SQL, or connection strings.
 */
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import pg from 'pg';
import { migrationVersion, sha256Hex } from './migrate.mjs';

export const ONLY_MIGRATION = '0031_payment_failed_to_paid.sql';

export const FAILED_TO_PAID_FRAGMENT =
  "OLD.transaction_status = 'FAILED' AND NEW.transaction_status = 'PAID'";

/**
 * Pure assessment of guard verification evidence.
 * Incomplete probes (missing rows) are never treated as success.
 *
 * @param {{
 *   functionBody: string,
 *   failedToPaid: null | { outcome: 'allowed' | 'rejected', rows: number },
 *   paidToFailed: null | { outcome: 'allowed' | 'rejected', rows: number },
 *   sameAmountRewrite: null | { outcome: 'allowed' | 'rejected', rows: number },
 *   amountChange: null | { outcome: 'allowed' | 'rejected', rows: number },
 * }} evidence
 */
export function assessGuardVerification(evidence) {
  const lines = [];
  const failures = [];
  const incomplete = [];

  const body = String(evidence.functionBody ?? '');
  const hasRecovery = body.includes(FAILED_TO_PAID_FRAGMENT);
  lines.push(`function_failed_to_paid=${hasRecovery ? 'present' : 'missing'}`);
  if (!hasRecovery) {
    failures.push(
      'required FAILED → PAID guard rule is missing from payment_transactions_guard()',
    );
  }

  if (evidence.failedToPaid == null) {
    lines.push('probe_failed_to_paid=incomplete no_failed_row');
    incomplete.push(
      'no FAILED payment_transactions row available to probe FAILED → PAID',
    );
  } else {
    lines.push(
      `probe_failed_to_paid=${evidence.failedToPaid.outcome} rows=${evidence.failedToPaid.rows}`,
    );
    if (
      evidence.failedToPaid.outcome !== 'allowed' ||
      evidence.failedToPaid.rows < 1
    ) {
      failures.push('FAILED → PAID must be allowed');
    }
  }

  if (evidence.paidToFailed == null) {
    lines.push('probe_paid_to_failed=incomplete no_paid_row');
    incomplete.push(
      'no PAID payment_transactions row available to probe PAID → FAILED',
    );
  } else {
    lines.push(`probe_paid_to_failed=${evidence.paidToFailed.outcome}`);
    if (evidence.paidToFailed.outcome !== 'rejected') {
      failures.push('PAID → FAILED must be rejected');
    }
  }

  if (evidence.sameAmountRewrite == null) {
    lines.push('probe_same_amount_rewrite=incomplete no_paid_row');
    if (
      !incomplete.includes(
        'no PAID payment_transactions row available to probe PAID → FAILED',
      )
    ) {
      incomplete.push(
        'no PAID payment_transactions row available to probe same-amount rewrite',
      );
    }
  } else {
    lines.push(
      `probe_same_amount_rewrite=${evidence.sameAmountRewrite.outcome}`,
    );
    // 0031 uses IS DISTINCT FROM: a no-op SET amount = amount is allowed.
    // Money immutability is enforced by rejecting actual amount changes.
    if (evidence.sameAmountRewrite.outcome !== 'allowed') {
      failures.push(
        'no-op amount rewrite (SET amount = amount) must be allowed',
      );
    }
  }

  if (evidence.amountChange == null) {
    lines.push('probe_amount_change=incomplete no_paid_row');
    if (
      !incomplete.some((item) => item.includes('no PAID payment_transactions'))
    ) {
      incomplete.push(
        'no PAID payment_transactions row available to probe amount change',
      );
    }
  } else {
    lines.push(`probe_amount_change=${evidence.amountChange.outcome}`);
    if (evidence.amountChange.outcome !== 'rejected') {
      failures.push('changing amount must be rejected');
    }
  }

  return {
    ok: failures.length === 0 && incomplete.length === 0,
    lines,
    failures,
    incomplete,
  };
}

/**
 * @param {{
 *   failures: string[],
 *   incomplete: string[],
 *   migrationCommitted: boolean,
 * }} report
 */
export function formatVerificationFailure(report) {
  const parts = [];
  if (report.migrationCommitted) {
    parts.push(
      'Post-apply verification failed after the migration transaction already committed; the migration was not rolled back.',
    );
  }
  if (report.failures.length > 0) {
    parts.push(`Guard check failed: ${report.failures.join('; ')}`);
  }
  if (report.incomplete.length > 0) {
    parts.push(
      `Database verification incomplete: ${report.incomplete.join('; ')}`,
    );
  }
  if (parts.length === 0) {
    return 'Post-apply verification failed';
  }
  return parts.join(' ');
}

export function assertSingleMigrationRequest(env = process.env) {
  const requested = (env.MIGRATION_ONLY || '').trim();
  const confirm = (env.MIGRATE_CONFIRM || '').trim();
  if (requested !== ONLY_MIGRATION) {
    throw new Error(
      `MIGRATION_ONLY must be ${ONLY_MIGRATION}`,
    );
  }
  if (confirm !== 'apply-one') {
    throw new Error('Set MIGRATE_CONFIRM=apply-one');
  }
  const version = migrationVersion(requested);
  if (version !== '0031_payment_failed_to_paid') {
    throw new Error('0031 version did not match the filename');
  }
  return { filename: requested, version };
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
  const inImage = resolve(scriptDir, '..', 'records_database', 'migrations');
  if (existsSync(inImage)) {
    return inImage;
  }
  return resolve(scriptDir, '..', '..', 'records_database', 'migrations');
}

async function expectTransition(client, sql, params) {
  await client.query('SAVEPOINT probe');
  try {
    const result = await client.query(sql, params);
    await client.query('RELEASE SAVEPOINT probe');
    return { outcome: 'allowed', rows: result.rowCount ?? 0 };
  } catch {
    await client.query('ROLLBACK TO SAVEPOINT probe');
    return { outcome: 'rejected', rows: 0 };
  }
}

async function verifyGuard(client, { migrationCommitted }) {
  const definition = await client.query(
    `SELECT pg_get_functiondef('payment_transactions_guard()'::regprocedure) AS def`,
  );
  const functionBody = String(definition.rows[0]?.def ?? '');

  await client.query('BEGIN');
  let failedToPaid = null;
  let paidToFailed = null;
  let sameAmountRewrite = null;
  let amountChange = null;
  try {
    const failed = await client.query(
      `SELECT payment_transaction_id
       FROM payment_transactions
       WHERE transaction_status = 'FAILED'
       LIMIT 1`,
    );
    const paid = await client.query(
      `SELECT payment_transaction_id
       FROM payment_transactions
       WHERE transaction_status = 'PAID'
       LIMIT 1`,
    );
    const failedId = failed.rows[0]?.payment_transaction_id ?? null;
    const paidId = paid.rows[0]?.payment_transaction_id ?? null;

    if (failedId) {
      failedToPaid = await expectTransition(
        client,
        `UPDATE payment_transactions
         SET transaction_status = 'PAID'
         WHERE payment_transaction_id = $1
           AND transaction_status = 'FAILED'`,
        [failedId],
      );
    }

    if (paidId) {
      paidToFailed = await expectTransition(
        client,
        `UPDATE payment_transactions
         SET transaction_status = 'FAILED'
         WHERE payment_transaction_id = $1
           AND transaction_status = 'PAID'`,
        [paidId],
      );
      sameAmountRewrite = await expectTransition(
        client,
        `UPDATE payment_transactions
         SET amount = amount
         WHERE payment_transaction_id = $1`,
        [paidId],
      );
      amountChange = await expectTransition(
        client,
        `UPDATE payment_transactions
         SET amount = amount + 1
         WHERE payment_transaction_id = $1`,
        [paidId],
      );
    }
  } finally {
    await client.query('ROLLBACK');
  }
  process.stdout.write(
    'probe_transaction=rolled_back (verification probes only; migration commit is unchanged)\n',
  );

  const assessment = assessGuardVerification({
    functionBody,
    failedToPaid,
    paidToFailed,
    sameAmountRewrite,
    amountChange,
  });
  for (const line of assessment.lines) {
    process.stdout.write(`${line}\n`);
  }
  if (!assessment.ok) {
    throw new Error(
      formatVerificationFailure({
        failures: assessment.failures,
        incomplete: assessment.incomplete,
        migrationCommitted,
      }),
    );
  }
  process.stdout.write('verification=passed\n');
}

export async function applyOneMigration() {
  const { filename, version } = assertSingleMigrationRequest();
  const directory = migrationsDirectory();
  const path = join(directory, filename);
  if (!existsSync(path)) {
    throw new Error('Requested migration file was not found');
  }
  const bytes = readFileSync(path);
  const checksum = sha256Hex(bytes);
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
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version     TEXT PRIMARY KEY,
        filename    TEXT NOT NULL,
        checksum    TEXT NOT NULL,
        applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);
    const existing = await client.query(
      `SELECT version, filename, checksum
       FROM schema_migrations
       WHERE version = $1`,
      [version],
    );
    let migrationCommitted = false;
    if (existing.rows[0]) {
      const recorded = String(existing.rows[0].checksum).toLowerCase();
      if (recorded !== checksum) {
        throw new Error('0031 is already recorded with a different checksum');
      }
      process.stdout.write(`SKIP already applied: ${filename}\n`);
      // Already recorded from a prior commit; verification still must pass.
      migrationCommitted = true;
    } else {
      try {
        await client.query('BEGIN');
        await client.query(bytes.toString('utf8'));
        await client.query(
          `INSERT INTO schema_migrations (version, filename, checksum)
           VALUES ($1, $2, $3)`,
          [version, filename, checksum],
        );
        await client.query('COMMIT');
        migrationCommitted = true;
      } catch (error) {
        try {
          await client.query('ROLLBACK');
        } catch {
          // The connection may already have aborted the transaction.
        }
        const message = error instanceof Error ? error.message : 'migration failed';
        throw new Error(`Migration ${filename} failed: ${message}`);
      }
      process.stdout.write(`APPLY ${filename}\n`);
      process.stdout.write(`checksum=${checksum}\n`);
    }
    await verifyGuard(client, { migrationCommitted });
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
  applyOneMigration().catch((error) => {
    const message = error instanceof Error ? error.message : 'migration failed';
    process.stderr.write(`${message}\n`);
    process.exitCode = 1;
  });
}
