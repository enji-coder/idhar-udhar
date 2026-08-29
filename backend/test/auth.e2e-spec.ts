import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { PostgresService } from '../src/database/postgres.service';
import { createTestApp, deleteIdentity, issueCustomerSession } from './helpers';

describe('Auth foundation (e2e)', () => {
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

  it('rejects protected /v1/auth/session without a bearer token', async () => {
    const response = await request(app.getHttpServer()).get('/v1/auth/session');
    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('UNAUTHENTICATED');
    expect(response.body.error.request_id).toBeDefined();
    expect(response.body.error).not.toHaveProperty('stack');
  });

  it('issues, refreshes, and revokes a session against public.sessions', async () => {
    const issued = await issueCustomerSession(app);
    identityIds.push(issued.identityId);

    const session = await request(app.getHttpServer())
      .get('/v1/auth/session')
      .set('Authorization', `Bearer ${issued.tokens.accessToken}`);
    expect(session.status).toBe(200);
    expect(session.body.role).toBe('CUSTOMER');
    expect(session.body.identity_id).toBe(issued.identityId);
    expect(session.body.profile_id).toBe(issued.profileId);

    const stored = await postgres.query<{ refresh_token_hash: string }>(
      'SELECT refresh_token_hash FROM sessions WHERE session_id = $1',
      [issued.tokens.sessionId],
    );
    expect(stored.rows[0].refresh_token_hash).toBeTruthy();
    expect(stored.rows[0].refresh_token_hash).not.toBe(
      issued.tokens.refreshToken,
    );

    const refreshed = await request(app.getHttpServer())
      .post('/v1/auth/token/refresh')
      .send({ refresh_token: issued.tokens.refreshToken });
    expect(refreshed.status).toBe(200);
    expect(refreshed.body.access_token).toBeDefined();
    expect(refreshed.body.refresh_token).not.toBe(issued.tokens.refreshToken);

    const reuse = await request(app.getHttpServer())
      .post('/v1/auth/token/refresh')
      .send({ refresh_token: issued.tokens.refreshToken });
    expect(reuse.status).toBe(401);
    expect(reuse.body.error.code).toBe('INVALID_REFRESH_TOKEN');

    const forbidden = await request(app.getHttpServer())
      .get('/v1/auth/admin-ping')
      .set('Authorization', `Bearer ${refreshed.body.access_token}`);
    expect(forbidden.status).toBe(403);
    expect(forbidden.body.error.code).toBe('FORBIDDEN');

    const logout = await request(app.getHttpServer())
      .post('/v1/auth/logout')
      .set('Authorization', `Bearer ${refreshed.body.access_token}`);
    expect(logout.status).toBe(200);
    expect(logout.body.revoked).toBe(true);

    const afterLogout = await request(app.getHttpServer())
      .get('/v1/auth/session')
      .set('Authorization', `Bearer ${refreshed.body.access_token}`);
    expect(afterLogout.status).toBe(401);
    expect(afterLogout.body.error.code).toBe('SESSION_REVOKED');
  });
});
