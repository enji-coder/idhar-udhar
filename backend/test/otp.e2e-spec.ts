import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { AppLogger } from '../src/common/logger/app-logger';
import { PostgresService } from '../src/database/postgres.service';
import { CapturingOtpDeliveryProvider } from '../src/auth/otp/capturing-otp-delivery.provider';
import {
  assertNoSecrets,
  createTestApp,
  deleteByPhone,
  uniquePhone,
} from './helpers';

describe('OTP authentication (e2e)', () => {
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

  async function requestOtp(phone: string, actor: 'CUSTOMER' | 'RIDER' = 'CUSTOMER') {
    phones.push(phone);
    return request(app.getHttpServer())
      .post('/v1/auth/otp/request')
      .send({ phone, actor_type: actor });
  }

  it('stores only a hash and never returns the OTP', async () => {
    const phone = uniquePhone();
    const logs: string[] = [];
    const logger = app.get(AppLogger);
    const spy = jest.spyOn(logger, 'info').mockImplementation((msg, fields) => {
      logs.push(JSON.stringify({ msg, fields }));
    });

    const created = await requestOtp(phone);
    expect(created.status).toBe(200);
    expect(created.body.requested).toBe(true);
    const code = capture.peek(phone);
    expect(code).toMatch(/^\d{6}$/);
    expect(JSON.stringify(created.body)).not.toContain(code as string);
    assertNoSecrets(created.body);

    const stored = await postgres.query<{ code_hash: string }>(
      `
      SELECT code_hash
      FROM otp_challenges
      WHERE phone_normalized = $1
      ORDER BY created_at DESC
      LIMIT 1
      `,
      [phone],
    );
    expect(stored.rows[0].code_hash).toBeTruthy();
    expect(stored.rows[0].code_hash).not.toBe(code);
    expect(logs.join('\n')).not.toContain(code as string);
    spy.mockRestore();
  });

  it('verifies a valid OTP and creates a customer session', async () => {
    const phone = uniquePhone();
    await requestOtp(phone);
    const verified = await request(app.getHttpServer())
      .post('/v1/auth/otp/verify')
      .send({ phone, actor_type: 'CUSTOMER', code: capture.peek(phone) });
    expect(verified.status).toBe(200);
    expect(verified.body.role).toBe('CUSTOMER');
    expect(verified.body.access_token).toBeDefined();
    expect(verified.body.refresh_token).toBeDefined();
    assertNoSecrets(verified.body);

    const session = await request(app.getHttpServer())
      .get('/v1/auth/session')
      .set('Authorization', `Bearer ${verified.body.access_token}`);
    expect(session.status).toBe(200);
    expect(session.body.role).toBe('CUSTOMER');
  });

  it('rejects an incorrect OTP', async () => {
    const phone = uniquePhone();
    await requestOtp(phone);
    const response = await request(app.getHttpServer())
      .post('/v1/auth/otp/verify')
      .send({ phone, actor_type: 'CUSTOMER', code: '000000' });
    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('OTP_INVALID');
  });

  it('rejects an expired OTP', async () => {
    const phone = uniquePhone();
    await requestOtp(phone);
    await postgres.query(
      `
      UPDATE otp_challenges
      SET expires_at = now() - interval '1 minute'
      WHERE phone_normalized = $1
      `,
      [phone],
    );
    const response = await request(app.getHttpServer())
      .post('/v1/auth/otp/verify')
      .send({ phone, actor_type: 'CUSTOMER', code: capture.peek(phone) });
    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('OTP_EXPIRED');
  });

  it('rejects an already-used OTP (replay)', async () => {
    const phone = uniquePhone();
    await requestOtp(phone);
    const code = capture.peek(phone);
    const first = await request(app.getHttpServer())
      .post('/v1/auth/otp/verify')
      .send({ phone, actor_type: 'CUSTOMER', code });
    expect(first.status).toBe(200);
    const second = await request(app.getHttpServer())
      .post('/v1/auth/otp/verify')
      .send({ phone, actor_type: 'CUSTOMER', code });
    expect(second.status).toBe(401);
    expect(second.body.error.code).toBe('OTP_ALREADY_USED');
  });

  it('locks the challenge after too many attempts', async () => {
    const phone = uniquePhone();
    await requestOtp(phone);
    let last: { status: number; body: { error?: { code?: string } } } | null =
      null;
    for (let i = 0; i < 5; i += 1) {
      last = await request(app.getHttpServer())
        .post('/v1/auth/otp/verify')
        .send({ phone, actor_type: 'CUSTOMER', code: '000000' });
    }
    expect(last?.status).toBe(401);
    expect(last?.body.error?.code).toBe('OTP_ATTEMPTS_EXCEEDED');
  });

  it('enforces cooldown when cooldown_until is in the future', async () => {
    const phone = uniquePhone();
    await requestOtp(phone);
    await postgres.query(
      `
      UPDATE otp_challenges
      SET cooldown_until = now() + interval '1 hour'
      WHERE phone_normalized = $1
      `,
      [phone],
    );
    const again = await request(app.getHttpServer())
      .post('/v1/auth/otp/request')
      .send({ phone, actor_type: 'CUSTOMER' });
    expect(again.status).toBe(429);
    expect(again.body.error.code).toBe('OTP_COOLDOWN');
  });

  it('does not expose capture OTP over HTTP when DEV_OTP_PEEK is off', async () => {
    const phone = uniquePhone();
    await requestOtp(phone);
    expect(capture.peek(phone)).toBeDefined();
    const peek = await request(app.getHttpServer()).get(
      `/v1/auth/dev/otp-capture?phone=${phone}`,
    );
    expect(peek.status).toBe(404);
    expect(JSON.stringify(peek.body)).not.toContain(capture.peek(phone));
  });
});
