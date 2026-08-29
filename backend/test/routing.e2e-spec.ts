import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { formatInr } from '../src/fare/money';
import { PostgresService } from '../src/database/postgres.service';
import { MemoryLocationStore } from '../src/location/memory-location.store';
import { metersToKm } from '../src/routing/coordinates';
import { MockRoutingProvider, mockRoadMeters } from '../src/routing/mock-routing.provider';
import {
  createTestApp,
  ensureOrderCatalog,
  issueAdminSession,
  issueCustomerSession,
  issueRiderSession,
  OrderCatalog,
  sampleStops,
  uniqueIdempotencyKey,
} from './helpers';

describe('Routing and rider location (e2e)', () => {
  let app: INestApplication;
  let postgres: PostgresService;
  let catalog: OrderCatalog;
  let customer: Awaited<ReturnType<typeof issueCustomerSession>>;
  let rider: Awaited<ReturnType<typeof issueRiderSession>>;
  let admin: Awaited<ReturnType<typeof issueAdminSession>>;
  let mockRouting: MockRoutingProvider;

  beforeAll(async () => {
    app = await createTestApp();
    postgres = app.get(PostgresService);
    catalog = await ensureOrderCatalog(postgres);
    customer = await issueCustomerSession(app);
    rider = await issueRiderSession(app);
    admin = await issueAdminSession(app);
    mockRouting = app.get(MockRoutingProvider);
  });

  afterAll(async () => {
    await app.close();
  });

  afterEach(() => {
    mockRouting.reset();
  });

  function bearer(token: string) {
    return { Authorization: `Bearer ${token}` };
  }

  async function createOrder(stops = sampleStops(catalog.zoneId)) {
    return request(app.getHttpServer())
      .post('/v1/orders')
      .set(bearer(customer.tokens.accessToken))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({
        city_id: catalog.cityId,
        vehicle_category_id: catalog.vehicleCategoryId,
        stops,
      });
  }

  it('rejects invalid stop latitude on create', async () => {
    const stops = sampleStops(catalog.zoneId);
    stops[0].latitude = 91;
    const created = await createOrder(stops);
    expect(created.status).toBe(400);
    expect(created.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('quotes fare from routed mock distance, not a client distance', async () => {
    const created = await createOrder();
    expect(created.status).toBe(201);
    const stops = created.body.stops as { latitude: string; longitude: string }[];
    const expectedMeters = mockRoadMeters(
      stops.map((stop) => ({
        latitude: Number(stop.latitude),
        longitude: Number(stop.longitude),
      })),
    );
    const expectedKm = metersToKm(expectedMeters);

    const quote = await request(app.getHttpServer())
      .post(`/v1/orders/${created.body.order_id}/quote`)
      .set(bearer(customer.tokens.accessToken))
      .send({});
    expect(quote.status).toBe(201);
    expect(quote.body.routing.provider).toBe('mock');
    expect(quote.body.routing.distance_meters).toBe(expectedMeters);
    expect(quote.body.distance_km).toBe(expectedKm);
    expect(quote.body.tax).toBe('0.00');
    expect(typeof quote.body.estimated_duration_seconds).toBe('undefined');
    expect(quote.body.routing.estimated_duration_seconds).toBeGreaterThan(0);
    expect(quote.body).not.toHaveProperty('google_key');

    const expected = await postgres.query<{
      distance_charge: string;
      trip_fare: string;
    }>(
      `
      SELECT
        ROUND(per_km * $3::numeric(10,3), 2)::text AS distance_charge,
        GREATEST(
          initial_minimum,
          ROUND(
            base_fare + ROUND(per_km * $3::numeric(10,3), 2) + waiting + surge + toll + parking,
            2
          )
        )::text AS trip_fare
      FROM fare_config_version_rates
      WHERE fare_config_version_id = $1
        AND vehicle_category_id = $2
      `,
      [catalog.fareConfigVersionId, catalog.vehicleCategoryId, expectedKm],
    );
    expect(quote.body.distance_charge).toBe(formatInr(expected.rows[0].distance_charge));
    expect(quote.body.trip_fare).toBe(formatInr(expected.rows[0].trip_fare));
  });

  it('rejects client-supplied distance_km so it cannot force the fare', async () => {
    const created = await createOrder();
    const response = await request(app.getHttpServer())
      .post(`/v1/orders/${created.body.order_id}/quote`)
      .set(bearer(customer.tokens.accessToken))
      .send({ distance_km: '1' });
    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('preserves pickup + 3 drop order and does not optimize', async () => {
    const stops = sampleStops(catalog.zoneId, 2);
    const created = await createOrder(stops);
    expect(created.status).toBe(201);
    expect(created.body.stops.map((s: { stop_type: string }) => s.stop_type)).toEqual([
      'PICKUP',
      'DROP',
      'DROP',
      'DROP',
    ]);
    const quote = await request(app.getHttpServer())
      .post(`/v1/orders/${created.body.order_id}/quote`)
      .set(bearer(customer.tokens.accessToken))
      .send({});
    expect(quote.status).toBe(201);
    expect(quote.body.stop_count).toBe(4);
    expect(quote.body.routing.waypoint_count).toBe(2);
    expect(mockRouting.lastRequest?.points).toEqual(
      stops.map((stop) => ({
        latitude: stop.latitude,
        longitude: stop.longitude,
      })),
    );
  });

  it('returns ROUTING_PROVIDER_UNAVAILABLE when the provider fails', async () => {
    mockRouting.enqueue('unavailable');
    const created = await createOrder();
    const quote = await request(app.getHttpServer())
      .post(`/v1/orders/${created.body.order_id}/quote`)
      .set(bearer(customer.tokens.accessToken))
      .send({});
    expect(quote.status).toBe(503);
    expect(quote.body.error.code).toBe('ROUTING_PROVIDER_UNAVAILABLE');
  });

  it('exposes a live route to admin without storing geometry', async () => {
    const created = await createOrder();
    const route = await request(app.getHttpServer())
      .get(`/v1/admin/orders/${created.body.order_id}/route`)
      .set(bearer(admin.tokens.accessToken));
    expect(route.status).toBe(200);
    expect(route.body.routing.provider).toBe('mock');
    expect(route.body.routing.encoded_polyline).toBeNull();
  });

  it('accepts a rider location from the session and does not write GPS history tables', async () => {
    const recordedAt = new Date().toISOString();
    const response = await request(app.getHttpServer())
      .post('/v1/rider/location')
      .set(bearer(rider.tokens.accessToken))
      .send({
        latitude: 23.03,
        longitude: 72.55,
        accuracy_meters: 8,
        heading: 90,
        speed: 4.2,
        timestamp: recordedAt,
        rider_profile_id: '00000000-0000-4000-8000-000000000099',
      });
    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');

    const ok = await request(app.getHttpServer())
      .post('/v1/rider/location')
      .set(bearer(rider.tokens.accessToken))
      .send({
        latitude: 23.03,
        longitude: 72.55,
        accuracy_meters: 8,
        heading: 90,
        speed: 4.2,
        timestamp: recordedAt,
      });
    expect(ok.status).toBe(200);
    expect(ok.body.accepted).toBe(true);
    expect(ok.body.store).toBe('memory');
    expect(ok.body.durable).toBe(false);
    expect(ok.body.rider_profile_id).toBe(rider.profileId);

    const mine = await request(app.getHttpServer())
      .get('/v1/rider/location')
      .set(bearer(rider.tokens.accessToken));
    expect(mine.status).toBe(200);
    expect(mine.body.location.latitude).toBe(23.03);
    expect(mine.body.durable).toBe(false);

    const store = app.get(MemoryLocationStore);
    const stored = await store.get(rider.profileId);
    expect(stored?.identityId).toBe(rider.identityId);

    const ghostTables = await postgres.query<{ table_name: string }>(
      `
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
        AND table_name IN (
          'rider_location_samples',
          'gps_samples',
          'route_history',
          'order_routes'
        )
      `,
    );
    expect(ghostTables.rows).toHaveLength(0);
  });

  it('rejects invalid rider coordinates and customer callers', async () => {
    const timestamp = new Date().toISOString();
    const badLat = await request(app.getHttpServer())
      .post('/v1/rider/location')
      .set(bearer(rider.tokens.accessToken))
      .send({ latitude: 91, longitude: 72.55, timestamp });
    expect(badLat.status).toBe(400);

    const customerCall = await request(app.getHttpServer())
      .post('/v1/rider/location')
      .set(bearer(customer.tokens.accessToken))
      .send({ latitude: 23.03, longitude: 72.55, timestamp });
    expect(customerCall.status).toBe(403);
  });
});
