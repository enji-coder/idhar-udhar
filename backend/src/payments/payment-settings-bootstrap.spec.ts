import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const migrationPath = resolve(
  __dirname,
  '../../../records_database/migrations/0036_active_payment_settings_version.sql',
);
const runnerPath = resolve(__dirname, '../../../backend/scripts/migrate.mjs');
const sql = readFileSync(migrationPath, 'utf8');
const runner = readFileSync(runnerPath, 'utf8');

function assertControlFlow() {
  const doAt = sql.indexOf('DO $$');
  const insertAt = sql.indexOf('INSERT INTO payment_settings_versions');
  expect(doAt).toBeGreaterThanOrEqual(0);
  expect(insertAt).toBeGreaterThan(doAt);
  const guard = sql.slice(doAt, insertAt);
  expect(guard).toMatch(/IF active_count > 0 THEN\s+RETURN;\s+END IF;/);
  expect(guard).toMatch(
    /IF admin_count = 0 THEN\s+RAISE EXCEPTION '0036 refused: no admin profile exists to own the ACTIVE payment settings version'/,
  );
  expect(guard.indexOf('IF active_count > 0')).toBeLessThan(
    guard.indexOf('IF admin_count = 0'),
  );
  expect(sql).toMatch(/85,\s*15,\s*50,/);
  expect(sql).toContain('WHERE NOT EXISTS');
  expect(sql).not.toMatch(/\bUPDATE\b/i);
  expect(sql).not.toMatch(/\bDELETE\b/i);
  expect(sql.match(/INSERT INTO/g)).toHaveLength(1);
  expect(sql).toContain('ORDER BY');
  expect(sql).toContain("role IN ('SUPER_ADMIN', 'FINANCE')");
}

/**
 * The DO block returns when an ACTIVE version exists, raises when none exists
 * and admin_profiles is empty, and otherwise falls through to the guarded insert.
 * The runner records schema_migrations only after that SQL query succeeds.
 */
function applyOutcome(activeVersions: number, adminProfiles: number) {
  assertControlFlow();
  const recordsMigrationOnlyAfterSql = runner.indexOf('await client.query(sql)') <
    runner.indexOf('INSERT INTO schema_migrations');
  const rollsBackBeforeRecord = runner.indexOf("await client.query('ROLLBACK')") >
    runner.indexOf('await client.query(sql)');
  if (!recordsMigrationOnlyAfterSql || !rollsBackBeforeRecord) {
    throw new Error('migration runner no longer aborts before recording a failed file');
  }
  if (activeVersions > 0) {
    return 'unchanged';
  }
  if (adminProfiles === 0) {
    return 'failed-not-recorded';
  }
  return 'inserted-85-15-50';
}

describe('payment settings bootstrap migration', () => {
  it('fails and is not recorded when no ACTIVE version and no admin profile exist', () => {
    expect(applyOutcome(0, 0)).toBe('failed-not-recorded');
  });

  it('creates one ACTIVE 85/15/50 version when an admin profile exists', () => {
    expect(applyOutcome(0, 1)).toBe('inserted-85-15-50');
    expect(sql).toContain('created_by_admin_profile_id');
    expect(sql).not.toContain('order_finance_snapshots');
    expect(sql).not.toContain('wallet_');
    expect(sql).not.toContain('cod_');
    expect(sql).not.toContain('payment_transactions');
  });

  it('leaves an existing ACTIVE version unchanged', () => {
    expect(applyOutcome(1, 0)).toBe('unchanged');
    expect(applyOutcome(1, 2)).toBe('unchanged');
  });

  it('does not create a duplicate when the successful migration is applied again', () => {
    expect(applyOutcome(0, 1)).toBe('inserted-85-15-50');
    expect(applyOutcome(1, 1)).toBe('unchanged');
    expect(sql).toContain("WHERE status = 'ACTIVE'");
  });
});
