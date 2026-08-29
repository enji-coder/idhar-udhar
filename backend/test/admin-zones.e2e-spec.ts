import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { PostgresService } from '../src/database/postgres.service';
import {
  assertNoSecrets,
  createTestApp,
  deleteIdentity,
  issueAdminSession,
} from './helpers';

function bearer(token: string) {
  return { Authorization: `Bearer ${token}` };
}

describe('Admin zones (e2e)', () => {
  let app: INestApplication;
  let postgres: PostgresService;
  const identityIds: string[] = [];
  const zoneIds: string[] = [];

  beforeAll(async () => {
    app = await createTestApp();
    postgres = app.get(PostgresService);
  });

  afterAll(async () => {
    for (const id of zoneIds) {
      await postgres.query(`DELETE FROM zones WHERE zone_id = $1`, [id]);
    }
    for (const identityId of identityIds) {
      await deleteIdentity(postgres, identityId);
    }
    await app.close();
  });

  it('creates a zone under Ahmedabad when the launch city exists', async () => {
    const city = await postgres.query<{ city_id: string }>(
      `SELECT city_id FROM cities WHERE city_code = 'AMD' AND active = TRUE`,
    );
    if (!city.rows[0]) {
      return;
    }
    const admin = await issueAdminSession(app);
    identityIds.push(admin.identityId);

    const created = await request(app.getHttpServer())
      .post('/v1/admin/zones')
      .set(bearer(admin.tokens.accessToken))
      .send({ name: `E2E Zone ${Date.now()}` });
    expect(created.status).toBe(201);
    expect(created.body.city_code).toBe('AMD');
    assertNoSecrets(created.body);
    zoneIds.push(created.body.zone_id);

    const listed = await request(app.getHttpServer())
      .get('/v1/admin/zones')
      .set(bearer(admin.tokens.accessToken));
    expect(listed.status).toBe(200);
    expect(
      listed.body.zones.some(
        (row: { zone_id: string }) => row.zone_id === created.body.zone_id,
      ),
    ).toBe(true);

    const removed = await request(app.getHttpServer())
      .delete(`/v1/admin/zones/${created.body.zone_id}`)
      .set(bearer(admin.tokens.accessToken));
    expect(removed.status).toBe(200);
    zoneIds.pop();
  });
});
