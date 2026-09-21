import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import {
  issueCustomerSession,
  issueRiderSession,
  createTestApp,
} from './helpers';

const token = `fcm-token-${'a'.repeat(40)}`;

describe('Device token registration (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    app = await createTestApp();
  });

  afterAll(async () => {
    await app.close();
  });

  it('rejects unauthenticated token registration', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/device-tokens')
      .send({ token, platform: 'ANDROID' });
    expect(res.status).toBe(401);
  });

  it('registers for the session owner and isolates unregister', async () => {
    const customer = await issueCustomerSession(app);
    const registered = await request(app.getHttpServer())
      .post('/v1/device-tokens')
      .set('Authorization', `Bearer ${customer.tokens.accessToken}`)
      .send({ token, platform: 'ANDROID' });
    expect(registered.status).toBe(200);
    expect(registered.body).toEqual({ registered: true });
    expect(JSON.stringify(registered.body)).not.toContain(token);

    const rider = await issueRiderSession(app);
    const stolen = await request(app.getHttpServer())
      .post('/v1/device-tokens/unregister')
      .set('Authorization', `Bearer ${rider.tokens.accessToken}`)
      .send({ token });
    expect(stolen.status).toBe(200);
    expect(stolen.body.unregistered).toBe(false);

    const own = await request(app.getHttpServer())
      .post('/v1/device-tokens/unregister')
      .set('Authorization', `Bearer ${customer.tokens.accessToken}`)
      .send({ token });
    expect(own.status).toBe(200);
    expect(own.body.unregistered).toBe(true);
  });
});
