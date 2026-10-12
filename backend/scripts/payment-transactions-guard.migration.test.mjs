import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { migrationVersion, planMigrations } from './migrate.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const migrationsDir = resolve(root, 'records_database', 'migrations');
const filename = '0031_payment_failed_to_paid.sql';
const sql = readFileSync(resolve(migrationsDir, filename), 'utf8');

const IMMUTABLE_COLUMNS = [
  'payment_transaction_id',
  'order_id',
  'payer_type',
  'method',
  'amount',
  'direction',
  'provider_txn_id',
  'provider_event_id',
  'idempotency_key',
  'created_by_type',
  'created_by_profile_id',
  'created_at',
];

test('0031 is the next unused migration version', () => {
  const versions = readdirSync(migrationsDir)
    .map((name) => migrationVersion(name))
    .filter(Boolean);
  assert.equal(versions.filter((version) => version.startsWith('0031_')).length, 1);
  const numbers = versions.map((version) => Number.parseInt(version.slice(0, 4), 10));
  assert.equal(Math.max(...numbers), 31);
  assert.equal(migrationVersion(filename), '0031_payment_failed_to_paid');
});

test('an environment that already applied 0030 will apply 0031 once', () => {
  const filenames = readdirSync(migrationsDir).filter((name) => name.endsWith('.sql'));
  const applied = filenames
    .map((name) => migrationVersion(name))
    .filter((version) => version && version !== '0031_payment_failed_to_paid');
  const missing = planMigrations(filenames, applied);
  assert.deepEqual(
    missing.apply.map((item) => item.filename),
    [filename],
  );
  const again = planMigrations(filenames, [...applied, '0031_payment_failed_to_paid']);
  assert.equal(
    again.apply.some((item) => item.filename === filename),
    false,
  );
});

test('the replacement function permits FAILED to PAID and keeps the other rules', () => {
  assert.match(sql, /CREATE OR REPLACE FUNCTION payment_transactions_guard\(\)/);
  assert.doesNotMatch(sql, /DROP (TRIGGER|FUNCTION)/i);
  assert.doesNotMatch(sql, /CREATE TRIGGER/i);
  assert.match(sql, /payment_transactions cannot be deleted/);
  assert.match(
    sql,
    /OLD\.transaction_status = 'PENDING' AND NEW\.transaction_status IN \('PAID', 'FAILED'\)/,
  );
  assert.match(
    sql,
    /OLD\.transaction_status = 'FAILED' AND NEW\.transaction_status = 'PAID'/,
  );
  assert.match(sql, /illegal payment transaction_status transition/);
  assert.match(sql, /payment_transactions identity\/money columns are immutable/);
  for (const column of IMMUTABLE_COLUMNS) {
    assert.match(sql, new RegExp(`NEW\\.${column} IS DISTINCT FROM OLD\\.${column}`));
  }
  assert.doesNotMatch(
    sql,
    /OLD\.transaction_status = 'PAID' AND NEW\.transaction_status = 'REFUNDED'/,
  );
  assert.doesNotMatch(
    sql,
    /OLD\.transaction_status = 'PAID' AND NEW\.transaction_status = 'FAILED'/,
  );
  assert.doesNotMatch(
    sql,
    /OLD\.transaction_status = 'REFUNDED' AND NEW\.transaction_status = 'PAID'/,
  );
});
