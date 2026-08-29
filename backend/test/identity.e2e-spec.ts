import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { PostgresService } from '../src/database/postgres.service';
import { CapturingOtpDeliveryProvider } from '../src/auth/otp/capturing-otp-delivery.provider';
import {
  createTestApp,
  deleteByPhone,
  uniquePhone,
} from './helpers';

describe('Identity resolution (e2e)', () => {
  let app: INestApplication;
  let postgres: PostgresService;
  let capture: CapturingOtpDeliveryProvider;
  const phones: string[] = [];

  beforeAll(async () => {
    app = await createTestApp();
    postgres = app.get(PostgresService);
    capture = app.get(CapturingOtpDeliveryProvider);
  });

  afterAll(async () => {
    for (const phone of phones) {
      await deleteByPhone(postgres, phone);
    }
    await app.close();
  });

  async function verify(phone: string, actor: 'CUSTOMER' | 'RIDER') {
    phones.push(phone);
    await request(app.getHttpServer())
      .post('/v1/auth/otp/request')
      .send({ phone, actor_type: actor });
    return request(app.getHttpServer())
      .post('/v1/auth/otp/verify')
      .send({ phone, actor_type: actor, code: capture.peek(phone) });
  }

  it('creates one identity and customer profile on first verify', async () => {
    const phone = uniquePhone();
    const verified = await verify(phone, 'CUSTOMER');
    expect(verified.status).toBe(200);
    const rows = await postgres.query<{ count: string }>(
      'SELECT count(*)::text AS count FROM identities WHERE phone_normalized = $1',
      [phone],
    );
    expect(rows.rows[0].count).toBe('1');
  });

  it('does not duplicate the identity on a second customer login', async () => {
    const phone = uniquePhone();
    const first = await verify(phone, 'CUSTOMER');
    const second = await verify(phone, 'CUSTOMER');
    expect(first.body.identity_id).toBe(second.body.identity_id);
    const rows = await postgres.query<{ count: string }>(
      'SELECT count(*)::text AS count FROM identities WHERE phone_normalized = $1',
      [phone],
    );
    expect(rows.rows[0].count).toBe('1');
  });

  it('attaches a rider profile to the same identity', async () => {
    const phone = uniquePhone();
    const customer = await verify(phone, 'CUSTOMER');
    const rider = await verify(phone, 'RIDER');
    expect(customer.status).toBe(200);
    expect(rider.status).toBe(200);
    expect(rider.body.identity_id).toBe(customer.body.identity_id);
    expect(rider.body.role).toBe('RIDER');
    expect(rider.body.profile_id).not.toBe(customer.body.profile_id);
  });
});
