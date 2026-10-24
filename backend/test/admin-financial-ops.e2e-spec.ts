import { join } from 'node:path';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { Client } from 'pg';
import { PostgresService } from '../src/database/postgres.service';
import { SettlementRepository } from '../src/settlement/settlement.repository';
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
import { applyDisposableMigrations } from './apply-disposable-migrations';

const disposable =
  process.env.DATABASE_HOST === '127.0.0.1' &&
  process.env.DATABASE_PORT === '54329' &&
  process.env.DATABASE_NAME === 'idhar_udhar_disposable';

const describeOps = disposable ? describe : describe.skip;

describeOps('admin financial operations on disposable Postgres', () => {
  let app: INestApplication;
  let postgres: PostgresService;
  let catalog: OrderCatalog;
  let admin: Awaited<ReturnType<typeof issueAdminSession>>;
  let customer: Awaited<ReturnType<typeof issueCustomerSession>>;
  let rider: Awaited<ReturnType<typeof issueRiderSession>>;
  let settingsId: string;

  beforeAll(async () => {
    await applyDisposableMigrations(join(__dirname, '../../records_database/migrations'));
    app = await createTestApp();
    postgres = app.get(PostgresService);
    catalog = await ensureOrderCatalog(postgres);
    const settings = await ensureActivePaymentSettings(postgres);
    settingsId = settings.payment_settings_version_id;
    admin = await issueAdminSession(app);
    customer = await issueCustomerSession(app);
    rider = await issueRiderSession(app);
  }, 180000);

  afterAll(async () => {
    if (app) {
      await app.close();
    }
  });

  function bearer(token: string) {
    return { Authorization: `Bearer ${token}` };
  }

  async function createOrder() {
    const created = await request(app.getHttpServer())
      .post('/v1/orders')
      .set(bearer(customer.tokens.accessToken))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({
        city_id: catalog.cityId,
        vehicle_category_id: catalog.vehicleCategoryId,
        package_weight_kg: 1,
        stops: sampleStops(catalog.zoneId),
      });
    expect(created.status).toBe(201);
    return created.body as { order_id: string; display_id: string; crn: string; canonical_status: string };
  }

  async function confirmOrder(orderId: string) {
    const quote = await request(app.getHttpServer())
      .post(`/v1/orders/${orderId}/quote`)
      .set(bearer(customer.tokens.accessToken))
      .send({});
    expect(quote.status).toBe(201);
    const confirm = await request(app.getHttpServer())
      .post(`/v1/orders/${orderId}/confirm`)
      .set(bearer(customer.tokens.accessToken))
      .send({ fare_quote_id: quote.body.fare_quote_id });
    expect(confirm.status).toBe(200);
    return confirm.body as { canonical_status: string };
  }

  function removalBody(order: { display_id: string; crn: string }, crn = order.crn) {
    return {
      reason: 'Disposable historical cleanup',
      confirm_display_id: order.display_id,
      confirm_crn: crn,
    };
  }

  it('rejects purge without an admin token and rejects a CRN mismatch', async () => {
    const order = await createOrder();
    const denied = await request(app.getHttpServer())
      .delete(`/v1/admin/orders/${order.order_id}`)
      .set(bearer(customer.tokens.accessToken))
      .send(removalBody(order));
    expect(denied.status).toBe(403);
    const mismatch = await request(app.getHttpServer())
      .delete(`/v1/admin/orders/${order.order_id}`)
      .set(bearer(admin.tokens.accessToken))
      .send(removalBody(order, 'IU-CRN-AMD-9999999999'));
    expect(mismatch.status).toBe(422);
    const still = await postgres.query(`SELECT 1 FROM orders WHERE order_id = $1`, [order.order_id]);
    expect(still.rowCount).toBe(1);
  });

  it('purges an unconfirmed historical order and writes the audit row', async () => {
    const order = await createOrder();
    expect(order.canonical_status).toBe('CREATED');
    const purged = await request(app.getHttpServer())
      .delete(`/v1/admin/orders/${order.order_id}`)
      .set(bearer(admin.tokens.accessToken))
      .send(removalBody(order));
    expect(purged.status).toBe(200);
    expect(purged.body.result).toBe('purged');
    const gone = await postgres.query(`SELECT 1 FROM orders WHERE order_id = $1`, [order.order_id]);
    expect(gone.rowCount).toBe(0);
    const stops = await postgres.query(`SELECT 1 FROM order_stops WHERE order_id = $1`, [order.order_id]);
    expect(stops.rowCount).toBe(0);
    const audit = await postgres.query(
      `SELECT action FROM audit_logs WHERE entity_id = $1 AND action = 'ORDER_PURGED'`,
      [order.order_id],
    );
    expect(audit.rowCount).toBe(1);
  });

  it('rejects an active order and a financially dependent order without partial deletes', async () => {
    const active = await createOrder();
    await confirmOrder(active.order_id);
    const blocked = await request(app.getHttpServer())
      .delete(`/v1/admin/orders/${active.order_id}`)
      .set(bearer(admin.tokens.accessToken))
      .send(removalBody(active));
    expect(blocked.status).toBe(409);
    expect(blocked.body.error.code).toBe('ORDER_DELETE_BLOCKED');
    const stopsBefore = await postgres.query<{ n: string }>(
      `SELECT count(*)::text AS n FROM order_stops WHERE order_id = $1`,
      [active.order_id],
    );

    const cancelled = await request(app.getHttpServer())
      .post(`/v1/admin/orders/${active.order_id}/cancel`)
      .set(bearer(admin.tokens.accessToken));
    expect(cancelled.status).toBe(200);
    await postgres.query(
      `
      INSERT INTO payment_transactions (
        order_id, payer_type, method, amount, direction, transaction_status,
        idempotency_key, created_by_type
      )
      VALUES ($1, 'CUSTOMER', 'CASH', 10.00, 'CHARGE', 'PAID', $2, 'ADMIN')
      `,
      [active.order_id, uniqueIdempotencyKey()],
    );
    const financial = await request(app.getHttpServer())
      .delete(`/v1/admin/orders/${active.order_id}`)
      .set(bearer(admin.tokens.accessToken))
      .send(removalBody(active));
    expect(financial.status).toBe(409);
    expect(financial.body.error.code).toBe('ORDER_FINANCIAL_DEPENDENCY');
    const stopsAfter = await postgres.query<{ n: string }>(
      `SELECT count(*)::text AS n FROM order_stops WHERE order_id = $1`,
      [active.order_id],
    );
    expect(stopsAfter.rows[0].n).toBe(stopsBefore.rows[0].n);
    const payment = await postgres.query(`SELECT 1 FROM payment_transactions WHERE order_id = $1`, [active.order_id]);
    expect(payment.rowCount).toBe(1);
  });

  it('hides a dependent order idempotently and keeps it in the GST delivered set', async () => {
    const order = await createOrder();
    await confirmOrder(order.order_id);
    await postgres.query(
      `UPDATE orders SET canonical_status = 'DELIVERED' WHERE order_id = $1`,
      [order.order_id],
    );
    await postgres.query(
      `
      INSERT INTO order_finance_snapshots (
        order_id, snapshot_kind, trip_fare, rider_percentage, company_commission_percentage,
        operational_cost_percentage_of_commission, rider_amount, company_commission_amount,
        operational_cost_amount, profit_amount, payment_settings_version_id, frozen_at
      )
      VALUES (
        $1, 'ORIGINAL', 100.00, 85, 15, 50, 85.00, 15.00, 7.50, 7.50, $2, now()
      )
      `,
      [order.order_id, settingsId],
    );
    const hidden = await request(app.getHttpServer())
      .post(`/v1/admin/orders/${order.order_id}/remove-from-operations`)
      .set(bearer(admin.tokens.accessToken))
      .send(removalBody(order));
    expect(hidden.status).toBe(200);
    expect(hidden.body.result).toBe('removed_from_operations');
    const again = await request(app.getHttpServer())
      .post(`/v1/admin/orders/${order.order_id}/remove-from-operations`)
      .set(bearer(admin.tokens.accessToken))
      .send(removalBody(order));
    expect(again.status).toBe(200);
    expect(again.body.result).toBe('already_removed');
    const list = await request(app.getHttpServer())
      .get('/v1/admin/orders')
      .set(bearer(admin.tokens.accessToken));
    expect(list.status).toBe(200);
    expect(list.body.orders.some((row: { order_id: string }) => row.order_id === order.order_id)).toBe(false);
    const gst = await request(app.getHttpServer())
      .get('/v1/admin/reports/gst')
      .query({ preset: 'today', crn: order.crn })
      .set(bearer(admin.tokens.accessToken));
    expect(gst.status).toBe(200);
    const match = gst.body.records.find((row: { order_id: string }) => row.order_id === order.order_id);
    expect(match).toBeTruthy();
    expect(match.crn).toBe(order.crn);
    expect(match.trip_fare).toBe('100.00');
    expect(gst.body.summary.total_trip_fare).toBe('100.00');
  });

  it('does not invoice a cancelled order and does not let the purge flag leak', async () => {
    const order = await createOrder();
    await confirmOrder(order.order_id);
    const cancelled = await request(app.getHttpServer())
      .post(`/v1/admin/orders/${order.order_id}/cancel`)
      .set(bearer(admin.tokens.accessToken));
    expect(cancelled.status).toBe(200);
    const check = await request(app.getHttpServer())
      .post(`/v1/admin/orders/${order.order_id}/invoice-check`)
      .set(bearer(admin.tokens.accessToken));
    expect(check.status).toBe(409);
    expect(check.body.error.code).toBe('INVOICE_ORDER_CANCELLED');
    const settlement = app.get(SettlementRepository);
    await postgres.transaction(async (tx) => {
      const inserted = await settlement.insertInvoice(
        {
          invoiceNumber: `INV-DISP-${order.order_id.slice(0, 8)}`,
          orderId: order.order_id,
          tripFare: '100.00',
          additional: '0.00',
          billedTotal: '100.00',
          customerPaid: '0.00',
          receiverPaid: '0.00',
          paymentStatus: 'UNPAID',
        },
        tx,
      );
      expect(inserted).toBeUndefined();
    });
    const invoices = await postgres.query(`SELECT 1 FROM invoices WHERE order_id = $1`, [order.order_id]);
    expect(invoices.rowCount).toBe(0);

    await expect(
      postgres.transaction(async (tx) => {
        await tx.query(
          `
          INSERT INTO invoices (
            invoice_number, order_id, status, issued_at,
            trip_fare, discount, additional_locked_charges, rounding, billed_total,
            customer_paid, receiver_paid, gst_on_fare
          )
          VALUES ($1, $2, 'ISSUED', now(), 100, 0, 0, 0, 100, 0, 0, 0)
          `,
          [`INV-KEEP-${order.order_id.slice(0, 8)}`, order.order_id],
        );
        await tx.query(`SELECT set_config('app.order_purge', 'on', true)`);
        await tx.query(`DELETE FROM invoices WHERE order_id = $1`, [order.order_id]);
      }),
    ).rejects.toMatchObject({ code: '23001' });
    const leaked = await postgres.query<{ value: string | null }>(
      `SELECT current_setting('app.order_purge', true) AS value`,
    );
    expect(leaked.rows[0].value ?? '').not.toBe('on');
  });

  it('rolls back hide when the audit insert fails', async () => {
    const order = await createOrder();
    await postgres.query(`
      CREATE OR REPLACE FUNCTION disposable_audit_fail()
      RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.action = 'ORDER_REMOVED_FROM_OPERATIONS' THEN
          RAISE EXCEPTION 'forced audit failure';
        END IF;
        RETURN NEW;
      END;
      $$
    `);
    await postgres.query(`
      DROP TRIGGER IF EXISTS disposable_audit_fail ON audit_logs;
      CREATE TRIGGER disposable_audit_fail
      BEFORE INSERT ON audit_logs
      FOR EACH ROW EXECUTE FUNCTION disposable_audit_fail()
    `);
    try {
      const hidden = await request(app.getHttpServer())
        .post(`/v1/admin/orders/${order.order_id}/remove-from-operations`)
        .set(bearer(admin.tokens.accessToken))
        .send(removalBody(order));
      expect(hidden.status).toBeGreaterThanOrEqual(500);
      const row = await postgres.query<{ removed: Date | null }>(
        `SELECT removed_from_operations_at AS removed FROM orders WHERE order_id = $1`,
        [order.order_id],
      );
      expect(row.rows[0].removed).toBeNull();
    } finally {
      await postgres.query(`DROP TRIGGER IF EXISTS disposable_audit_fail ON audit_logs`);
      await postgres.query(`DROP FUNCTION IF EXISTS disposable_audit_fail()`);
    }
  });

  it('reverses an eligible adjustment once and refuses a payout', async () => {
    const account = await postgres.query<{ wallet_account_id: string }>(
      `
      INSERT INTO rider_wallet_accounts (rider_profile_id, available_balance)
      VALUES ($1, 10.00)
      RETURNING wallet_account_id
      `,
      [rider.profileId],
    );
    const ledger = await postgres.query<{ wallet_ledger_id: string }>(
      `
      INSERT INTO wallet_ledger_entries (
        wallet_account_id, direction, amount, entry_type, actor_type, actor_profile_id
      )
      VALUES ($1, 'CREDIT', 10.00, 'ADJUSTMENT', 'ADMIN', $2)
      RETURNING wallet_ledger_id
      `,
      [account.rows[0].wallet_account_id, admin.profileId],
    );
    const otherRider = await issueRiderSession(app);
    const payoutAccount = await postgres.query<{ wallet_account_id: string }>(
      `
      INSERT INTO rider_wallet_accounts (rider_profile_id, available_balance)
      VALUES ($1, 1.00)
      RETURNING wallet_account_id
      `,
      [otherRider.profileId],
    );
    const payout = await postgres.query<{ wallet_ledger_id: string }>(
      `
      INSERT INTO wallet_ledger_entries (
        wallet_account_id, direction, amount, entry_type, actor_type, actor_profile_id
      )
      VALUES ($1, 'DEBIT', 1.00, 'PAYOUT', 'ADMIN', $2)
      RETURNING wallet_ledger_id
      `,
      [payoutAccount.rows[0].wallet_account_id, admin.profileId],
    );
    const body = {
      ledger_kind: 'RIDER_WALLET',
      ledger_id: ledger.rows[0].wallet_ledger_id,
      reason: 'Confirmed dummy rider adjustment',
      confirm: true,
    };
    const first = await request(app.getHttpServer())
      .post('/v1/admin/wallet/cleanup')
      .set(bearer(admin.tokens.accessToken))
      .send(body);
    expect(first.status).toBe(200);
    expect(first.body.result).toBe('reversed');
    const second = await request(app.getHttpServer())
      .post('/v1/admin/wallet/cleanup')
      .set(bearer(admin.tokens.accessToken))
      .send(body);
    expect(second.status).toBe(200);
    expect(second.body.result).toBe('already_reversed');
    const reversals = await postgres.query(
      `SELECT 1 FROM wallet_ledger_entries WHERE reverses_wallet_ledger_id = $1`,
      [ledger.rows[0].wallet_ledger_id],
    );
    expect(reversals.rowCount).toBe(1);
    const balance = await postgres.query<{ available_balance: string; ledger_sum: string }>(
      `
      SELECT
        a.available_balance::text AS available_balance,
        COALESCE(SUM(CASE WHEN e.direction = 'CREDIT' THEN e.amount ELSE -e.amount END), 0)::text AS ledger_sum
      FROM rider_wallet_accounts a
      LEFT JOIN wallet_ledger_entries e ON e.wallet_account_id = a.wallet_account_id
      WHERE a.wallet_account_id = $1
      GROUP BY a.available_balance
      `,
      [account.rows[0].wallet_account_id],
    );
    expect(balance.rows[0].available_balance).toBe(balance.rows[0].ledger_sum);
    const refused = await request(app.getHttpServer())
      .post('/v1/admin/wallet/cleanup')
      .set(bearer(admin.tokens.accessToken))
      .send({ ...body, ledger_id: payout.rows[0].wallet_ledger_id, reason: 'Must not reverse a payout' });
    expect(refused.status).toBe(409);
    expect(refused.body.error.code).toBe('WALLET_CLEANUP_REJECTED');
  });

  it('rejects a reversal that would make the ledger negative and rolls back when audit fails', async () => {
    const customerWallet = await postgres.query<{ customer_wallet_id: string }>(
      `
      INSERT INTO customer_wallet_accounts (customer_profile_id, available_balance)
      VALUES ($1, 10.00)
      ON CONFLICT (customer_profile_id) DO UPDATE
        SET available_balance = EXCLUDED.available_balance
      RETURNING customer_wallet_id
      `,
      [customer.profileId],
    );
    const credit = await postgres.query<{ customer_wallet_ledger_id: string }>(
      `
      INSERT INTO customer_wallet_ledger_entries (
        customer_wallet_id, direction, amount, entry_type, actor_type
      )
      VALUES ($1, 'CREDIT', 100.00, 'ADJUSTMENT', 'ADMIN')
      RETURNING customer_wallet_ledger_id
      `,
      [customerWallet.rows[0].customer_wallet_id],
    );
    await postgres.query(
      `
      INSERT INTO customer_wallet_ledger_entries (
        customer_wallet_id, direction, amount, entry_type, actor_type
      )
      VALUES ($1, 'DEBIT', 90.00, 'ADJUSTMENT', 'ADMIN')
      `,
      [customerWallet.rows[0].customer_wallet_id],
    );
    await postgres.query(
      `UPDATE customer_wallet_accounts SET available_balance = 10.00 WHERE customer_wallet_id = $1`,
      [customerWallet.rows[0].customer_wallet_id],
    );
    const negative = await request(app.getHttpServer())
      .post('/v1/admin/wallet/cleanup')
      .set(bearer(admin.tokens.accessToken))
      .send({
        ledger_kind: 'CUSTOMER_WALLET',
        ledger_id: credit.rows[0].customer_wallet_ledger_id,
        reason: 'This reversal would overdraw',
        confirm: true,
      });
    expect(negative.status).toBe(409);
    const untouched = await postgres.query(
      `SELECT 1 FROM customer_wallet_ledger_entries WHERE reverses_customer_wallet_ledger_id = $1`,
      [credit.rows[0].customer_wallet_ledger_id],
    );
    expect(untouched.rowCount).toBe(0);

    const small = await postgres.query<{ customer_wallet_ledger_id: string }>(
      `
      INSERT INTO customer_wallet_ledger_entries (
        customer_wallet_id, direction, amount, entry_type, actor_type
      )
      VALUES ($1, 'CREDIT', 5.00, 'ADJUSTMENT', 'ADMIN')
      RETURNING customer_wallet_ledger_id
      `,
      [customerWallet.rows[0].customer_wallet_id],
    );
    await postgres.query(`
      CREATE OR REPLACE FUNCTION disposable_wallet_audit_fail()
      RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.action = 'WALLET_ENTRY_REVERSED' THEN
          RAISE EXCEPTION 'forced wallet audit failure';
        END IF;
        RETURN NEW;
      END;
      $$
    `);
    await postgres.query(`
      DROP TRIGGER IF EXISTS disposable_wallet_audit_fail ON audit_logs;
      CREATE TRIGGER disposable_wallet_audit_fail
      BEFORE INSERT ON audit_logs
      FOR EACH ROW EXECUTE FUNCTION disposable_wallet_audit_fail()
    `);
    try {
      const failed = await request(app.getHttpServer())
        .post('/v1/admin/wallet/cleanup')
        .set(bearer(admin.tokens.accessToken))
        .send({
          ledger_kind: 'CUSTOMER_WALLET',
          ledger_id: small.rows[0].customer_wallet_ledger_id,
          reason: 'Audit must roll this back',
          confirm: true,
        });
      expect(failed.status).toBeGreaterThanOrEqual(500);
      const rolled = await postgres.query(
        `SELECT 1 FROM customer_wallet_ledger_entries WHERE reverses_customer_wallet_ledger_id = $1`,
        [small.rows[0].customer_wallet_ledger_id],
      );
      expect(rolled.rowCount).toBe(0);
    } finally {
      await postgres.query(`DROP TRIGGER IF EXISTS disposable_wallet_audit_fail ON audit_logs`);
      await postgres.query(`DROP FUNCTION IF EXISTS disposable_wallet_audit_fail()`);
    }
  });

  it('keeps the purge flag off for a second transaction on a new connection', async () => {
    const client = new Client({
      host: '127.0.0.1',
      port: 54329,
      database: 'idhar_udhar_disposable',
      user: process.env.DATABASE_USER,
      password: process.env.DATABASE_PASSWORD,
    });
    await client.connect();
    try {
      await client.query('BEGIN');
      await client.query(`SELECT set_config('app.order_purge', 'on', true)`);
      await client.query('COMMIT');
      const after = await client.query<{ value: string | null }>(
        `SELECT current_setting('app.order_purge', true) AS value`,
      );
      expect(after.rows[0].value ?? '').not.toBe('on');
      await expect(client.query(`DELETE FROM rider_wallet_accounts WHERE FALSE`)).resolves.toBeTruthy();
      await expect(client.query(`DELETE FROM invoices WHERE FALSE`)).resolves.toBeTruthy();
    } finally {
      await client.end();
    }
  });
});
