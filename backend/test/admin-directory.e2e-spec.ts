import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { PostgresService } from '../src/database/postgres.service';
import {
  assertNoSecrets,
  createTestApp,
  deleteIdentity,
  insertCustomerFixture,
  insertRiderFixture,
  issueAdminSession,
} from './helpers';

function bearer(token: string) {
  return { Authorization: `Bearer ${token}` };
}

describe('Admin directory and ledgers (e2e)', () => {
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

  it('lists riders and customers for an admin', async () => {
    const admin = await issueAdminSession(app);
    identityIds.push(admin.identityId);
    const rider = await insertRiderFixture(postgres);
    identityIds.push(rider.identityId);
    const customer = await insertCustomerFixture(postgres);
    identityIds.push(customer.identityId);

    const riders = await request(app.getHttpServer())
      .get('/v1/admin/riders')
      .set(bearer(admin.tokens.accessToken));
    expect(riders.status).toBe(200);
    expect(Array.isArray(riders.body.riders)).toBe(true);
    expect(
      riders.body.riders.some(
        (row: { rider_profile_id: string }) =>
          row.rider_profile_id === rider.profileId,
      ),
    ).toBe(true);
    assertNoSecrets(riders.body);

    const one = await request(app.getHttpServer())
      .get(`/v1/admin/riders/${rider.profileId}`)
      .set(bearer(admin.tokens.accessToken));
    expect(one.status).toBe(200);
    expect(one.body.rider_profile_id).toBe(rider.profileId);

    const customers = await request(app.getHttpServer())
      .get('/v1/admin/customers')
      .set(bearer(admin.tokens.accessToken));
    expect(customers.status).toBe(200);
    expect(
      customers.body.customers.some(
        (row: { customer_profile_id: string }) =>
          row.customer_profile_id === customer.profileId,
      ),
    ).toBe(true);
  });

  it('lists stored payments and earnings for finance admins only', async () => {
    const finance = await issueAdminSession(app, { financeAccess: true });
    identityIds.push(finance.identityId);
    const payments = await request(app.getHttpServer())
      .get('/v1/admin/payments')
      .set(bearer(finance.tokens.accessToken));
    expect(payments.status).toBe(200);
    expect(Array.isArray(payments.body.transactions)).toBe(true);
    assertNoSecrets(payments.body);

    const earnings = await request(app.getHttpServer())
      .get('/v1/admin/earnings')
      .set(bearer(finance.tokens.accessToken));
    expect(earnings.status).toBe(200);
    expect(Array.isArray(earnings.body.earnings)).toBe(true);

    const blocked = await issueAdminSession(app, {
      financeAccess: false,
      role: 'SUPPORT',
    });
    identityIds.push(blocked.identityId);
    const forbidden = await request(app.getHttpServer())
      .get('/v1/admin/payments')
      .set(bearer(blocked.tokens.accessToken));
    expect(forbidden.status).toBe(403);
    expect(forbidden.body.error.code).toBe('FORBIDDEN');
  });
});
