import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { PostgresService } from '../src/database/postgres.service';
import {
  assertNoSecrets,
  createTestApp,
  deleteIdentity,
  issueAdminSession,
  purgeIsolatedTestVehicleCatalog,
} from './helpers';

function bearer(token: string) {
  return { Authorization: `Bearer ${token}` };
}

describe('Admin vehicle categories (e2e)', () => {
  let app: INestApplication;
  let postgres: PostgresService;
  const identityIds: string[] = [];
  const categoryIds: string[] = [];

  beforeAll(async () => {
    app = await createTestApp();
    postgres = app.get(PostgresService);
  });

  afterAll(async () => {
    await purgeIsolatedTestVehicleCatalog(postgres);
    for (const id of categoryIds) {
      await postgres.query(
        `
        DELETE FROM vehicle_categories
        WHERE vehicle_category_id = $1
          AND NOT EXISTS (
            SELECT 1 FROM fare_config_version_rates r
            WHERE r.vehicle_category_id = $1
          )
          AND NOT EXISTS (
            SELECT 1 FROM orders o WHERE o.vehicle_category_id = $1
          )
        `,
        [id],
      );
    }
    for (const identityId of identityIds) {
      try {
        await deleteIdentity(postgres, identityId);
      } catch {
        /* fare_config_versions.created_by may still reference this admin */
      }
    }
    await app.close();
  });

  it('lists, creates, updates, and deletes a category without dummy fallback', async () => {
    const admin = await issueAdminSession(app);
    identityIds.push(admin.identityId);

    const empty = await request(app.getHttpServer())
      .get('/v1/admin/vehicle-categories')
      .set(bearer(admin.tokens.accessToken));
    expect(empty.status).toBe(200);
    expect(Array.isArray(empty.body.vehicle_categories)).toBe(true);
    assertNoSecrets(empty.body);

    const created = await request(app.getHttpServer())
      .post('/v1/admin/vehicle-categories')
      .set(bearer(admin.tokens.accessToken))
      .send({ name: `E2E Bike ${Date.now()}`, active: true });
    expect(created.status).toBe(201);
    expect(created.body.name).toMatch(/^E2E Bike /);
    expect(created.body.active).toBe(true);
    expect(created.body.vehicle_category_id).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
    );
    categoryIds.push(created.body.vehicle_category_id);

    const listed = await request(app.getHttpServer())
      .get('/v1/admin/vehicle-categories')
      .set(bearer(admin.tokens.accessToken));
    expect(
      listed.body.vehicle_categories.some(
        (row: { vehicle_category_id: string }) =>
          row.vehicle_category_id === created.body.vehicle_category_id,
      ),
    ).toBe(true);

    const updated = await request(app.getHttpServer())
      .patch(`/v1/admin/vehicle-categories/${created.body.vehicle_category_id}`)
      .set(bearer(admin.tokens.accessToken))
      .send({ name: `${created.body.name} XL`, weight_capacity: '25' });
    expect(updated.status).toBe(200);
    expect(updated.body.name).toBe(`${created.body.name} XL`);
    expect(updated.body.weight_capacity).toBe('25');

    const stored = await postgres.query<{ name: string }>(
      `SELECT name FROM vehicle_categories WHERE vehicle_category_id = $1`,
      [created.body.vehicle_category_id],
    );
    expect(stored.rows[0].name).toBe(`${created.body.name} XL`);

    const removed = await request(app.getHttpServer())
      .delete(`/v1/admin/vehicle-categories/${created.body.vehicle_category_id}`)
      .set(bearer(admin.tokens.accessToken));
    expect(removed.status).toBe(200);
    categoryIds.pop();

    const after = await postgres.query(
      `SELECT 1 FROM vehicle_categories WHERE vehicle_category_id = $1`,
      [created.body.vehicle_category_id],
    );
    expect(after.rows.length).toBe(0);
  });

  it('publishes fare version N+1 and refuses delete while rates exist', async () => {
    const admin = await issueAdminSession(app);
    identityIds.push(admin.identityId);

    const created = await request(app.getHttpServer())
      .post('/v1/admin/vehicle-categories')
      .set(bearer(admin.tokens.accessToken))
      .send({
        name: `E2E Fare ${Date.now()}`,
        rates: { base_fare: 79, per_km: 0, initial_minimum: 79 },
      });
    expect(created.status).toBe(201);
    expect(created.body.rates.base_fare).toBe('79.00');
    categoryIds.push(created.body.vehicle_category_id);

    const versions = await postgres.query<{ status: string }>(
      `
      SELECT v.status
      FROM fare_config_version_rates r
      JOIN fare_config_versions v
        ON v.fare_config_version_id = r.fare_config_version_id
      WHERE r.vehicle_category_id = $1
      `,
      [created.body.vehicle_category_id],
    );
    expect(versions.rows.some((row) => row.status === 'ACTIVE')).toBe(true);

    const blocked = await request(app.getHttpServer())
      .delete(`/v1/admin/vehicle-categories/${created.body.vehicle_category_id}`)
      .set(bearer(admin.tokens.accessToken));
    expect(blocked.status).toBe(409);
    expect(blocked.body.error.code).toBe('VEHICLE_CATEGORY_IN_USE');
    expect(blocked.body.error.message).toMatch(/published fare|protected/i);

    const deactivated = await request(app.getHttpServer())
      .patch(`/v1/admin/vehicle-categories/${created.body.vehicle_category_id}`)
      .set(bearer(admin.tokens.accessToken))
      .send({ active: false });
    expect(deactivated.status).toBe(200);
    expect(deactivated.body.active).toBe(false);
  });

  it('rejects unauthenticated access', async () => {
    const response = await request(app.getHttpServer()).get(
      '/v1/admin/vehicle-categories',
    );
    expect(response.status).toBe(401);
  });
});
