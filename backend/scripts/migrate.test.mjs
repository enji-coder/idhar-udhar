import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import {
  assertProductionMigrationIdentity,
  assertRecordedChecksums,
  assertUniqueNumericPrefixes,
  HISTORICAL_APPLIED_WITHOUT_BYTES,
  migrationNumericPrefix,
  planMigrations,
  PRODUCTION_FILE_CHECKSUMS,
  sha256Hex,
} from './migrate.mjs';

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

test('migrationNumericPrefix uses the leading four digits', () => {
  assert.equal(
    migrationNumericPrefix('0026_rider_wallet_topup_withdrawal.sql'),
    '0026',
  );
});

test('assertUniqueNumericPrefixes accepts a unique sequence', () => {
  assert.doesNotThrow(() =>
    assertUniqueNumericPrefixes([
      '0025_states_and_city_state.sql',
      '0026_rider_wallet_topup_withdrawal.sql',
      '0027_wallet_idempotency_scopes.sql',
    ]),
  );
});

test('a recorded checksum mismatch is refused before apply', () => {
  assert.throws(
    () =>
      assertRecordedChecksums(
        [{ version: '0027_idempotency_wallet_scopes', checksum: 'aaaa' }],
        new Map([['0027_idempotency_wallet_scopes', 'bbbb']]),
      ),
    /checksum does not match/,
  );
});

test('a matching recorded checksum is accepted', () => {
  assert.doesNotThrow(() =>
    assertRecordedChecksums(
      [{ version: '0027_idempotency_wallet_scopes', checksum: 'ABCD' }],
      new Map([['0027_idempotency_wallet_scopes', 'abcd']]),
    ),
  );
});

test('an empty recorded checksum is refused', () => {
  assert.throws(
    () =>
      assertRecordedChecksums(
        [{ version: '0032_admin_order_purge_wallet_reversal', checksum: '  ' }],
        new Map([['0032_admin_order_purge_wallet_reversal', 'abc']]),
      ),
    /0032_admin_order_purge_wallet_reversal/,
  );
});

test('migration prefixes are unique and production 0026 and 0027 checksums match', () => {
  const directory = resolve(root, 'records_database', 'migrations');
  const names = readdirSync(directory)
    .filter((name) => /^\d{4}_.+\.sql$/.test(name))
    .sort();
  assert.doesNotThrow(() => assertUniqueNumericPrefixes(names));
  assert.equal(
    names.filter((name) => name.startsWith('0026_')).length,
    1,
  );
  assert.equal(
    names.filter((name) => name.startsWith('0027_')).length,
    1,
  );
  assert.equal(
    names.filter((name) => name.startsWith('0028_')).length,
    0,
  );
  assert.ok(names.includes('0032_admin_order_purge_wallet_reversal.sql'));
  assert.ok(names.includes('0033_rider_withdrawal_payout_columns.sql'));
  assert.ok(names.includes('0034_payout_beneficiary_and_instrument.sql'));
  const checksums = new Map(
    names.map((name) => [
      name.replace(/\.sql$/, ''),
      sha256Hex(readFileSync(resolve(directory, name))),
    ]),
  );
  assert.doesNotThrow(() => assertProductionMigrationIdentity(checksums));
  for (const [version, expected] of Object.entries(PRODUCTION_FILE_CHECKSUMS)) {
    assert.equal(checksums.get(version), expected);
  }
  assert.equal(checksums.has('0028_payout_provider_references'), false);
  const forward = readFileSync(
    resolve(directory, '0033_rider_withdrawal_payout_columns.sql'),
    'utf8',
  );
  assert.match(forward, /ADD COLUMN IF NOT EXISTS provider_transfer_id/);
  assert.match(forward, /rww_provider_transfer_unique/);
  assert.match(forward, /rww_merchant_transfer_unique/);
  assert.match(forward, /rww_refund_ledger_unique/);
  assert.match(forward, /rww_processing_reconcile_idx/);
  assert.doesNotMatch(
    readFileSync(resolve(directory, '0026_rider_wallet_topup_withdrawal.sql'), 'utf8'),
    /provider_transfer_id/,
  );
  const beneficiary = readFileSync(
    resolve(directory, '0034_payout_beneficiary_and_instrument.sql'),
    'utf8',
  );
  assert.match(beneficiary, /cashfree_beneficiary_id/);
  assert.match(beneficiary, /cashfree_beneficiary_status/);
  assert.match(beneficiary, /rider_upis_cf_beneficiary_status_chk/);
  assert.match(beneficiary, /rider_bank_cf_beneficiary_status_chk/);
  assert.match(beneficiary, /rider_upis_cf_beneficiary_unique/);
  assert.match(beneficiary, /rider_bank_cf_beneficiary_unique/);
  assert.doesNotMatch(beneficiary, /DROP TABLE/i);
  assert.doesNotMatch(beneficiary, /TRUNCATE/i);
  assert.doesNotMatch(beneficiary, /CASCADE/i);
});

test('a recorded version with no local file is refused unless it is the unrecovered 0028 pin', () => {
  const pin = HISTORICAL_APPLIED_WITHOUT_BYTES['0028_payout_provider_references'];
  assert.doesNotThrow(() =>
    assertRecordedChecksums(
      [{ version: '0028_payout_provider_references', checksum: pin }],
      new Map(),
    ),
  );
  assert.throws(
    () =>
      assertRecordedChecksums(
        [{ version: '0028_payout_provider_references', checksum: 'deadbeef' }],
        new Map(),
      ),
    /0028_payout_provider_references/,
  );
  assert.throws(
    () =>
      assertRecordedChecksums(
        [{ version: '0029_order_crn', checksum: 'abc' }],
        new Map(),
      ),
    /no local file/,
  );
  const plan = planMigrations(
    ['0029_order_crn.sql', '0033_rider_withdrawal_payout_columns.sql'],
    ['0028_payout_provider_references'],
  );
  assert.deepEqual(
    plan.apply.map((item) => item.version),
    ['0029_order_crn', '0033_rider_withdrawal_payout_columns'],
  );
  assert.equal(
    plan.apply.some((item) => item.version === '0028_payout_provider_references'),
    false,
  );
});

test('a guessed 0028 file is refused before it can be applied', () => {
  assert.throws(
    () =>
      assertProductionMigrationIdentity(
        new Map([
          [
            '0026_rider_wallet_topup_withdrawal',
            PRODUCTION_FILE_CHECKSUMS['0026_rider_wallet_topup_withdrawal'],
          ],
          [
            '0027_wallet_idempotency_scopes',
            PRODUCTION_FILE_CHECKSUMS['0027_wallet_idempotency_scopes'],
          ],
          ['0028_payout_provider_references', 'a'.repeat(64)],
        ]),
      ),
    /Unrecovered production migration/,
  );
});

test('assertUniqueNumericPrefixes refuses duplicate prefixes', () => {
  assert.throws(
    () =>
      assertUniqueNumericPrefixes([
        '0026_rider_wallet_topup_withdrawal.sql',
        '0026_rider_wallet_topup_withdrawals.sql',
      ]),
    /Duplicate migration numeric prefixes/,
  );
});
