import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { createTestApp } from './helpers';

const ADMIN_ORIGIN = 'https://idhar-udhar-admin.netlify.app';

describe('CORS (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    app = await createTestApp();
  });

  afterAll(async () => {
    await app.close();
  });

  it('allows the deployed Admin origin and private-network preflight', async () => {
    const response = await request(app.getHttpServer())
      .options('/v1/admin/auth/login')
      .set('Origin', ADMIN_ORIGIN)
      .set('Access-Control-Request-Method', 'POST')
      .set('Access-Control-Request-Headers', 'content-type')
      .set('Access-Control-Request-Private-Network', 'true');
    expect(response.headers['access-control-allow-origin']).toBe(ADMIN_ORIGIN);
    expect(response.headers['access-control-allow-private-network']).toBe('true');
    expect(response.headers['access-control-allow-credentials']).toBe('true');
  });

  it('allows loopback Admin origins used by Vite', async () => {
    const response = await request(app.getHttpServer())
      .get('/health')
      .set('Origin', 'http://localhost:5173');
    expect(response.headers['access-control-allow-origin']).toBe('http://localhost:5173');
  });

  it('does not use a wildcard origin', async () => {
    const response = await request(app.getHttpServer())
      .get('/health')
      .set('Origin', 'https://evil.example');
    expect(response.headers['access-control-allow-origin']).toBeUndefined();
  });
});
