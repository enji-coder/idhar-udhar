import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { createTestApp } from './helpers';

describe('Health (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    app = await createTestApp();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /health/live returns process ok without auth', async () => {
    const response = await request(app.getHttpServer()).get('/health/live');
    expect(response.status).toBe(200);
    expect(response.body.status).toBe('ok');
    expect(response.body.checks.process).toBe('ok');
    expect(response.headers['x-request-id']).toBeDefined();
  });

  it('GET /health/db pings the existing PostgreSQL database', async () => {
    const response = await request(app.getHttpServer()).get('/health/db');
    expect(response.status).toBe(200);
    expect(response.body.status).toBe('ok');
    expect(response.body.checks.database).toBe('ok');
    expect(response.body.database.name).toBe('idhar_udhar');
  });

  it('GET /health is healthy when the database responds', async () => {
    const response = await request(app.getHttpServer()).get('/health');
    expect(response.status).toBe(200);
    expect(response.body.status).toBe('ok');
    expect(response.body.service).toBe('idhar-udhar-api');
  });

  it('GET /health/worker returns safe worker stats without auth', async () => {
    const response = await request(app.getHttpServer()).get('/health/worker');
    expect(response.status).toBe(200);
    expect(response.body.status).toBe('ok');
    expect(response.body.worker.pending_deliveries).toBeGreaterThanOrEqual(0);
    expect(JSON.stringify(response.body)).not.toMatch(/password/);
  });
});
