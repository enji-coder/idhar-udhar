import assert from 'node:assert/strict';
import test from 'node:test';
import {
  FAILED_TO_PAID_FRAGMENT,
  ONLY_MIGRATION,
  assertSingleMigrationRequest,
  assessGuardVerification,
  formatVerificationFailure,
} from './apply-one-migration.mjs';

const GUARD_WITH_RECOVERY = `
CREATE OR REPLACE FUNCTION payment_transactions_guard()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF ${FAILED_TO_PAID_FRAGMENT} THEN
    RETURN NEW;
  END IF;
END;
$$;
`;

const GUARD_WITHOUT_RECOVERY = `
CREATE OR REPLACE FUNCTION payment_transactions_guard()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.transaction_status = 'PENDING' AND NEW.transaction_status IN ('PAID', 'FAILED') THEN
    RETURN NEW;
  END IF;
END;
$$;
`;

const allowed = { outcome: 'allowed', rows: 1 };
const rejected = { outcome: 'rejected', rows: 0 };

function completeEvidence(overrides = {}) {
  return {
    functionBody: GUARD_WITH_RECOVERY,
    failedToPaid: allowed,
    paidToFailed: rejected,
    sameAmountRewrite: allowed,
    amountChange: rejected,
    ...overrides,
  };
}

test('accepts only the 0031 file with apply-one confirmation', () => {
  const result = assertSingleMigrationRequest({
    MIGRATION_ONLY: ONLY_MIGRATION,
    MIGRATE_CONFIRM: 'apply-one',
  });
  assert.equal(result.filename, '0031_payment_failed_to_paid.sql');
  assert.equal(result.version, '0031_payment_failed_to_paid');
});

test('refuses the full migration runner confirmation', () => {
  assert.throws(
    () =>
      assertSingleMigrationRequest({
        MIGRATION_ONLY: ONLY_MIGRATION,
        MIGRATE_CONFIRM: 'apply-missing',
      }),
    /MIGRATE_CONFIRM=apply-one/,
  );
});

test('refuses every other migration filename', () => {
  for (const filename of [
    '0026_rider_wallet_topup_withdrawal.sql',
    '0026_rider_wallet_topup_withdrawals.sql',
    '0027_wallet_idempotency_scopes.sql',
    '0028_withdrawal_payout_refs.sql',
    '0030_something.sql',
  ]) {
    assert.throws(
      () =>
        assertSingleMigrationRequest({
          MIGRATION_ONLY: filename,
          MIGRATE_CONFIRM: 'apply-one',
        }),
      /MIGRATION_ONLY must be/,
    );
  }
});

test('verification passes when the FAILED → PAID rule and all probes match', () => {
  const result = assessGuardVerification(completeEvidence());
  assert.equal(result.ok, true);
  assert.deepEqual(result.failures, []);
  assert.deepEqual(result.incomplete, []);
  assert.equal(result.lines[0], 'function_failed_to_paid=present');
  assert.match(result.lines.join('\n'), /probe_failed_to_paid=allowed rows=1/);
  assert.match(result.lines.join('\n'), /probe_paid_to_failed=rejected/);
  assert.match(result.lines.join('\n'), /probe_same_amount_rewrite=allowed/);
  assert.match(result.lines.join('\n'), /probe_amount_change=rejected/);
});

test('verification fails when the FAILED → PAID rule is missing', () => {
  const result = assessGuardVerification(
    completeEvidence({ functionBody: GUARD_WITHOUT_RECOVERY }),
  );
  assert.equal(result.ok, false);
  assert.equal(result.lines[0], 'function_failed_to_paid=missing');
  assert.match(
    result.failures.join('; '),
    /required FAILED → PAID guard rule is missing/,
  );
});

test('verification fails when FAILED → PAID is rejected', () => {
  const result = assessGuardVerification(
    completeEvidence({ failedToPaid: rejected }),
  );
  assert.equal(result.ok, false);
  assert.match(result.failures.join('; '), /FAILED → PAID must be allowed/);
});

test('verification fails when FAILED → PAID reports zero updated rows', () => {
  const result = assessGuardVerification(
    completeEvidence({ failedToPaid: { outcome: 'allowed', rows: 0 } }),
  );
  assert.equal(result.ok, false);
  assert.match(result.failures.join('; '), /FAILED → PAID must be allowed/);
});

test('verification fails when PAID → FAILED is allowed', () => {
  const result = assessGuardVerification(
    completeEvidence({ paidToFailed: allowed }),
  );
  assert.equal(result.ok, false);
  assert.match(result.failures.join('; '), /PAID → FAILED must be rejected/);
});

test('verification fails when an amount change is allowed', () => {
  const result = assessGuardVerification(
    completeEvidence({ amountChange: allowed }),
  );
  assert.equal(result.ok, false);
  assert.match(result.failures.join('; '), /changing amount must be rejected/);
});

test('verification fails when a no-op amount rewrite is unexpectedly rejected', () => {
  const result = assessGuardVerification(
    completeEvidence({ sameAmountRewrite: rejected }),
  );
  assert.equal(result.ok, false);
  assert.match(result.failures.join('; '), /no-op amount rewrite/);
});

test('missing FAILED row is incomplete, not a successful verification', () => {
  const result = assessGuardVerification(
    completeEvidence({ failedToPaid: null }),
  );
  assert.equal(result.ok, false);
  assert.deepEqual(result.failures, []);
  assert.match(
    result.incomplete.join('; '),
    /no FAILED payment_transactions row/,
  );
  assert.match(result.lines.join('\n'), /probe_failed_to_paid=incomplete/);
});

test('missing PAID row is incomplete, not a successful verification', () => {
  const result = assessGuardVerification(
    completeEvidence({
      paidToFailed: null,
      sameAmountRewrite: null,
      amountChange: null,
    }),
  );
  assert.equal(result.ok, false);
  assert.deepEqual(result.failures, []);
  assert.match(result.incomplete.join('; '), /no PAID payment_transactions row/);
  assert.match(result.lines.join('\n'), /probe_paid_to_failed=incomplete/);
  assert.match(result.lines.join('\n'), /probe_same_amount_rewrite=incomplete/);
  assert.match(result.lines.join('\n'), /probe_amount_change=incomplete/);
});

test('failure message states the migration was not rolled back after commit', () => {
  const message = formatVerificationFailure({
    migrationCommitted: true,
    failures: ['FAILED → PAID must be allowed'],
    incomplete: [],
  });
  assert.match(message, /already committed/);
  assert.match(message, /was not rolled back/);
  assert.match(message, /FAILED → PAID must be allowed/);
  assert.doesNotMatch(message, /migration was rolled back/i);
});

test('failure message reports incomplete database verification separately', () => {
  const message = formatVerificationFailure({
    migrationCommitted: true,
    failures: [],
    incomplete: [
      'no FAILED payment_transactions row available to probe FAILED → PAID',
    ],
  });
  assert.match(message, /already committed/);
  assert.match(message, /Database verification incomplete/);
  assert.match(message, /no FAILED payment_transactions row/);
});
