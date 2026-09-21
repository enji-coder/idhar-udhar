import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { PostgresService } from '../src/database/postgres.service';
import { CapturingOtpDeliveryProvider } from '../src/auth/otp/capturing-otp-delivery.provider';
import {
  assertNoSecrets,
  createTestApp,
  deleteByPhone,
  deleteIdentity,
  insertAdminFixture,
  issueAdminSession,
  uniquePhone,
} from './helpers';

describe('Profiles and authorization (e2e)', () => {
  let app: INestApplication;
  let postgres: PostgresService;
  let capture: CapturingOtpDeliveryProvider;
  const phones: string[] = [];
  const identityIds: string[] = [];

  beforeAll(async () => {
    app = await createTestApp();
    postgres = app.get(PostgresService);
    capture = app.get(CapturingOtpDeliveryProvider);
  });

  afterAll(async () => {
    for (const phone of phones) {
      await deleteByPhone(postgres, phone);
    }
    for (const identityId of identityIds) {
      await deleteIdentity(postgres, identityId);
    }
    await app.close();
  });

  async function loginMarketplace(actor: 'CUSTOMER' | 'RIDER') {
    const phone = uniquePhone();
    phones.push(phone);
    await request(app.getHttpServer())
      .post('/v1/auth/otp/request')
      .send({ phone, actor_type: actor });
    const verified = await request(app.getHttpServer())
      .post('/v1/auth/otp/verify')
      .send({ phone, actor_type: actor, code: capture.peek(phone) });
    return verified.body as {
      access_token: string;
      identity_id: string;
      profile_id: string;
    };
  }

  it('returns the authenticated customer profile only', async () => {
    const customer = await loginMarketplace('CUSTOMER');
    const mine = await request(app.getHttpServer())
      .get('/v1/customer/profile')
      .set('Authorization', `Bearer ${customer.access_token}`);
    expect(mine.status).toBe(200);
    expect(mine.body.identity_id).toBe(customer.identity_id);
    expect(mine.body.customer_profile_id).toBe(customer.profile_id);
    expect(mine.body.needs_profile_setup).toBe(true);
    assertNoSecrets(mine.body);

    const other = await request(app.getHttpServer())
      .get(`/v1/customer/profile/${customer.identity_id}`)
      .set('Authorization', `Bearer ${customer.access_token}`);
    expect(other.status).toBe(404);
  });

  it('returns the authenticated rider profile', async () => {
    const rider = await loginMarketplace('RIDER');
    const mine = await request(app.getHttpServer())
      .get('/v1/rider/profile')
      .set('Authorization', `Bearer ${rider.access_token}`);
    expect(mine.status).toBe(200);
    expect(mine.body.rider_profile_id).toBe(rider.profile_id);
    assertNoSecrets(mine.body);
  });

  it('forbids a customer from reading rider or admin profiles', async () => {
    const customer = await loginMarketplace('CUSTOMER');
    const rider = await request(app.getHttpServer())
      .get('/v1/rider/profile')
      .set('Authorization', `Bearer ${customer.access_token}`);
    expect(rider.status).toBe(403);
    expect(rider.body.error.code).toBe('FORBIDDEN');

    const admin = await request(app.getHttpServer())
      .get('/v1/admin/profile')
      .set('Authorization', `Bearer ${customer.access_token}`);
    expect(admin.status).toBe(403);
  });

  it('persists customer registration name and lists it for admin', async () => {
    const customer = await loginMarketplace('CUSTOMER');
    const updated = await request(app.getHttpServer())
      .put('/v1/customer/profile')
      .set('Authorization', `Bearer ${customer.access_token}`)
      .send({ display_name: 'Asha Patel' });
    expect(updated.status).toBe(200);
    expect(updated.body.display_name).toBe('Asha Patel');
    expect(updated.body.needs_profile_setup).toBe(false);
    assertNoSecrets(updated.body);

    const admin = await issueAdminSession(app);
    identityIds.push(admin.identityId);
    const listed = await request(app.getHttpServer())
      .get('/v1/admin/customers')
      .set('Authorization', `Bearer ${admin.tokens.accessToken}`);
    expect(listed.status).toBe(200);
    expect(
      listed.body.customers.some(
        (row: { customer_profile_id: string; display_name: string }) =>
          row.customer_profile_id === customer.profile_id &&
          row.display_name === 'Asha Patel',
      ),
    ).toBe(true);
  });

  it('returns admin profile without the password hash', async () => {
    const password = 'AdminPass#2026!!';
    const fixture = await insertAdminFixture(app, password);
    identityIds.push(fixture.identityId);
    const login = await request(app.getHttpServer())
      .post('/v1/admin/auth/login')
      .send({ email: fixture.email, password });
    const profile = await request(app.getHttpServer())
      .get('/v1/admin/profile')
      .set('Authorization', `Bearer ${login.body.access_token}`);
    expect(profile.status).toBe(200);
    expect(profile.body.role).toBe('SUPER_ADMIN');
    expect(profile.body.password_hash).toBeUndefined();
    assertNoSecrets(profile.body);
  });
});
