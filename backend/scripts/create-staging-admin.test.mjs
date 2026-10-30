import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import {
  assertStagingAdminConfirmation,
  assertStagingAdminTarget,
  planStagingAdmin,
  PRODUCTION_DATABASE_HOST,
  readAdminPassword,
  runStagingAdminBootstrap,
  STAGING_DATABASE_HOST,
  STAGING_DATABASE_NAME,
} from './create-staging-admin.mjs';

const stagingEnv = {
  IU_DEPLOYMENT_TIER: 'staging',
  DATABASE_HOST: STAGING_DATABASE_HOST,
  DATABASE_NAME: STAGING_DATABASE_NAME,
  ADMIN_EMAIL: 'staging-admin@example.test',
  ADMIN_PASSWORD: 'test-password-not-a-secret',
  STAGING_ADMIN_CONFIRM: 'create-staging-admin',
  NODE_ENV: 'production',
};

function sqlText(call) {
  return typeof call === 'string' ? call : call.text;
}

function fakeClient({
  databaseName = STAGING_DATABASE_NAME,
  admins = [],
  identity = null,
} = {}) {
  const calls = [];
  return {
    calls,
    async connect() {
      calls.push('connect');
    },
    async end() {
      calls.push('end');
    },
    async query(sql, params) {
      const text = String(sql).replace(/\s+/g, ' ').trim();
      calls.push({ text, params });
      if (text.startsWith('BEGIN') || text === 'COMMIT' || text === 'ROLLBACK') {
        return { rows: [] };
      }
      if (text.includes('current_database() AS database_name') && text.includes('FROM admin_profiles')) {
        return {
          rows: [
            {
              database_name: databaseName,
              auth_status: 'ACTIVE',
              role: 'SUPER_ADMIN',
              active: true,
              password_set: true,
            },
          ],
        };
      }
      if (text.startsWith('SELECT current_database()')) {
        return { rows: [{ database_name: databaseName }] };
      }
      if (text.includes('FROM admin_profiles a')) {
        return { rows: admins };
      }
      if (text.includes('FROM identities i')) {
        return { rows: identity ? [identity] : [] };
      }
      if (text.includes('INSERT INTO identities')) {
        return { rows: [{ identity_id: 'identity-1' }] };
      }
      if (text.includes('INSERT INTO admin_profiles')) {
        return { rows: [{ admin_profile_id: 'admin-1' }] };
      }
      throw new Error(`unexpected query: ${text}`);
    },
  };
}

test('production tier and production host are refused before connect', async () => {
  assert.throws(
    () => assertStagingAdminTarget({ ...stagingEnv, IU_DEPLOYMENT_TIER: 'production' }),
    /Refusing IU_DEPLOYMENT_TIER=production/,
  );
  assert.throws(
    () => assertStagingAdminTarget({ ...stagingEnv, DATABASE_HOST: PRODUCTION_DATABASE_HOST }),
    /Refusing production database host/,
  );
  const client = fakeClient();
  await assert.rejects(
    () => runStagingAdminBootstrap({
      env: { ...stagingEnv, IU_DEPLOYMENT_TIER: 'production' },
      client,
    }),
    /Refusing IU_DEPLOYMENT_TIER=production/,
  );
  assert.equal(client.calls.includes('connect'), false);
});

test('wrong database name is refused before connect and after connect', async () => {
  assert.throws(
    () => assertStagingAdminTarget({ ...stagingEnv, DATABASE_NAME: 'idhar_udhar' }),
    /expected idhar_udhar_staging/,
  );
  const client = fakeClient({ databaseName: 'idhar_udhar' });
  await assert.rejects(
    () => runStagingAdminBootstrap({ env: stagingEnv, client }),
    /Refusing connected database/,
  );
  assert.equal(client.calls.some((call) => sqlText(call).includes('INSERT')), false);
});

test('missing tier, database, confirmation, and password are refused', () => {
  assert.throws(
    () => assertStagingAdminTarget({ ...stagingEnv, IU_DEPLOYMENT_TIER: '' }),
    /IU_DEPLOYMENT_TIER=staging is required/,
  );
  assert.throws(
    () => assertStagingAdminTarget({ NODE_ENV: 'staging', DATABASE_HOST: STAGING_DATABASE_HOST, DATABASE_NAME: STAGING_DATABASE_NAME }),
    /IU_DEPLOYMENT_TIER=staging is required/,
  );
  assert.throws(
    () => assertStagingAdminTarget({ ...stagingEnv, DATABASE_NAME: '' }),
    /DATABASE_NAME is required/,
  );
  assert.throws(
    () => assertStagingAdminTarget({ ...stagingEnv, DATABASE_HOST: '' }),
    /DATABASE_HOST is required/,
  );
  assert.throws(
    () => assertStagingAdminConfirmation({ STAGING_ADMIN_DRY_RUN: '0' }),
    /STAGING_ADMIN_CONFIRM=create-staging-admin/,
  );
  assert.throws(
    () => readAdminPassword({ ADMIN_PASSWORD: '' }),
    /ADMIN_PASSWORD is required/,
  );
});

test('duplicate and existing accounts are refused without writes', async () => {
  assert.throws(
    () => planStagingAdmin({
      email: 'new@example.test',
      admins: [{ email: 'other@example.test', role: 'SUPER_ADMIN', active: true, auth_status: 'ACTIVE' }],
      identity: null,
    }),
    /Refusing a second admin account/,
  );
  assert.throws(
    () => planStagingAdmin({
      email: 'person@example.test',
      admins: [],
      identity: { identity_id: 'identity-9', admin_profile_id: null },
    }),
    /existing identity/,
  );

  const client = fakeClient({
    admins: [{
      email: 'other@example.test',
      role: 'SUPER_ADMIN',
      active: true,
      auth_status: 'ACTIVE',
    }],
  });
  await assert.rejects(
    () => runStagingAdminBootstrap({ env: stagingEnv, client }),
    /Refusing a second admin account/,
  );
  assert.equal(client.calls.some((call) => sqlText(call).includes('INSERT')), false);
});

test('valid staging setup creates one argon2id admin and does not log the password', async () => {
  assertStagingAdminTarget(stagingEnv);
  const lines = [];
  const client = fakeClient();
  const result = await runStagingAdminBootstrap({
    env: stagingEnv,
    client,
    write: (line) => lines.push(line),
  });
  assert.equal(result.action, 'created');
  assert.match(lines.join('\n'), /staging_admin created/);
  assert.equal(lines.join('\n').includes('test-password-not-a-secret'), false);
  assert.equal(lines.join('\n').includes(stagingEnv.ADMIN_EMAIL), false);
  const insert = client.calls.find((call) => sqlText(call).includes('INSERT INTO admin_profiles'));
  assert.equal(typeof insert, 'object');
  assert.match(insert.params[1], /^\$argon2id\$/);
  assert.equal(insert.params[1].includes(stagingEnv.ADMIN_PASSWORD), false);
});

test('the same active staging admin is idempotent and dry-run does not insert', async () => {
  const present = fakeClient({
    admins: [{
      email: stagingEnv.ADMIN_EMAIL,
      role: 'SUPER_ADMIN',
      active: true,
      auth_status: 'ACTIVE',
    }],
    identity: { identity_id: 'identity-1', admin_profile_id: 'admin-1' },
  });
  const lines = [];
  const again = await runStagingAdminBootstrap({
    env: stagingEnv,
    client: present,
    write: (line) => lines.push(line),
  });
  assert.equal(again.action, 'already_present');
  assert.equal(present.calls.some((call) => sqlText(call).includes('INSERT')), false);
  assert.match(lines.join('\n'), /already_present/);

  const dry = fakeClient();
  const dryLines = [];
  const preview = await runStagingAdminBootstrap({
    env: { ...stagingEnv, STAGING_ADMIN_DRY_RUN: '1', STAGING_ADMIN_CONFIRM: '', ADMIN_PASSWORD: '' },
    client: dry,
    write: (line) => dryLines.push(line),
  });
  assert.equal(preview.action, 'dry_run');
  assert.equal(dry.calls.some((call) => sqlText(call).includes('INSERT')), false);
  assert.match(dryLines.join('\n'), /dry_run action=create/);
  assert.equal(dry.calls.some((call) => sqlText(call).includes('BEGIN READ ONLY')), true);
});

test('the staging script does not load env files or the production bootstrap', () => {
  const source = readFileSync(new URL('./create-staging-admin.mjs', import.meta.url), 'utf8');
  assert.equal(source.includes('create-production-admin'), false);
  assert.equal(source.includes('loadEnv('), false);
  assert.equal(source.includes("'.env'"), false);
});
