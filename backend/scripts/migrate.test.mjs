import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { planMigrations, sha256Hex } from './migrate.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const migrationFile = resolve(
  root,
  'records_database',
  'migrations',
  '0019_cashfree_gateway.sql',
);

const productionApplied = [
  '0018_vehicle_category_commission_split',
  '0020_vehicle_category_hierarchy',
  '0021_rider_document_verification_source',
  '0022_rider_profile_picture_language_reopen',
  '0023_order_package_weight',
];

const filenames = [
  '0018_vehicle_category_commission_split.sql',
  '0019_cashfree_gateway.sql',
  '0020_vehicle_category_hierarchy.sql',
  '0021_rider_document_verification_source.sql',
  '0022_rider_profile_picture_language_reopen.sql',
  '0023_order_package_weight.sql',
];

test('a missing earlier migration is applied and later applied versions are skipped', () => {
  const plan = planMigrations(filenames, productionApplied);
  assert.deepEqual(
    plan.apply.map((item) => item.version),
    ['0019_cashfree_gateway'],
  );
  assert.deepEqual(
    plan.skip.map((item) => item.version),
    productionApplied,
  );
});

test('an applied 0019 is not selected again', () => {
  const plan = planMigrations(filenames, [
    ...productionApplied,
    '0019_cashfree_gateway',
  ]);
  assert.deepEqual(plan.apply, []);
});

test('0019 file checksum matches the confirmed production digest', () => {
  const bytes = readFileSync(migrationFile);
  assert.equal(
    sha256Hex(bytes),
    'ebb61a59ee095441bca87d6ed77ca614b0d58416aad2b0e68a2fdbae8ab0363c',
  );
});
