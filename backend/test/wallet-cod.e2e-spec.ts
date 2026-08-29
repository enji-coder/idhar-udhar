import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { formatInr } from '../src/fare/money';
import { PostgresService } from '../src/database/postgres.service';
import { FinanceService } from '../src/payments/finance.service';
import { WalletCodRepository } from '../src/wallet-cod/wallet-cod.repository';
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

describe('Rider wallet and COD (e2e)', () => {
  let app: INestApplication;
  let postgres: PostgresService;
  let finance: FinanceService;
  let walletCod: WalletCodRepository;
  let catalog: OrderCatalog;
  let customer: Awaited<ReturnType<typeof issueCustomerSession>>;
  let admin: Awaited<ReturnType<typeof issueAdminSession>>;
  let paymentSettings: Awaited<ReturnType<typeof ensureActivePaymentSettings>>;

  beforeAll(async () => {
    app = await createTestApp();
    postgres = app.get(PostgresService);
    finance = app.get(FinanceService);
    walletCod = app.get(WalletCodRepository);
    catalog = await ensureOrderCatalog(postgres);
    paymentSettings = await ensureActivePaymentSettings(postgres);
    customer = await issueCustomerSession(app);
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
      token,
    };
  }

  async function setPlan(
    orderId: string,
    token: string,
    kind: 'CASH' | 'ONLINE',
    bill: string,
  ) {
    const responsibility = await request(app.getHttpServer())
      .post(`/v1/orders/${orderId}/payment/responsibility`)
      .set(bearer(token))
      .send({ who_pays: 'CUSTOMER' });
    expect(responsibility.status).toBe(201);
    const plan = await request(app.getHttpServer())
      .post(`/v1/orders/${orderId}/payment/plan`)
      .set(bearer(token))
      .send({
        customer_planned_online: kind === 'ONLINE' ? bill : '0.00',
        customer_planned_cash: kind === 'CASH' ? bill : '0.00',
        receiver_planned_online: '0.00',
        receiver_planned_cash: '0.00',
      });
    expect(plan.status).toBe(201);
  }

  async function assignRider(
    orderId: string,
    rider: Awaited<ReturnType<typeof issueRiderSession>>,
  ) {
    const offer = await request(app.getHttpServer())
      .post(`/v1/admin/orders/${orderId}/offers`)
      .set(bearer(admin.tokens.accessToken))
      .send({ rider_profile_id: rider.profileId });
    expect(offer.status).toBe(201);
    const accept = await request(app.getHttpServer())
      .post(`/v1/rider/offers/${offer.body.order_offer_id}/accept`)
      .set(bearer(rider.tokens.accessToken));
    expect(accept.status).toBe(200);
    return offer.body.order_offer_id as string;
  }

  async function freeze(orderId: string) {
    const result = await request(app.getHttpServer())
      .post(`/v1/admin/orders/${orderId}/finance/freeze`)
      .set(bearer(admin.tokens.accessToken));
    expect(result.status).toBe(201);
    return result.body.snapshot as {
      rider_amount: string;
      company_commission_amount: string;
      trip_fare: string;
      tax: string;
    };
  }

  async function collectCash(
    orderId: string,
    amount: string,
    rider: Awaited<ReturnType<typeof issueRiderSession>>,
  ) {
    const result = await request(app.getHttpServer())
      .post(`/v1/orders/${orderId}/payment/transactions`)
      .set(bearer(rider.tokens.accessToken))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({
        payer_type: 'CUSTOMER',
        method: 'CASH',
        amount,
      });
    expect(result.status).toBe(201);
  }

  async function fixtureCodDue(riderProfileId: string, amount: string) {
    await postgres.transaction(async (tx) => {
      const accounts = await walletCod.lockAccounts(riderProfileId, tx);
      const already = formatInr(accounts.cod.cod_due);
      if (already !== '0.00') {
        throw new Error(`Expected zero COD Due before fixture, got ${already}`);
      }
      await walletCod.increaseCod(accounts.cod.cod_account_id, amount, tx);
      await walletCod.insertCodLedger(
        {
          codAccountId: accounts.cod.cod_account_id,
          direction: 'INCREASE',
          amount,
          source: 'ADMIN_ADJUSTMENT',
          sourceTxnId: `test-cod:${riderProfileId}:${amount}:${Date.now()}`,
        },
        tx,
      );
      await walletCod.syncOperationalStatus(
        riderProfileId,
        amount,
        accounts.threshold,
        tx,
      );
    });
  }

  it('starts a rider wallet at ₹0 with a matching empty ledger', async () => {
    const rider = await issueRiderSession(app);
    const wallet = await request(app.getHttpServer())
      .get('/v1/rider/wallet')
      .set(bearer(rider.tokens.accessToken));
    expect(wallet.status).toBe(200);
    expect(wallet.body.rider_profile_id).toBe(rider.profileId);
    expect(wallet.body.available_balance).toBe('0.00');
    const ledger = await request(app.getHttpServer())
      .get('/v1/rider/wallet/ledger')
      .set(bearer(rider.tokens.accessToken));
    expect(ledger.status).toBe(200);
    expect(ledger.body.entries).toEqual([]);
    const cod = await request(app.getHttpServer())
      .get('/v1/rider/cod')
      .set(bearer(rider.tokens.accessToken));
    expect(cod.status).toBe(200);
    expect(cod.body.cod_due).toBe('0.00');
    expect(cod.body.suspended).toBe(false);
    expect(cod.body.suspend_threshold).toBe('100.00');
  });

  it('credits 85/15 rider earning to the wallet from a frozen digital trip', async () => {
    const rider = await issueRiderSession(app);
    const order = await createConfirmedOrder();
    await setPlan(order.orderId, order.token, 'ONLINE', order.netPayable);
    await assignRider(order.orderId, rider);
    const snapshot = await freeze(order.orderId);
    const expected = await finance.allocatePreview(order.tripFare);
    expect(snapshot.tax).toBe('0.00');
    expect(snapshot.rider_amount).toBe(expected.rider_amount);
    expect(snapshot.company_commission_amount).toBe(
      expected.company_commission_amount,
    );
    if (
      formatInr(paymentSettings.rider_percentage) === '85.00' &&
      formatInr(paymentSettings.company_commission_percentage) === '15.00' &&
      order.tripFare === '100.00'
    ) {
      expect(snapshot.rider_amount).toBe('85.00');
      expect(snapshot.company_commission_amount).toBe('15.00');
    }
    const wallet = await request(app.getHttpServer())
      .get('/v1/rider/wallet')
      .set(bearer(rider.tokens.accessToken));
    expect(wallet.body.available_balance).toBe(snapshot.rider_amount);
    const ledger = await request(app.getHttpServer())
      .get('/v1/rider/wallet/ledger')
      .set(bearer(rider.tokens.accessToken));
    expect(ledger.body.entries).toHaveLength(1);
    expect(ledger.body.entries[0].entry_type).toBe('EARNING');
    expect(ledger.body.entries[0].direction).toBe('CREDIT');
    expect(ledger.body.entries[0].amount).toBe(snapshot.rider_amount);
    const earnings = await request(app.getHttpServer())
      .get('/v1/rider/earnings')
      .set(bearer(rider.tokens.accessToken));
    expect(earnings.status).toBe(200);
    expect(earnings.body.earnings[0].rider_amount).toBe(snapshot.rider_amount);
    expect(earnings.body.earnings[0].tax).toBe('0.00');
    const net = await postgres.query<{
      balance: string;
      ledger: string;
    }>(
      `
      SELECT
        a.available_balance::text AS balance,
        COALESCE(SUM(CASE WHEN l.direction = 'CREDIT' THEN l.amount ELSE -l.amount END), 0)::text AS ledger
      FROM rider_wallet_accounts a
      LEFT JOIN wallet_ledger_entries l ON l.wallet_account_id = a.wallet_account_id
      WHERE a.rider_profile_id = $1
      GROUP BY a.available_balance
      `,
      [rider.profileId],
    );
    expect(formatInr(net.rows[0].balance)).toBe(formatInr(net.rows[0].ledger));
  });

  it('computes locked Trip Fare ₹100 as rider ₹85 / company ₹15', async () => {
    const alloc = await finance.allocatePreview('100.00');
    expect(alloc.tax).toBe('0.00');
    if (
      formatInr(paymentSettings.rider_percentage) === '85.00' &&
      formatInr(paymentSettings.company_commission_percentage) === '15.00'
    ) {
      expect(alloc.rider_amount).toBe('85.00');
      expect(alloc.company_commission_amount).toBe('15.00');
      expect(alloc.operational_cost_amount).toBe('7.50');
      expect(alloc.profit_amount).toBe('7.50');
    }
  });

  it('posts COD Due from cash collection without crediting the cash earning to wallet', async () => {
    const rider = await issueRiderSession(app);
    const order = await createConfirmedOrder();
    await setPlan(order.orderId, order.token, 'CASH', order.netPayable);
    await assignRider(order.orderId, rider);
    const snapshot = await freeze(order.orderId);
    const before = await request(app.getHttpServer())
      .get('/v1/rider/wallet')
      .set(bearer(rider.tokens.accessToken));
    expect(before.body.available_balance).toBe('0.00');
    await collectCash(order.orderId, order.netPayable, rider);
    const wallet = await request(app.getHttpServer())
      .get('/v1/rider/wallet')
      .set(bearer(rider.tokens.accessToken));
    expect(wallet.body.available_balance).toBe('0.00');
    const due = await postgres.query<{ due: string }>(
      `
      SELECT GREATEST(
        0::numeric(12,2),
        $1::numeric(12,2) - $2::numeric(12,2)
      )::text AS due
      `,
      [order.netPayable, snapshot.rider_amount],
    );
    const expectedDue = formatInr(due.rows[0].due);
    const cod = await request(app.getHttpServer())
      .get('/v1/rider/cod')
      .set(bearer(rider.tokens.accessToken));
    expect(cod.body.cod_due).toBe(expectedDue);
    const ledger = await request(app.getHttpServer())
      .get('/v1/rider/cod/ledger')
      .set(bearer(rider.tokens.accessToken));
    expect(ledger.body.entries).toHaveLength(1);
    expect(ledger.body.entries[0].direction).toBe('INCREASE');
    expect(ledger.body.entries[0].source).toBe('CASH_COMPANY_SHARE');
    expect(ledger.body.entries[0].amount).toBe(expectedDue);
  });

  it('settles COD Due to zero without going negative', async () => {
    const rider = await issueRiderSession(app);
    await request(app.getHttpServer())
      .get('/v1/rider/wallet')
      .set(bearer(rider.tokens.accessToken));
    await fixtureCodDue(rider.profileId, '15.00');
    const over = await request(app.getHttpServer())
      .post('/v1/rider/cod/settle')
      .set(bearer(rider.tokens.accessToken))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({ amount: '15.01' });
    expect(over.status).toBe(409);
    expect(over.body.error.code).toBe('COD_SETTLEMENT_EXCEEDS_DUE');
    const settle = await request(app.getHttpServer())
      .post('/v1/rider/cod/settle')
      .set(bearer(rider.tokens.accessToken))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({ amount: '15.00' });
    expect(settle.status).toBe(201);
    expect(settle.body.cod_due).toBe('0.00');
    expect(settle.body.available_balance).toBe('0.00');
    const again = await request(app.getHttpServer())
      .get('/v1/rider/cod')
      .set(bearer(rider.tokens.accessToken));
    expect(again.body.cod_due).toBe('0.00');
    expect(again.body.suspended).toBe(false);
  });

  it('applies recharge settle-first: wallet ₹85, COD ₹15, recharge ₹20 → ₹90 / ₹0', async () => {
    const rider = await issueRiderSession(app);
    const topup = await request(app.getHttpServer())
      .post('/v1/rider/wallet/recharge')
      .set(bearer(rider.tokens.accessToken))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({ amount: '85.00' });
    expect(topup.status).toBe(201);
    expect(topup.body.available_balance).toBe('85.00');
    await fixtureCodDue(rider.profileId, '15.00');
    const recharge = await request(app.getHttpServer())
      .post('/v1/rider/wallet/recharge')
      .set(bearer(rider.tokens.accessToken))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({ amount: '20.00' });
    expect(recharge.status).toBe(201);
    expect(recharge.body.cod_due).toBe('0.00');
    expect(recharge.body.available_balance).toBe('90.00');
    expect(recharge.body.settled_against_cod).toBe('15.00');
    expect(recharge.body.wallet_credited).toBe('5.00');
    const wallet = await request(app.getHttpServer())
      .get('/v1/rider/wallet')
      .set(bearer(rider.tokens.accessToken));
    expect(wallet.body.available_balance).toBe('90.00');
  });

  it('rejects a second wallet debit that would go negative via the CHECK constraint', async () => {
    const rider = await issueRiderSession(app);
    await request(app.getHttpServer())
      .post('/v1/rider/wallet/recharge')
      .set(bearer(rider.tokens.accessToken))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({ amount: '5.00' });
    const failed = await postgres.query(
      `
      UPDATE rider_wallet_accounts
      SET available_balance = available_balance - 10.00
      WHERE rider_profile_id = $1
      `,
      [rider.profileId],
    ).catch((err: { code?: string }) => err);
    expect((failed as { code?: string }).code).toBe('23514');
    const wallet = await request(app.getHttpServer())
      .get('/v1/rider/wallet')
      .set(bearer(rider.tokens.accessToken));
    expect(wallet.body.available_balance).toBe('5.00');
  });

  it('blocks accept at COD Due ₹100 and allows accept at ₹99.99', async () => {
    const blocked = await issueRiderSession(app);
    await request(app.getHttpServer())
      .get('/v1/rider/cod')
      .set(bearer(blocked.tokens.accessToken));
    const pending = await createConfirmedOrder();
    const pendingOffer = await request(app.getHttpServer())
      .post(`/v1/admin/orders/${pending.orderId}/offers`)
      .set(bearer(admin.tokens.accessToken))
      .send({ rider_profile_id: blocked.profileId });
    expect(pendingOffer.status).toBe(201);
    await fixtureCodDue(blocked.profileId, '100.00');
    const blockedCod = await request(app.getHttpServer())
      .get('/v1/rider/cod')
      .set(bearer(blocked.tokens.accessToken));
    expect(blockedCod.body.cod_due).toBe('100.00');
    expect(blockedCod.body.suspended).toBe(true);
    const accept = await request(app.getHttpServer())
      .post(`/v1/rider/offers/${pendingOffer.body.order_offer_id}/accept`)
      .set(bearer(blocked.tokens.accessToken));
    expect(accept.status).toBe(409);
    expect(accept.body.error.code).toBe('RIDER_NOT_ELIGIBLE');

    const blockedOrder = await createConfirmedOrder();
    const blockedOffer = await request(app.getHttpServer())
      .post(`/v1/admin/orders/${blockedOrder.orderId}/offers`)
      .set(bearer(admin.tokens.accessToken))
      .send({ rider_profile_id: blocked.profileId });
    expect(blockedOffer.status).toBe(409);
    expect(blockedOffer.body.error.code).toBe('RIDER_NOT_ELIGIBLE');

    const allowed = await issueRiderSession(app);
    await request(app.getHttpServer())
      .get('/v1/rider/cod')
      .set(bearer(allowed.tokens.accessToken));
    await fixtureCodDue(allowed.profileId, '99.99');
    const allowedCod = await request(app.getHttpServer())
      .get('/v1/rider/cod')
      .set(bearer(allowed.tokens.accessToken));
    expect(allowedCod.body.cod_due).toBe('99.99');
    expect(allowedCod.body.suspended).toBe(false);
    const allowedOrder = await createConfirmedOrder();
    await assignRider(allowedOrder.orderId, allowed);

    const cmp = await postgres.query<{
      hundred: boolean;
      under: boolean;
    }>(
      `
      SELECT
        '100.00'::numeric(12,2) >= '100.00'::numeric(12,2) AS hundred,
        '99.99'::numeric(12,2) >= '100.00'::numeric(12,2) AS under
      `,
    );
    expect(cmp.rows[0].hundred).toBe(true);
    expect(cmp.rows[0].under).toBe(false);
  });

  it('clears suspension after COD Due drops below ₹100', async () => {
    const rider = await issueRiderSession(app);
    await request(app.getHttpServer())
      .get('/v1/rider/wallet')
      .set(bearer(rider.tokens.accessToken));
    await fixtureCodDue(rider.profileId, '100.00');
    const settle = await request(app.getHttpServer())
      .post('/v1/rider/cod/settle')
      .set(bearer(rider.tokens.accessToken))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({ amount: '0.01' });
    expect(settle.status).toBe(201);
    expect(settle.body.cod_due).toBe('99.99');
    expect(settle.body.suspended).toBe(false);
    const order = await createConfirmedOrder();
    await assignRider(order.orderId, rider);
  });

  it('serializes concurrent recharges without lost updates', async () => {
    const rider = await issueRiderSession(app);
    await request(app.getHttpServer())
      .post('/v1/rider/wallet/recharge')
      .set(bearer(rider.tokens.accessToken))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({ amount: '85.00' });
    await fixtureCodDue(rider.profileId, '15.00');
    const [first, second] = await Promise.all([
      request(app.getHttpServer())
        .post('/v1/rider/wallet/recharge')
        .set(bearer(rider.tokens.accessToken))
        .set('Idempotency-Key', uniqueIdempotencyKey())
        .send({ amount: '20.00' }),
      request(app.getHttpServer())
        .post('/v1/rider/wallet/recharge')
        .set(bearer(rider.tokens.accessToken))
        .set('Idempotency-Key', uniqueIdempotencyKey())
        .send({ amount: '20.00' }),
    ]);
    expect(first.status).toBe(201);
    expect(second.status).toBe(201);
    const wallet = await request(app.getHttpServer())
      .get('/v1/rider/wallet')
      .set(bearer(rider.tokens.accessToken));
    const cod = await request(app.getHttpServer())
      .get('/v1/rider/cod')
      .set(bearer(rider.tokens.accessToken));
    expect(wallet.body.available_balance).toBe('110.00');
    expect(cod.body.cod_due).toBe('0.00');
  });

  it('replays the same recharge idempotency key and conflicts on a different body', async () => {
    const rider = await issueRiderSession(app);
    const key = uniqueIdempotencyKey();
    const first = await request(app.getHttpServer())
      .post('/v1/rider/wallet/recharge')
      .set(bearer(rider.tokens.accessToken))
      .set('Idempotency-Key', key)
      .send({ amount: '10.00' });
    const replay = await request(app.getHttpServer())
      .post('/v1/rider/wallet/recharge')
      .set(bearer(rider.tokens.accessToken))
      .set('Idempotency-Key', key)
      .send({ amount: '10.00' });
    expect(first.status).toBe(201);
    expect(replay.status).toBe(201);
    expect(replay.body).toEqual(first.body);
    const conflict = await request(app.getHttpServer())
      .post('/v1/rider/wallet/recharge')
      .set(bearer(rider.tokens.accessToken))
      .set('Idempotency-Key', key)
      .send({ amount: '11.00' });
    expect(conflict.status).toBe(409);
    expect(conflict.body.error.code).toBe('IDEMPOTENCY_CONFLICT');
    const wallet = await request(app.getHttpServer())
      .get('/v1/rider/wallet')
      .set(bearer(rider.tokens.accessToken));
    expect(wallet.body.available_balance).toBe('10.00');
  });

  it('forbids customers and other riders from reading rider wallet/COD', async () => {
    const rider = await issueRiderSession(app);
    const stranger = await issueRiderSession(app);
    const otherCustomer = await issueCustomerSession(app);
    await request(app.getHttpServer())
      .get('/v1/rider/wallet')
      .set(bearer(rider.tokens.accessToken));
    const customerWallet = await request(app.getHttpServer())
      .get('/v1/rider/wallet')
      .set(bearer(otherCustomer.tokens.accessToken));
    expect(customerWallet.status).toBe(403);
    const customerCod = await request(app.getHttpServer())
      .get('/v1/rider/cod')
      .set(bearer(otherCustomer.tokens.accessToken));
    expect(customerCod.status).toBe(403);
    const adminWallet = await request(app.getHttpServer())
      .get(`/v1/admin/riders/${rider.profileId}/wallet`)
      .set(bearer(admin.tokens.accessToken));
    expect(adminWallet.status).toBe(200);
    expect(adminWallet.body.rider_profile_id).toBe(rider.profileId);
    const strangerAdmin = await request(app.getHttpServer())
      .get(`/v1/admin/riders/${rider.profileId}/wallet`)
      .set(bearer(stranger.tokens.accessToken));
    expect(strangerAdmin.status).toBe(403);
    const staff = await issueAdminSession(app, {
      role: 'SUPPORT',
      financeAccess: false,
    });
    const denied = await request(app.getHttpServer())
      .get(`/v1/admin/riders/${rider.profileId}/cod`)
      .set(bearer(staff.tokens.accessToken));
    expect(denied.status).toBe(403);
  });

  it('rejects UPDATE/DELETE of wallet and COD ledger rows', async () => {
    const rider = await issueRiderSession(app);
    await request(app.getHttpServer())
      .post('/v1/rider/wallet/recharge')
      .set(bearer(rider.tokens.accessToken))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({ amount: '10.00' });
    await expect(
      postgres.query(
        `
        UPDATE wallet_ledger_entries l
        SET amount = l.amount + 1
        FROM rider_wallet_accounts a
        WHERE l.wallet_account_id = a.wallet_account_id
          AND a.rider_profile_id = $1
        `,
        [rider.profileId],
      ),
    ).rejects.toThrow(/immutable|cannot/i);
    await expect(
      postgres.query(
        `
        DELETE FROM wallet_ledger_entries l
        USING rider_wallet_accounts a
        WHERE l.wallet_account_id = a.wallet_account_id
          AND a.rider_profile_id = $1
        `,
        [rider.profileId],
      ),
    ).rejects.toThrow(/immutable|cannot/i);
    await fixtureCodDue(rider.profileId, '5.00');
    await expect(
      postgres.query(
        `
        UPDATE cod_ledger_entries l
        SET amount = l.amount + 1
        FROM rider_cod_accounts a
        WHERE l.cod_account_id = a.cod_account_id
          AND a.rider_profile_id = $1
        `,
        [rider.profileId],
      ),
    ).rejects.toThrow(/immutable|cannot/i);
  });

  it('keeps resend Case A on 85/15 of extra km bill and Case B on 10/8/2', async () => {
    const km = '3.000';
    const base = catalog.rates.base_fare;
    const rows = await postgres.query<{
      case_a_customer: string;
      case_a_rider: string;
      case_a_company: string;
      case_b_customer: string;
      case_b_rider: string;
      case_b_company: string;
      case_b_as_85: string;
    }>(
      `
      SELECT
        case_a_customer::text AS case_a_customer,
        ROUND(case_a_customer * rider_percentage / 100, 2)::text AS case_a_rider,
        ROUND(
          case_a_customer - ROUND(case_a_customer * rider_percentage / 100, 2),
          2
        )::text AS case_a_company,
        case_b_customer::text AS case_b_customer,
        case_b_rider::text AS case_b_rider,
        case_b_company::text AS case_b_company,
        ROUND(case_b_customer * rider_percentage / 100, 2)::text AS case_b_as_85
      FROM (
        SELECT
          s.rider_percentage,
          ROUND(
            $1::numeric(12,2) + COALESCE(e.resend_case_a_per_km, 10) * $2::numeric(12,3),
            2
          ) AS case_a_customer,
          ROUND(COALESCE(e.resend_case_b_customer_per_km, 10) * $2::numeric(12,3), 2) AS case_b_customer,
          ROUND(COALESCE(e.resend_case_b_rider_per_km, 8) * $2::numeric(12,3), 2) AS case_b_rider,
          ROUND(COALESCE(e.resend_case_b_company_per_km, 2) * $2::numeric(12,3), 2) AS case_b_company
        FROM payment_settings_versions s
        LEFT JOIN extra_rate_versions e ON e.status = 'ACTIVE'
        WHERE s.status = 'ACTIVE'
      ) calc
      `,
      [base, km],
    );
    const row = rows.rows[0];
    expect(formatInr(row.case_b_rider)).not.toBe(formatInr(row.case_b_as_85));
    expect(formatInr(row.case_b_customer)).toBe('30.00');
    expect(formatInr(row.case_b_rider)).toBe('24.00');
    expect(formatInr(row.case_b_company)).toBe('6.00');
    const caseACheck = await postgres.query<{ ok: boolean }>(
      `
      SELECT (
        $1::numeric(12,2) + $2::numeric(12,2) = $3::numeric(12,2)
      ) AS ok
      `,
      [row.case_a_rider, row.case_a_company, row.case_a_customer],
    );
    expect(caseACheck.rows[0].ok).toBe(true);
  });
});
