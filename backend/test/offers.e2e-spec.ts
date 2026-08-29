import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { PostgresService } from '../src/database/postgres.service';
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

describe('Offers, dispatch and state machine (e2e)', () => {
  let app: INestApplication;
  let postgres: PostgresService;
  let catalog: OrderCatalog;
  let customer: Awaited<ReturnType<typeof issueCustomerSession>>;
  let admin: Awaited<ReturnType<typeof issueAdminSession>>;

  beforeAll(async () => {
    app = await createTestApp();
    postgres = app.get(PostgresService);
    catalog = await ensureOrderCatalog(postgres);
    customer = await issueCustomerSession(app);
    admin = await issueAdminSession(app);
  });

  afterAll(async () => {
    await app.close();
  });

  async function bookedSearchingOrder() {
    const created = await request(app.getHttpServer())
      .post('/v1/orders')
      .set('Authorization', `Bearer ${customer.tokens.accessToken}`)
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({
        city_id: catalog.cityId,
        vehicle_category_id: catalog.vehicleCategoryId,
        stops: sampleStops(catalog.zoneId),
      });
    const quote = await request(app.getHttpServer())
      .post(`/v1/orders/${created.body.order_id}/quote`)
      .set('Authorization', `Bearer ${customer.tokens.accessToken}`)
      .send({});
    const confirm = await request(app.getHttpServer())
      .post(`/v1/orders/${created.body.order_id}/confirm`)
      .set('Authorization', `Bearer ${customer.tokens.accessToken}`)
      .send({ fare_quote_id: quote.body.fare_quote_id });
    return confirm.body;
  }

  async function dispatch(orderId: string, riderProfileId: string) {
    return request(app.getHttpServer())
      .post(`/v1/admin/orders/${orderId}/offers`)
      .set('Authorization', `Bearer ${admin.tokens.accessToken}`)
      .send({ rider_profile_id: riderProfileId });
  }

  it('creates an offer the eligible rider can see and rejects other riders', async () => {
    const order = await bookedSearchingOrder();
    const rider = await issueRiderSession(app);
    const other = await issueRiderSession(app);
    const offered = await dispatch(order.order_id, rider.profileId);
    expect(offered.status).toBe(201);
    expect(offered.body.status).toBe('PENDING');
    expect(offered.body.order.canonical_status).toBe('OFFERED');

    const mine = await request(app.getHttpServer())
      .get('/v1/rider/offers')
      .set('Authorization', `Bearer ${rider.tokens.accessToken}`);
    expect(mine.status).toBe(200);
    expect(
      mine.body.offers.some(
        (row: { order_offer_id: string }) =>
          row.order_offer_id === offered.body.order_offer_id,
      ),
    ).toBe(true);

    const otherList = await request(app.getHttpServer())
      .get('/v1/rider/offers')
      .set('Authorization', `Bearer ${other.tokens.accessToken}`);
    expect(
      otherList.body.offers.some(
        (row: { order_offer_id: string }) =>
          row.order_offer_id === offered.body.order_offer_id,
      ),
    ).toBe(false);

    const stolen = await request(app.getHttpServer())
      .post(`/v1/rider/offers/${offered.body.order_offer_id}/accept`)
      .set('Authorization', `Bearer ${other.tokens.accessToken}`);
    expect(stolen.status).toBe(403);
  });

  it('rejects accepting a rejected or expired offer', async () => {
    const order = await bookedSearchingOrder();
    const rider = await issueRiderSession(app);
    const offered = await dispatch(order.order_id, rider.profileId);

    const rejected = await request(app.getHttpServer())
      .post(`/v1/rider/offers/${offered.body.order_offer_id}/reject`)
      .set('Authorization', `Bearer ${rider.tokens.accessToken}`);
    expect(rejected.status).toBe(200);
    expect(rejected.body.status).toBe('REJECTED');
    expect(rejected.body.order.canonical_status).toBe('SEARCHING');

    const acceptRejected = await request(app.getHttpServer())
      .post(`/v1/rider/offers/${offered.body.order_offer_id}/accept`)
      .set('Authorization', `Bearer ${rider.tokens.accessToken}`);
    expect(acceptRejected.status).toBe(409);
    expect(acceptRejected.body.error.code).toBe('OFFER_REJECTED');

    const rider2 = await issueRiderSession(app);
    const secondOffer = await dispatch(order.order_id, rider2.profileId);
    expect(secondOffer.status).toBe(201);
    await postgres.query(
      `UPDATE order_offers SET created_at = now() - interval '1 hour' WHERE order_offer_id = $1`,
      [secondOffer.body.order_offer_id],
    );
    const acceptExpired = await request(app.getHttpServer())
      .post(`/v1/rider/offers/${secondOffer.body.order_offer_id}/accept`)
      .set('Authorization', `Bearer ${rider2.tokens.accessToken}`);
    expect(acceptExpired.status).toBe(409);
    expect(acceptExpired.body.error.code).toBe('OFFER_EXPIRED');
  });

  it('allows only one rider to win a simultaneous accept', async () => {
    const order = await bookedSearchingOrder();
    const riderA = await issueRiderSession(app);
    const riderB = await issueRiderSession(app);
    const offerA = await dispatch(order.order_id, riderA.profileId);
    const offerB = await dispatch(order.order_id, riderB.profileId);
    expect(offerA.status).toBe(201);
    expect(offerB.status).toBe(201);

    const [first, second] = await Promise.all([
      request(app.getHttpServer())
        .post(`/v1/rider/offers/${offerA.body.order_offer_id}/accept`)
        .set('Authorization', `Bearer ${riderA.tokens.accessToken}`),
      request(app.getHttpServer())
        .post(`/v1/rider/offers/${offerB.body.order_offer_id}/accept`)
        .set('Authorization', `Bearer ${riderB.tokens.accessToken}`),
    ]);
    const statuses = [first.status, second.status].sort();
    expect(statuses).toEqual([200, 409]);
    const winner = first.status === 200 ? first : second;
    const loser = first.status === 200 ? second : first;
    expect(winner.body.order.canonical_status).toBe('ASSIGNED');
    expect(loser.body.error.code).toBe('ORDER_ALREADY_ACCEPTED');

    const accepted = await postgres.query<{ count: string; rider_profile_id: string }>(
      `
      SELECT count(*)::text AS count, max(rider_profile_id::text) AS rider_profile_id
      FROM order_offers
      WHERE order_id = $1 AND status = 'ACCEPTED'
      `,
      [order.order_id],
    );
    expect(accepted.rows[0].count).toBe('1');

    const assigned = await postgres.query<{ rider_profile_id: string; canonical_status: string }>(
      `SELECT rider_profile_id, canonical_status FROM orders WHERE order_id = $1`,
      [order.order_id],
    );
    expect(assigned.rows[0].canonical_status).toBe('ASSIGNED');
    expect(assigned.rows[0].rider_profile_id).toBe(winner.body.rider_profile_id);
  });

  it('retries accept for the winning rider as the same logical result', async () => {
    const order = await bookedSearchingOrder();
    const rider = await issueRiderSession(app);
    const offered = await dispatch(order.order_id, rider.profileId);
    const first = await request(app.getHttpServer())
      .post(`/v1/rider/offers/${offered.body.order_offer_id}/accept`)
      .set('Authorization', `Bearer ${rider.tokens.accessToken}`);
    const second = await request(app.getHttpServer())
      .post(`/v1/rider/offers/${offered.body.order_offer_id}/accept`)
      .set('Authorization', `Bearer ${rider.tokens.accessToken}`);
    expect(first.status).toBe(200);
    expect(second.status).toBe(200);
    expect(second.body.order.order_id).toBe(first.body.order.order_id);
    expect(second.body.order.canonical_status).toBe('ASSIGNED');
  });

  it('validates happy-path transitions and rejects illegal or unauthorized ones', async () => {
    const order = await bookedSearchingOrder();
    const rider = await issueRiderSession(app);
    const offered = await dispatch(order.order_id, rider.profileId);
    const accepted = await request(app.getHttpServer())
      .post(`/v1/rider/offers/${offered.body.order_offer_id}/accept`)
      .set('Authorization', `Bearer ${rider.tokens.accessToken}`);
    expect(accepted.status).toBe(200);

    const skip = await request(app.getHttpServer())
      .post(`/v1/rider/orders/${order.order_id}/status`)
      .set('Authorization', `Bearer ${rider.tokens.accessToken}`)
      .send({ to_status: 'DELIVERED' });
    expect(skip.status).toBe(409);
    expect(skip.body.error.code).toBe('INVALID_TRANSITION');

    const enRoute = await request(app.getHttpServer())
      .post(`/v1/rider/orders/${order.order_id}/status`)
      .set('Authorization', `Bearer ${rider.tokens.accessToken}`)
      .send({ to_status: 'EN_ROUTE_PICKUP' });
    expect(enRoute.status).toBe(200);
    expect(enRoute.body.canonical_status).toBe('EN_ROUTE_PICKUP');

    const customerJump = await request(app.getHttpServer())
      .post(`/v1/orders/${order.order_id}/status`)
      .set('Authorization', `Bearer ${customer.tokens.accessToken}`)
      .send({ to_status: 'ARRIVED_PICKUP' });
    expect(customerJump.status).toBe(403);

    const otherRider = await issueRiderSession(app);
    const stolen = await request(app.getHttpServer())
      .post(`/v1/rider/orders/${order.order_id}/status`)
      .set('Authorization', `Bearer ${otherRider.tokens.accessToken}`)
      .send({ to_status: 'ARRIVED_PICKUP' });
    expect(stolen.status).toBe(403);

    const arrived = await request(app.getHttpServer())
      .post(`/v1/rider/orders/${order.order_id}/status`)
      .set('Authorization', `Bearer ${rider.tokens.accessToken}`)
      .send({ to_status: 'ARRIVED_PICKUP' });
    expect(arrived.status).toBe(200);

    const events = await postgres.query<{ to_status: string }>(
      `
      SELECT to_status
      FROM order_status_events
      WHERE order_id = $1
      ORDER BY created_at
      `,
      [order.order_id],
    );
    expect(events.rows.map((row) => row.to_status)).toEqual([
      'CREATED',
      'SEARCHING',
      'OFFERED',
      'ASSIGNED',
      'EN_ROUTE_PICKUP',
      'ARRIVED_PICKUP',
    ]);
  });

  it('rejects rider access to an unoffered customer order', async () => {
    const order = await bookedSearchingOrder();
    const rider = await issueRiderSession(app);
    const peek = await request(app.getHttpServer())
      .get(`/v1/rider/orders/${order.order_id}`)
      .set('Authorization', `Bearer ${rider.tokens.accessToken}`);
    expect(peek.status).toBe(403);
  });

  it('lets an admin inspect any order and rejects a customer dispatch attempt', async () => {
    const order = await bookedSearchingOrder();
    const rider = await issueRiderSession(app);
    const customerDispatch = await request(app.getHttpServer())
      .post(`/v1/admin/orders/${order.order_id}/offers`)
      .set('Authorization', `Bearer ${customer.tokens.accessToken}`)
      .send({ rider_profile_id: rider.profileId });
    expect(customerDispatch.status).toBe(403);

    const inspect = await request(app.getHttpServer())
      .get(`/v1/admin/orders/${order.order_id}`)
      .set('Authorization', `Bearer ${admin.tokens.accessToken}`);
    expect(inspect.status).toBe(200);
    expect(inspect.body.fare_snapshot.tax).toBe('0.00');
  });
});
