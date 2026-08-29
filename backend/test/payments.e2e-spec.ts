import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { formatInr } from '../src/fare/money';
import { PostgresService } from '../src/database/postgres.service';
import { FinanceService } from '../src/payments/finance.service';
import {
  createTestApp,
  ensureActivePaymentSettings,
  ensureOrderCatalog,
  issueAdminSession,
  issueCustomerSession,
  issueRiderSession,
  OrderCatalog,
  sampleStops,
  uniqueIdempotencyKey,
} from './helpers';

describe('Payments and finance (e2e)', () => {
  let app: INestApplication;
  let postgres: PostgresService;
  let finance: FinanceService;
  let catalog: OrderCatalog;
  let customer: Awaited<ReturnType<typeof issueCustomerSession>>;
  let otherCustomer: Awaited<ReturnType<typeof issueCustomerSession>>;
  let admin: Awaited<ReturnType<typeof issueAdminSession>>;
  let paymentSettings: Awaited<ReturnType<typeof ensureActivePaymentSettings>>;

  beforeAll(async () => {
    app = await createTestApp();
    postgres = app.get(PostgresService);
    finance = app.get(FinanceService);
    catalog = await ensureOrderCatalog(postgres);
    paymentSettings = await ensureActivePaymentSettings(postgres);
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

  async function createConfirmedOrder(token = customer.tokens.accessToken) {
    const created = await request(app.getHttpServer())
      .post('/v1/orders')
      .set(bearer(token))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({
        city_id: catalog.cityId,
        vehicle_category_id: catalog.vehicleCategoryId,
        stops: sampleStops(catalog.zoneId),
      });
    expect(created.status).toBe(201);
    const quote = await request(app.getHttpServer())
      .post(`/v1/orders/${created.body.order_id}/quote`)
      .set(bearer(token))
      .send({});
    expect(quote.status).toBe(201);
    const confirm = await request(app.getHttpServer())
      .post(`/v1/orders/${created.body.order_id}/confirm`)
      .set(bearer(token))
      .send({ fare_quote_id: quote.body.fare_quote_id });
    expect(confirm.status).toBe(200);
    return {
      orderId: created.body.order_id as string,
      tripFare: quote.body.trip_fare as string,
      netPayable: quote.body.net_payable as string,
      tax: quote.body.tax as string,
      token,
    };
  }

  async function splitBill(bill: string) {
    const result = await postgres.query<{ customer: string; receiver: string }>(
      `
      SELECT
        ROUND($1::numeric(12,2) / 2, 2)::text AS customer,
        ($1::numeric(12,2) - ROUND($1::numeric(12,2) / 2, 2))::text AS receiver
      `,
      [bill],
    );
    return {
      customer: formatInr(result.rows[0].customer),
      receiver: formatInr(result.rows[0].receiver),
    };
  }

  it('computes the locked 85/15/50 model on Trip Fare ₹100 in PostgreSQL', async () => {
    const alloc = await finance.allocatePreview('100.00');
    expect(alloc.tax).toBe('0.00');
    expect(alloc.payment_settings_version_id).toBe(
      paymentSettings.payment_settings_version_id,
    );
    if (
      formatInr(paymentSettings.rider_percentage) === '85.00' &&
      formatInr(paymentSettings.company_commission_percentage) === '15.00' &&
      formatInr(paymentSettings.operational_cost_percentage_of_commission) ===
        '50.00'
    ) {
      expect(alloc.rider_amount).toBe('85.00');
      expect(alloc.company_commission_amount).toBe('15.00');
      expect(alloc.operational_cost_amount).toBe('7.50');
      expect(alloc.profit_amount).toBe('7.50');
    }
  });

  it('applies existing remainder rounding on a non-even Trip Fare', async () => {
    const alloc = await finance.allocatePreview('101.00');
    const expected = await postgres.query<{
      rider_amount: string;
      company_commission_amount: string;
      operational_cost_amount: string;
      profit_amount: string;
    }>(
      `
      SELECT
        ROUND(101.00 * rider_percentage / 100, 2)::text AS rider_amount,
        ROUND(101.00 - ROUND(101.00 * rider_percentage / 100, 2), 2)::text AS company_commission_amount,
        ROUND(
          ROUND(101.00 - ROUND(101.00 * rider_percentage / 100, 2), 2)
          * operational_cost_percentage_of_commission / 100,
          2
        )::text AS operational_cost_amount,
        ROUND(
          ROUND(101.00 - ROUND(101.00 * rider_percentage / 100, 2), 2)
          - ROUND(
            ROUND(101.00 - ROUND(101.00 * rider_percentage / 100, 2), 2)
            * operational_cost_percentage_of_commission / 100,
            2
          ),
          2
        )::text AS profit_amount
      FROM payment_settings_versions
      WHERE status = 'ACTIVE'
      `,
    );
    expect(alloc.rider_amount).toBe(formatInr(expected.rows[0].rider_amount));
    expect(alloc.company_commission_amount).toBe(
      formatInr(expected.rows[0].company_commission_amount),
    );
    expect(alloc.operational_cost_amount).toBe(
      formatInr(expected.rows[0].operational_cost_amount),
    );
    expect(alloc.profit_amount).toBe(formatInr(expected.rows[0].profit_amount));
    expect(alloc.tax).toBe('0.00');
  });

  it('sets CUSTOMER responsibility from the bill, not Trip Fare', async () => {
    const order = await createConfirmedOrder();
    expect(order.tax).toBe('0.00');
    const response = await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/responsibility`)
      .set(bearer(order.token))
      .send({ who_pays: 'CUSTOMER' });
    expect(response.status).toBe(201);
    expect(response.body.who_pays).toBe('CUSTOMER');
    expect(response.body.applicable_bill_total).toBe(order.netPayable);
    expect(response.body.customer_responsibility).toBe(order.netPayable);
    expect(response.body.receiver_responsibility).toBe('0.00');
  });

  it('sets RECEIVER responsibility', async () => {
    const order = await createConfirmedOrder();
    const response = await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/responsibility`)
      .set(bearer(order.token))
      .send({ who_pays: 'RECEIVER' });
    expect(response.status).toBe(201);
    expect(response.body.who_pays).toBe('RECEIVER');
    expect(response.body.customer_responsibility).toBe('0.00');
    expect(response.body.receiver_responsibility).toBe(order.netPayable);
  });

  it('sets and validates SPLIT responsibility', async () => {
    const order = await createConfirmedOrder();
    const parts = await splitBill(order.netPayable);
    const valid = await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/responsibility`)
      .set(bearer(order.token))
      .send({
        who_pays: 'SPLIT',
        customer_responsibility: parts.customer,
        receiver_responsibility: parts.receiver,
      });
    expect(valid.status).toBe(201);
    expect(valid.body.who_pays).toBe('SPLIT');

    const invalid = await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/responsibility`)
      .set(bearer(order.token))
      .send({
        who_pays: 'SPLIT',
        customer_responsibility: parts.customer,
        receiver_responsibility: '0.01',
      });
    expect(invalid.status).toBe(409);
    expect(invalid.body.error.code).toBe('PAYMENT_RESPONSIBILITY_EXISTS');
  });

  it('rejects a SPLIT that does not sum to the bill', async () => {
    const order = await createConfirmedOrder();
    const response = await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/responsibility`)
      .set(bearer(order.token))
      .send({
        who_pays: 'SPLIT',
        customer_responsibility: '1.00',
        receiver_responsibility: '1.00',
      });
    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('PAYMENT_RESPONSIBILITY_INVALID');
  });

  it('rejects unauthorized users from payment writes and foreign reads', async () => {
    const order = await createConfirmedOrder();
    const other = await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/responsibility`)
      .set(bearer(otherCustomer.tokens.accessToken))
      .send({ who_pays: 'CUSTOMER' });
    expect(other.status).toBe(404);

    const unauth = await request(app.getHttpServer())
      .get(`/v1/orders/${order.orderId}/payment`);
    expect(unauth.status).toBe(401);

    const rider = await issueRiderSession(app);
    const riderRead = await request(app.getHttpServer())
      .get(`/v1/orders/${order.orderId}/payment`)
      .set(bearer(rider.tokens.accessToken));
    expect(riderRead.status).toBe(403);
  });

  it('creates a plan that matches responsibility and rejects an invalid plan', async () => {
    const order = await createConfirmedOrder();
    await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/responsibility`)
      .set(bearer(order.token))
      .send({ who_pays: 'CUSTOMER' });
    const valid = await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/plan`)
      .set(bearer(order.token))
      .send({
        customer_planned_online: '0.00',
        customer_planned_cash: order.netPayable,
        receiver_planned_online: '0.00',
        receiver_planned_cash: '0.00',
      });
    expect(valid.status).toBe(201);
    expect(valid.body.customer_planned_cash).toBe(order.netPayable);

    const otherOrder = await createConfirmedOrder();
    await request(app.getHttpServer())
      .post(`/v1/orders/${otherOrder.orderId}/payment/responsibility`)
      .set(bearer(otherOrder.token))
      .send({ who_pays: 'CUSTOMER' });
    const invalid = await request(app.getHttpServer())
      .post(`/v1/orders/${otherOrder.orderId}/payment/plan`)
      .set(bearer(otherOrder.token))
      .send({
        customer_planned_online: '1.00',
        customer_planned_cash: '1.00',
        receiver_planned_online: '0.00',
        receiver_planned_cash: '0.00',
      });
    expect(invalid.status).toBe(400);
    expect(invalid.body.error.code).toBe('PAYMENT_PLAN_INVALID');
  });

  it('records PENDING, PAID, FAILED, refund, and multiple transactions', async () => {
    const order = await createConfirmedOrder();
    const parts = await splitBill(order.netPayable);
    await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/responsibility`)
      .set(bearer(order.token))
      .send({
        who_pays: 'SPLIT',
        customer_responsibility: parts.customer,
        receiver_responsibility: parts.receiver,
      });
    await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/plan`)
      .set(bearer(order.token))
      .send({
        customer_planned_online: parts.customer,
        customer_planned_cash: '0.00',
        receiver_planned_online: '0.00',
        receiver_planned_cash: parts.receiver,
      });

    const pending = await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/transactions`)
      .set(bearer(order.token))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({
        payer_type: 'CUSTOMER',
        method: 'ONLINE',
        amount: parts.customer,
      });
    expect(pending.status).toBe(201);
    expect(pending.body.transaction_status).toBe('PENDING');
    expect(pending.body.direction).toBe('CHARGE');

    const unpaid = await request(app.getHttpServer())
      .get(`/v1/orders/${order.orderId}/payment`)
      .set(bearer(order.token));
    expect(unpaid.status).toBe(200);
    expect(unpaid.body.fare.tax).toBe('0.00');
    expect(unpaid.body.payment_status.overall.status).toBe('UNPAID');
    expect(unpaid.body.fare.trip_fare).toBe(order.tripFare);

    const failed = await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/transactions`)
      .set(bearer(admin.tokens.accessToken))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({
        payer_type: 'CUSTOMER',
        method: 'ONLINE',
        amount: parts.customer,
        transaction_status: 'FAILED',
      });
    expect(failed.status).toBe(201);
    expect(failed.body.transaction_status).toBe('FAILED');

    const customerCash = await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/transactions`)
      .set(bearer(admin.tokens.accessToken))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({
        payer_type: 'CUSTOMER',
        method: 'CASH',
        amount: parts.customer,
      });
    expect(customerCash.status).toBe(201);
    expect(customerCash.body.transaction_status).toBe('PAID');

    const partial = await request(app.getHttpServer())
      .get(`/v1/orders/${order.orderId}/payment`)
      .set(bearer(order.token));
    expect(partial.body.payment_status.customer.status).toBe('PAID');
    expect(partial.body.payment_status.receiver.status).toBe('UNPAID');
    expect(partial.body.payment_status.overall.status).toBe('PARTIALLY_PAID');

    const receiverCash = await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/transactions`)
      .set(bearer(admin.tokens.accessToken))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({
        payer_type: 'RECEIVER',
        method: 'CASH',
        amount: parts.receiver,
      });
    expect(receiverCash.status).toBe(201);
    expect(receiverCash.body.transaction_status).toBe('PAID');

    const paid = await request(app.getHttpServer())
      .get(`/v1/orders/${order.orderId}/payment`)
      .set(bearer(order.token));
    expect(paid.body.payment_status.overall.status).toBe('PAID');
    expect(paid.body.payment_status.overall.paid).toBe(order.netPayable);

    const refund = await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/transactions`)
      .set(bearer(admin.tokens.accessToken))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({
        payer_type: 'RECEIVER',
        method: 'CASH',
        amount: parts.receiver,
        direction: 'REFUND',
      });
    expect(refund.status).toBe(201);
    expect(refund.body.direction).toBe('REFUND');
    expect(refund.body.transaction_status).toBe('REFUNDED');

    const original = await postgres.query<{ transaction_status: string }>(
      `SELECT transaction_status FROM payment_transactions WHERE payment_transaction_id = $1`,
      [receiverCash.body.payment_transaction_id],
    );
    expect(original.rows[0].transaction_status).toBe('PAID');

    const afterRefund = await request(app.getHttpServer())
      .get(`/v1/orders/${order.orderId}/payment`)
      .set(bearer(order.token));
    expect(afterRefund.body.payment_status.receiver.status).toBe('UNPAID');
    expect(afterRefund.body.payment_status.overall.status).toBe('PARTIALLY_PAID');

    const listed = await request(app.getHttpServer())
      .get(`/v1/orders/${order.orderId}/payment/transactions`)
      .set(bearer(order.token));
    expect(listed.status).toBe(200);
    expect(listed.body.transactions.length).toBeGreaterThanOrEqual(4);
  });

  it('does not fake ONLINE as PAID', async () => {
    const order = await createConfirmedOrder();
    await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/responsibility`)
      .set(bearer(order.token))
      .send({ who_pays: 'CUSTOMER' });
    await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/plan`)
      .set(bearer(order.token))
      .send({
        customer_planned_online: order.netPayable,
        customer_planned_cash: '0.00',
        receiver_planned_online: '0.00',
        receiver_planned_cash: '0.00',
      });
    const online = await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/transactions`)
      .set(bearer(order.token))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({
        payer_type: 'CUSTOMER',
        method: 'ONLINE',
        amount: order.netPayable,
      });
    expect(online.body.transaction_status).toBe('PENDING');
    const payment = await request(app.getHttpServer())
      .get(`/v1/orders/${order.orderId}/payment`)
      .set(bearer(order.token));
    expect(payment.body.payment_status.overall.status).toBe('UNPAID');
  });

  it('replays the same payment key and conflicts on a different body', async () => {
    const order = await createConfirmedOrder();
    await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/responsibility`)
      .set(bearer(order.token))
      .send({ who_pays: 'CUSTOMER' });
    await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/plan`)
      .set(bearer(order.token))
      .send({
        customer_planned_online: '0.00',
        customer_planned_cash: order.netPayable,
        receiver_planned_online: '0.00',
        receiver_planned_cash: '0.00',
      });
    const key = uniqueIdempotencyKey();
    const first = await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/transactions`)
      .set(bearer(admin.tokens.accessToken))
      .set('Idempotency-Key', key)
      .send({
        payer_type: 'CUSTOMER',
        method: 'CASH',
        amount: order.netPayable,
      });
    expect(first.status).toBe(201);
    const replay = await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/transactions`)
      .set(bearer(admin.tokens.accessToken))
      .set('Idempotency-Key', key)
      .send({
        payer_type: 'CUSTOMER',
        method: 'CASH',
        amount: order.netPayable,
      });
    expect(replay.status).toBe(201);
    expect(replay.body.payment_transaction_id).toBe(
      first.body.payment_transaction_id,
    );
    const conflict = await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/transactions`)
      .set(bearer(admin.tokens.accessToken))
      .set('Idempotency-Key', key)
      .send({
        payer_type: 'CUSTOMER',
        method: 'CASH',
        amount: '1.00',
      });
    expect(conflict.status).toBe(409);
    expect(conflict.body.error.code).toBe('IDEMPOTENCY_CONFLICT');
    const count = await postgres.query<{ count: string }>(
      `SELECT count(*)::text AS count FROM payment_transactions WHERE order_id = $1 AND transaction_status = 'PAID'`,
      [order.orderId],
    );
    expect(count.rows[0].count).toBe('1');
  });

  it('serializes two identical concurrent cash collections', async () => {
    const order = await createConfirmedOrder();
    await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/responsibility`)
      .set(bearer(order.token))
      .send({ who_pays: 'CUSTOMER' });
    await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/plan`)
      .set(bearer(order.token))
      .send({
        customer_planned_online: '0.00',
        customer_planned_cash: order.netPayable,
        receiver_planned_online: '0.00',
        receiver_planned_cash: '0.00',
      });
    const key = uniqueIdempotencyKey();
    const payload = {
      payer_type: 'CUSTOMER',
      method: 'CASH',
      amount: order.netPayable,
    };
    const [first, second] = await Promise.all([
      request(app.getHttpServer())
        .post(`/v1/orders/${order.orderId}/payment/transactions`)
        .set(bearer(admin.tokens.accessToken))
        .set('Idempotency-Key', key)
        .send(payload),
      request(app.getHttpServer())
        .post(`/v1/orders/${order.orderId}/payment/transactions`)
        .set(bearer(admin.tokens.accessToken))
        .set('Idempotency-Key', key)
        .send(payload),
    ]);
    expect([first.status, second.status].sort()).toEqual([201, 201]);
    expect(first.body.payment_transaction_id).toBe(
      second.body.payment_transaction_id,
    );
    const count = await postgres.query<{ count: string }>(
      `SELECT count(*)::text AS count FROM payment_transactions WHERE order_id = $1`,
      [order.orderId],
    );
    expect(count.rows[0].count).toBe('1');
  });

  it('freezes 85/15 from confirmed Trip Fare and keeps the snapshot immutable', async () => {
    const order = await createConfirmedOrder();
    const freeze = await request(app.getHttpServer())
      .post(`/v1/admin/orders/${order.orderId}/finance/freeze`)
      .set(bearer(admin.tokens.accessToken));
    expect(freeze.status).toBe(201);
    expect(freeze.body.capture_moment).toBe('ADMIN_TEST_TRIGGER');
    expect(freeze.body.snapshot.trip_fare).toBe(order.tripFare);
    expect(freeze.body.snapshot.tax).toBe('0.00');
    expect(freeze.body.snapshot.payment_settings_version_id).toBe(
      paymentSettings.payment_settings_version_id,
    );
    const expected = await finance.allocatePreview(order.tripFare);
    expect(freeze.body.snapshot.rider_amount).toBe(expected.rider_amount);
    expect(freeze.body.snapshot.company_commission_amount).toBe(
      expected.company_commission_amount,
    );
    expect(freeze.body.snapshot.operational_cost_amount).toBe(
      expected.operational_cost_amount,
    );
    expect(freeze.body.snapshot.profit_amount).toBe(expected.profit_amount);

    const got = await request(app.getHttpServer())
      .get(`/v1/orders/${order.orderId}/finance`)
      .set(bearer(order.token));
    expect(got.status).toBe(200);
    expect(got.body.frozen).toBe(true);
    expect(got.body.snapshots).toHaveLength(1);

    await expect(
      postgres.query(
        `UPDATE order_finance_snapshots SET rider_amount = 1 WHERE finance_snapshot_id = $1`,
        [freeze.body.snapshot.finance_snapshot_id],
      ),
    ).rejects.toThrow(/immutable|cannot/i);
    await expect(
      postgres.query(
        `DELETE FROM order_finance_snapshots WHERE finance_snapshot_id = $1`,
        [freeze.body.snapshot.finance_snapshot_id],
      ),
    ).rejects.toThrow(/immutable|cannot/i);
  });

  it('lets an assigned rider collect cash and isolates another rider', async () => {
    const order = await createConfirmedOrder();
    await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/responsibility`)
      .set(bearer(order.token))
      .send({ who_pays: 'CUSTOMER' });
    await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/plan`)
      .set(bearer(order.token))
      .send({
        customer_planned_online: '0.00',
        customer_planned_cash: order.netPayable,
        receiver_planned_online: '0.00',
        receiver_planned_cash: '0.00',
      });
    const rider = await issueRiderSession(app);
    const stranger = await issueRiderSession(app);
    const offer = await request(app.getHttpServer())
      .post(`/v1/admin/orders/${order.orderId}/offers`)
      .set(bearer(admin.tokens.accessToken))
      .send({ rider_profile_id: rider.profileId });
    expect(offer.status).toBe(201);
    const accept = await request(app.getHttpServer())
      .post(`/v1/rider/offers/${offer.body.order_offer_id}/accept`)
      .set(bearer(rider.tokens.accessToken));
    expect(accept.status).toBe(200);

    const cash = await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/transactions`)
      .set(bearer(rider.tokens.accessToken))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({
        payer_type: 'CUSTOMER',
        method: 'CASH',
        amount: order.netPayable,
      });
    expect(cash.status).toBe(201);
    expect(cash.body.transaction_status).toBe('PAID');

    const strangerPay = await request(app.getHttpServer())
      .get(`/v1/orders/${order.orderId}/payment`)
      .set(bearer(stranger.tokens.accessToken));
    expect(strangerPay.status).toBe(403);

    const riderPay = await request(app.getHttpServer())
      .get(`/v1/orders/${order.orderId}/payment`)
      .set(bearer(rider.tokens.accessToken));
    expect(riderPay.status).toBe(200);
    expect(riderPay.body.payment_status.overall.status).toBe('PAID');
  });

  it('does not debit rider wallet or COD during payment recording', async () => {
    const rider = await issueRiderSession(app);
    const order = await createConfirmedOrder();
    await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/responsibility`)
      .set(bearer(order.token))
      .send({ who_pays: 'CUSTOMER' });
    await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/plan`)
      .set(bearer(order.token))
      .send({
        customer_planned_online: '0.00',
        customer_planned_cash: order.netPayable,
        receiver_planned_online: '0.00',
        receiver_planned_cash: '0.00',
      });
    const offer = await request(app.getHttpServer())
      .post(`/v1/admin/orders/${order.orderId}/offers`)
      .set(bearer(admin.tokens.accessToken))
      .send({ rider_profile_id: rider.profileId });
    await request(app.getHttpServer())
      .post(`/v1/rider/offers/${offer.body.order_offer_id}/accept`)
      .set(bearer(rider.tokens.accessToken));
    const before = await postgres.query<{
      wallet: string | null;
      cod: string | null;
      wallet_ledger: string;
      cod_ledger: string;
    }>(
      `
      SELECT
        (SELECT available_balance::text FROM rider_wallet_accounts WHERE rider_profile_id = $1) AS wallet,
        (SELECT cod_due::text FROM rider_cod_accounts WHERE rider_profile_id = $1) AS cod,
        (SELECT count(*)::text FROM wallet_ledger_entries w
           JOIN rider_wallet_accounts a ON a.wallet_account_id = w.wallet_account_id
         WHERE a.rider_profile_id = $1) AS wallet_ledger,
        (SELECT count(*)::text FROM cod_ledger_entries c
           JOIN rider_cod_accounts a ON a.cod_account_id = c.cod_account_id
         WHERE a.rider_profile_id = $1) AS cod_ledger
      `,
      [rider.profileId],
    );
    await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/transactions`)
      .set(bearer(rider.tokens.accessToken))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({
        payer_type: 'CUSTOMER',
        method: 'CASH',
        amount: order.netPayable,
      });
    const after = await postgres.query<{
      wallet: string | null;
      cod: string | null;
      wallet_ledger: string;
      cod_ledger: string;
    }>(
      `
      SELECT
        (SELECT available_balance::text FROM rider_wallet_accounts WHERE rider_profile_id = $1) AS wallet,
        (SELECT cod_due::text FROM rider_cod_accounts WHERE rider_profile_id = $1) AS cod,
        (SELECT count(*)::text FROM wallet_ledger_entries w
           JOIN rider_wallet_accounts a ON a.wallet_account_id = w.wallet_account_id
         WHERE a.rider_profile_id = $1) AS wallet_ledger,
        (SELECT count(*)::text FROM cod_ledger_entries c
           JOIN rider_cod_accounts a ON a.cod_account_id = c.cod_account_id
         WHERE a.rider_profile_id = $1) AS cod_ledger
      `,
      [rider.profileId],
    );
    expect(after.rows[0].wallet).toBe(before.rows[0].wallet);
    expect(after.rows[0].cod).toBe(before.rows[0].cod);
    expect(after.rows[0].wallet_ledger).toBe(before.rows[0].wallet_ledger);
    expect(after.rows[0].cod_ledger).toBe(before.rows[0].cod_ledger);
  });
});
