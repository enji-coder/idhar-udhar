import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { formatInr } from '../src/fare/money';
import { PostgresService } from '../src/database/postgres.service';
import {
  createTestApp,
  ensureOrderCatalog,
  issueCustomerSession,
  OrderCatalog,
  sampleStops,
  uniqueIdempotencyKey,
} from './helpers';

describe('Fare quotes and snapshots (e2e)', () => {
  let app: INestApplication;
  let postgres: PostgresService;
  let catalog: OrderCatalog;
  let customer: Awaited<ReturnType<typeof issueCustomerSession>>;

  beforeAll(async () => {
    app = await createTestApp();
    postgres = app.get(PostgresService);
    catalog = await ensureOrderCatalog(postgres);
    customer = await issueCustomerSession(app);
  });

  afterAll(async () => {
    await app.close();
  });

  async function createOrder() {
    return request(app.getHttpServer())
      .post('/v1/orders')
      .set('Authorization', `Bearer ${customer.tokens.accessToken}`)
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({
        city_id: catalog.cityId,
        vehicle_category_id: catalog.vehicleCategoryId,
        stops: sampleStops(catalog.zoneId),
      });
  }

  it('creates a server-side quote from the active configuration with GST 0', async () => {
    const order = await createOrder();
    expect(order.status).toBe(201);

    const quote = await request(app.getHttpServer())
      .post(`/v1/orders/${order.body.order_id}/quote`)
      .set('Authorization', `Bearer ${customer.tokens.accessToken}`)
      .send({});
    expect(quote.status).toBe(201);
    expect(typeof quote.body.trip_fare).toBe('string');
    expect(typeof quote.body.base_fare).toBe('string');
    expect(quote.body.tax).toBe('0.00');
    expect(quote.body.fare_config_version_id).toBe(catalog.fareConfigVersionId);
    expect(quote.body.vehicle_category_id).toBe(catalog.vehicleCategoryId);
    expect(quote.body.routing.provider).toBe('mock');
    expect(quote.body.stop_count).toBe(2);

    const expected = await postgres.query<{
      distance_charge: string;
      trip_fare: string;
    }>(
      `
      SELECT
        ROUND(per_km * $3::numeric(10,3), 2)::text AS distance_charge,
        GREATEST(
          initial_minimum,
          ROUND(base_fare + ROUND(per_km * $3::numeric(10,3), 2) + waiting + surge + toll + parking, 2)
        )::text AS trip_fare
      FROM fare_config_version_rates
      WHERE fare_config_version_id = $1
        AND vehicle_category_id = $2
      `,
      [
        catalog.fareConfigVersionId,
        catalog.vehicleCategoryId,
        quote.body.distance_km,
      ],
    );
    expect(quote.body.distance_charge).toBe(formatInr(expected.rows[0].distance_charge));
    expect(quote.body.trip_fare).toBe(formatInr(expected.rows[0].trip_fare));
    expect(quote.body.net_payable).toBe(quote.body.trip_fare);
    expect(JSON.stringify(quote.body)).not.toMatch(/NaN|Infinity/);
  });

  it('freezes the configuration version on confirm and preserves Trip Fare', async () => {
    const order = await createOrder();
    const quote = await request(app.getHttpServer())
      .post(`/v1/orders/${order.body.order_id}/quote`)
      .set('Authorization', `Bearer ${customer.tokens.accessToken}`)
      .send({});
    expect(quote.status).toBe(201);

    const confirm = await request(app.getHttpServer())
      .post(`/v1/orders/${order.body.order_id}/confirm`)
      .set('Authorization', `Bearer ${customer.tokens.accessToken}`)
      .send({ fare_quote_id: quote.body.fare_quote_id });
    expect(confirm.status).toBe(200);
    expect(confirm.body.canonical_status).toBe('SEARCHING');
    expect(confirm.body.fare_snapshot.tax).toBe('0.00');
    expect(confirm.body.fare_snapshot.trip_fare).toBe(quote.body.trip_fare);
    expect(confirm.body.fare_snapshot.fare_config_version_id).toBe(
      catalog.fareConfigVersionId,
    );
    expect(confirm.body.fare_snapshot.net_payable).toBe(quote.body.net_payable);
    expect(typeof confirm.body.fare_snapshot.trip_fare).toBe('string');

    const stored = await postgres.query<{
      trip_fare: string;
      tax: string;
      fare_config_version_id: string;
    }>(
      `
      SELECT trip_fare::text AS trip_fare, tax::text AS tax, fare_config_version_id
      FROM order_fare_snapshots
      WHERE order_id = $1
      `,
      [order.body.order_id],
    );
    expect(stored.rows).toHaveLength(1);
    expect(stored.rows[0].fare_config_version_id).toBe(catalog.fareConfigVersionId);
    expect(stored.rows[0].tax === '0' || stored.rows[0].tax === '0.00').toBe(true);

    const event = await postgres.query<{ to_status: string }>(
      `
      SELECT to_status
      FROM order_status_events
      WHERE order_id = $1
      ORDER BY created_at
      `,
      [order.body.order_id],
    );
    expect(event.rows.map((row) => row.to_status)).toEqual(['CREATED', 'SEARCHING']);
  });

  it('rejects quoting after confirmation', async () => {
    const order = await createOrder();
    const quote = await request(app.getHttpServer())
      .post(`/v1/orders/${order.body.order_id}/quote`)
      .set('Authorization', `Bearer ${customer.tokens.accessToken}`)
      .send({});
    await request(app.getHttpServer())
      .post(`/v1/orders/${order.body.order_id}/confirm`)
      .set('Authorization', `Bearer ${customer.tokens.accessToken}`)
      .send({ fare_quote_id: quote.body.fare_quote_id });

    const again = await request(app.getHttpServer())
      .post(`/v1/orders/${order.body.order_id}/quote`)
      .set('Authorization', `Bearer ${customer.tokens.accessToken}`)
      .send({});
    expect(again.status).toBe(409);
    expect(again.body.error.code).toBe('ORDER_NOT_MODIFIABLE');
  });
});
