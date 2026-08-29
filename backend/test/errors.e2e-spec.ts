import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { createTestApp } from './helpers';

describe('API error standard (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    app = await createTestApp();
  });

  afterAll(async () => {
    await app.close();
  });

  it('returns VALIDATION_ERROR for a malformed refresh body', async () => {
    const response = await request(app.getHttpServer())
      .post('/v1/auth/token/refresh')
      .send({});
    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
    expect(response.body.error.request_id).toBeDefined();
    expect(Array.isArray(response.body.error.details)).toBe(true);
  });

  it('returns NOT_FOUND without leaking internals', async () => {
    const response = await request(app.getHttpServer()).get(
      '/v1/this-route-does-not-exist',
    );
    expect(response.status).toBe(404);
    expect(response.body.error.code).toBe('NOT_FOUND');
    expect(JSON.stringify(response.body)).not.toMatch(/SELECT /i);
    expect(response.body.error).not.toHaveProperty('stack');
  });
});
