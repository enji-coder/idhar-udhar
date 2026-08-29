import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { PostgresService } from '../src/database/postgres.service';
import {
  assertNoSecrets,
  createTestApp,
  deleteIdentity,
  insertAdminFixture,
} from './helpers';

describe('Admin authentication (e2e)', () => {
  let app: INestApplication;
  let postgres: PostgresService;
  const identityIds: string[] = [];

  beforeAll(async () => {
    app = await createTestApp();
    postgres = app.get(PostgresService);
  });

  afterAll(async () => {
    for (const identityId of identityIds) {
      await deleteIdentity(postgres, identityId);
    }
    await app.close();
  });

  it('logs in with a valid password and never returns the hash', async () => {
    const password = 'AdminPass#2026!!';
    const fixture = await insertAdminFixture(app, password);
    identityIds.push(fixture.identityId);

    const stored = await postgres.query<{ password_hash: string }>(
      'SELECT password_hash FROM admin_profiles WHERE admin_profile_id = $1',
      [fixture.profileId],
    );
    expect(stored.rows[0].password_hash).toMatch(/^\$argon2id\$/);
    expect(stored.rows[0].password_hash).not.toBe(password);

    const login = await request(app.getHttpServer())
      .post('/v1/admin/auth/login')
      .send({ email: fixture.email, password });
    expect(login.status).toBe(200);
    expect(login.body.role).toBe('ADMIN');
    expect(login.body.access_token).toBeDefined();
    assertNoSecrets(login.body);
    expect(JSON.stringify(login.body)).not.toContain(password);
  });

  it('rejects an invalid password', async () => {
    const fixture = await insertAdminFixture(app, 'AdminPass#2026!!');
    identityIds.push(fixture.identityId);
    const login = await request(app.getHttpServer())
      .post('/v1/admin/auth/login')
      .send({ email: fixture.email, password: 'wrong-password' });
    expect(login.status).toBe(401);
    expect(login.body.error.code).toBe('INVALID_CREDENTIALS');
  });
});
