import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { PostgresService } from '../src/database/postgres.service';
import {
  createTestApp,
  ensureOrderCatalog,
  issueAdminSession,
  issueCustomerSession,
  OrderCatalog,
  sampleStops,
  uniqueIdempotencyKey,
} from './helpers';

describe('Orders (e2e)', () => {
  let app: INestApplication;
  let postgres: PostgresService;
  let catalog: OrderCatalog;
  let customer: Awaited<ReturnType<typeof issueCustomerSession>>;
  let otherCustomer: Awaited<ReturnType<typeof issueCustomerSession>>;
  let admin: Awaited<ReturnType<typeof issueAdminSession>>;

  beforeAll(async () => {
    app = await createTestApp();
    postgres = app.get(PostgresService);
    catalog = await ensureOrderCatalog(postgres);
    customer = await issueCustomerSession(app);
    otherCustomer = await issueCustomerSession(app);
    admin = await issueAdminSession(app);
  });

  afterAll(async () => {
    await app.close();
  });

  function bearer(token: string) {
    return { Authorization: `Bearer ${token}` };
  }

  async function createOrder(options?: {
    token?: string;
    cityId?: string;
    vehicleCategoryId?: string;
    stops?: ReturnType<typeof sampleStops>;
    idempotencyKey?: string;
    extra?: Record<string, unknown>;
  }) {
    const key = options?.idempotencyKey ?? uniqueIdempotencyKey();
    const body = {
      city_id: options?.cityId ?? catalog.cityId,
      vehicle_category_id: options?.vehicleCategoryId ?? catalog.vehicleCategoryId,
      stops: options?.stops ?? sampleStops(catalog.zoneId),
      ...options?.extra,
    };
    return {
      key,
      response: await request(app.getHttpServer())
        .post('/v1/orders')
        .set('Authorization', `Bearer ${options?.token ?? customer.tokens.accessToken}`)
        .set('Idempotency-Key', key)
        .send(body),
    };
  }

  it('rejects unauthenticated order creation', async () => {
    const response = await request(app.getHttpServer())
      .post('/v1/orders')
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({
        city_id: catalog.cityId,
        vehicle_category_id: catalog.vehicleCategoryId,
        stops: sampleStops(catalog.zoneId),
      });
    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('UNAUTHENTICATED');
  });

  it('creates an order for the authenticated customer with UUID and display id', async () => {
    const { response } = await createOrder();
    expect(response.status).toBe(201);
    expect(response.body.customer_profile_id).toBe(customer.profileId);
    expect(response.body.canonical_status).toBe('CREATED');
    expect(response.body.order_id).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
    );
    expect(response.body.display_id).toMatch(/^IU-AMD-[0-9]{10}$/);
    expect(response.body.stops).toHaveLength(2);
    expect(response.body.stops[0].stop_type).toBe('PICKUP');
    expect(response.body.city_code).toBe('AMD');

    const stored = await postgres.query<{ display_id: string; customer_profile_id: string }>(
      `SELECT display_id, customer_profile_id FROM orders WHERE order_id = $1`,
      [response.body.order_id],
    );
    expect(stored.rows[0].display_id).toBe(response.body.display_id);
    expect(stored.rows[0].customer_profile_id).toBe(customer.profileId);
  });

  it('ignores a client-supplied customer id and uses the session', async () => {
    const { response } = await createOrder({
      extra: { customer_id: otherCustomer.profileId },
    });
    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('rejects an invalid vehicle category', async () => {
    const { response } = await createOrder({
      vehicleCategoryId: '00000000-0000-4000-8000-000000000001',
    });
    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VEHICLE_CATEGORY_INVALID');
  });

  it('rejects an invalid city', async () => {
    const { response } = await createOrder({
      cityId: '00000000-0000-4000-8000-000000000002',
    });
    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('CITY_INVALID');
  });

  it('rejects a zone that belongs to a different city', async () => {
    const { response } = await createOrder({
      stops: sampleStops(catalog.secondZoneId),
    });
    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('ZONE_INVALID');
  });

  it('rejects more than three drops', async () => {
    const { response } = await createOrder({
      stops: sampleStops(catalog.zoneId, 3),
    });
    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('rejects a missing pickup', async () => {
    const { response } = await createOrder({
      stops: [
        {
          sequence: 0,
          stop_type: 'DROP',
          address_text: 'Only drop A',
          latitude: 23.02,
          longitude: 72.57,
        },
        {
          sequence: 1,
          stop_type: 'DROP',
          address_text: 'Only drop B',
          latitude: 23.03,
          longitude: 72.58,
        },
      ],
    });
    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('INVALID_STOPS');
  });

  it('allocates unique city-specific display ids', async () => {
    const first = await createOrder();
    const second = await createOrder();
    expect(first.response.status).toBe(201);
    expect(second.response.status).toBe(201);
    expect(first.response.body.display_id).not.toBe(second.response.body.display_id);

    const otherCity = await createOrder({ cityId: catalog.secondCityId, stops: sampleStops(catalog.secondZoneId) });
    expect(otherCity.response.status).toBe(201);
    expect(otherCity.response.body.display_id).toMatch(/^IU-TST-[0-9]{10}$/);
    expect(otherCity.response.body.display_id).not.toBe(first.response.body.display_id);

    const amdSeq = first.response.body.display_id.slice(-10);
    const tstSeq = otherCity.response.body.display_id.slice(-10);
    expect(amdSeq).not.toBe(undefined);
    expect(tstSeq).toMatch(/^[0-9]{10}$/);
  });

  it('returns the same order for a duplicate idempotency key', async () => {
    const key = uniqueIdempotencyKey();
    const first = await createOrder({ idempotencyKey: key });
    const second = await createOrder({ idempotencyKey: key });
    expect(first.response.status).toBe(201);
    expect(second.response.status).toBe(201);
    expect(second.response.body.order_id).toBe(first.response.body.order_id);

    const count = await postgres.query<{ count: string }>(
      `
      SELECT count(*)::text AS count
      FROM orders
      WHERE customer_profile_id = $1 AND display_id = $2
      `,
      [customer.profileId, first.response.body.display_id],
    );
    expect(count.rows[0].count).toBe('1');
  });

  it('rejects a reused idempotency key with a different body', async () => {
    const key = uniqueIdempotencyKey();
    const first = await createOrder({ idempotencyKey: key });
    expect(first.response.status).toBe(201);
    const conflict = await createOrder({
      idempotencyKey: key,
      cityId: catalog.secondCityId,
      stops: sampleStops(catalog.secondZoneId),
    });
    expect(conflict.response.status).toBe(409);
    expect(conflict.response.body.error.code).toBe('IDEMPOTENCY_CONFLICT');
  });

  it('lists only the authenticated customer orders and hides others', async () => {
    const mine = await createOrder();
    const theirs = await createOrder({ token: otherCustomer.tokens.accessToken });
    expect(mine.response.status).toBe(201);
    expect(theirs.response.status).toBe(201);

    const list = await request(app.getHttpServer())
      .get('/v1/orders')
      .set(bearer(customer.tokens.accessToken));
    expect(list.status).toBe(200);
    const ids = list.body.orders.map((row: { order_id: string }) => row.order_id);
    expect(ids).toContain(mine.response.body.order_id);
    expect(ids).not.toContain(theirs.response.body.order_id);

    const hidden = await request(app.getHttpServer())
      .get(`/v1/orders/${theirs.response.body.order_id}`)
      .set(bearer(customer.tokens.accessToken));
    expect(hidden.status).toBe(404);

    const adminView = await request(app.getHttpServer())
      .get(`/v1/admin/orders/${theirs.response.body.order_id}`)
      .set(bearer(admin.tokens.accessToken));
    expect(adminView.status).toBe(200);
    expect(adminView.body.order_id).toBe(theirs.response.body.order_id);
  });

  it('returns stops on GET /v1/orders/:id/stops', async () => {
    const { response } = await createOrder({ stops: sampleStops(catalog.zoneId, 1) });
    expect(response.status).toBe(201);
    const stops = await request(app.getHttpServer())
      .get(`/v1/orders/${response.body.order_id}/stops`)
      .set(bearer(customer.tokens.accessToken));
    expect(stops.status).toBe(200);
    expect(stops.body.stops).toHaveLength(3);
    expect(stops.body.stops[0].sequence).toBe(0);
    expect(stops.body.stops.filter((s: { stop_type: string }) => s.stop_type === 'DROP')).toHaveLength(2);
  });
});
