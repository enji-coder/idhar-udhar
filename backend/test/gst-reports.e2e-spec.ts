import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { Workbook } from 'exceljs';
import { PostgresService } from '../src/database/postgres.service';
import { allocateGst, sumInr } from '../src/payments/gst-math';
import { localDateOf, REPORT_TIME_ZONE } from '../src/reports/date-range';
import {
  createTestApp,
  ensureActivePaymentSettings,
  ensureOrderCatalog,
  issueAdminSession,
  issueCustomerSession,
  OrderCatalog,
  sampleStops,
  uniqueIdempotencyKey,
} from './helpers';

type FrozenOrder = {
  orderId: string;
  displayId: string;
  tripFare: string;
  netPayable: string;
};

describe('GST reports (e2e)', () => {
  let app: INestApplication;
  let postgres: PostgresService;
  let catalog: OrderCatalog;
  let customer: Awaited<ReturnType<typeof issueCustomerSession>>;
  let admin: Awaited<ReturnType<typeof issueAdminSession>>;

  /** Orders this spec froze, so assertions can scope to its own data. */
  const frozen: FrozenOrder[] = [];

  beforeAll(async () => {
    app = await createTestApp();
    postgres = app.get(PostgresService);
    catalog = await ensureOrderCatalog(postgres);
    await ensureActivePaymentSettings(postgres);
    customer = await issueCustomerSession(app);
    admin = await issueAdminSession(app);
    await ensureSeedTaxConfig();

    for (let i = 0; i < 3; i += 1) {
      frozen.push(await createFrozenOrder());
    }
  });

  afterAll(async () => {
    // Leave the dev database on the intended default configuration.
    await restoreDefaultTaxConfig();
    await app.close();
  });

  function bearer(token: string) {
    return { Authorization: `Bearer ${token}` };
  }

  function adminAuth() {
    return bearer(admin.tokens.accessToken);
  }

  /** Publishes 18% EXCLUSIVE only if nothing is active. Never edits a version. */
  async function ensureSeedTaxConfig(): Promise<void> {
    const active = await postgres.query(
      `SELECT 1 FROM tax_config_versions WHERE status = 'ACTIVE'`,
    );
    if ((active.rowCount ?? 0) > 0) {
      return;
    }
    await request(app.getHttpServer())
      .post('/v1/admin/tax-config')
      .set(adminAuth())
      .send({
        gst_rate: '18.00',
        gst_calculation_basis: 'EXCLUSIVE',
        notes: 'e2e seed',
      })
      .expect(201);
  }

  async function restoreDefaultTaxConfig(): Promise<void> {
    const active = await postgres.query<{
      gst_rate: string;
      gst_calculation_basis: string;
    }>(
      `
      SELECT gst_rate::text AS gst_rate, gst_calculation_basis
      FROM tax_config_versions
      WHERE status = 'ACTIVE'
      `,
    );
    const current = active.rows[0];
    if (
      current &&
      current.gst_rate === '18.00' &&
      current.gst_calculation_basis === 'EXCLUSIVE'
    ) {
      return;
    }
    await request(app.getHttpServer())
      .post('/v1/admin/tax-config')
      .set(adminAuth())
      .send({
        gst_rate: '18.00',
        gst_calculation_basis: 'EXCLUSIVE',
        notes: 'restored default after e2e',
      });
  }

  async function createFrozenOrder(): Promise<FrozenOrder> {
    const token = customer.tokens.accessToken;
    const created = await request(app.getHttpServer())
      .post('/v1/orders')
      .set(bearer(token))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({
        city_id: catalog.cityId,
        vehicle_category_id: catalog.vehicleCategoryId,
        stops: sampleStops(catalog.zoneId),
      })
      .expect(201);
    const quote = await request(app.getHttpServer())
      .post(`/v1/orders/${created.body.order_id}/quote`)
      .set(bearer(token))
      .send({})
      .expect(201);
    await request(app.getHttpServer())
      .post(`/v1/orders/${created.body.order_id}/confirm`)
      .set(bearer(token))
      .send({ fare_quote_id: quote.body.fare_quote_id })
      .expect(200);
    const freeze = await request(app.getHttpServer())
      .post(`/v1/admin/orders/${created.body.order_id}/finance/freeze`)
      .set(adminAuth())
      .send({})
      .expect(201);
    return {
      orderId: created.body.order_id,
      displayId: created.body.display_id,
      tripFare: freeze.body.snapshot.trip_fare,
      netPayable: quote.body.net_payable,
    };
  }

  async function setCustomerBill(
    order: FrozenOrder,
    plan: { cash: string; online: string },
  ): Promise<void> {
    const token = customer.tokens.accessToken;
    await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/responsibility`)
      .set(bearer(token))
      .send({ who_pays: 'CUSTOMER' })
      .expect(201);
    await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/plan`)
      .set(bearer(token))
      .send({
        customer_planned_online: plan.online,
        customer_planned_cash: plan.cash,
        receiver_planned_online: '0.00',
        receiver_planned_cash: '0.00',
      })
      .expect(201);
  }

  /** Cash is the only method the existing rules settle as PAID immediately. */
  async function collectCash(order: FrozenOrder, amount: string): Promise<void> {
    await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/transactions`)
      .set(adminAuth())
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({ payer_type: 'CUSTOMER', method: 'CASH', amount })
      .expect(201);
  }

  async function halfOf(amount: string): Promise<string> {
    const result = await postgres.query<{ half: string }>(
      `SELECT ROUND($1::numeric(12,2) / 2, 2)::text AS half`,
      [amount],
    );
    return result.rows[0].half;
  }

  async function fetchReport(query: Record<string, string | number> = {}) {
    const response = await request(app.getHttpServer())
      .get('/v1/admin/reports/gst')
      .query({ preset: 'today', ...query })
      .set(adminAuth());
    expect(response.status).toBe(200);
    return response.body;
  }

  async function fetchWorkbook(
    query: Record<string, string | number> = {},
  ): Promise<Workbook> {
    const response = await request(app.getHttpServer())
      .get('/v1/admin/reports/gst/export')
      .query({ preset: 'today', ...query })
      .set(adminAuth())
      .responseType('blob');
    expect(response.status).toBe(200);
    const workbook = new Workbook();
    await workbook.xlsx.load(response.body);
    return workbook;
  }

  function recordFor(
    body: { records: Record<string, string>[] },
    orderId: string,
  ): Record<string, string> {
    const found = body.records.find((row) => row.order_id === orderId);
    expect(found).toBeDefined();
    return found as Record<string, string>;
  }

  function mine(records: { order_id: string }[]): { order_id: string }[] {
    return records.filter((row) =>
      frozen.some((item) => item.orderId === row.order_id),
    );
  }

  it('freezes a tax snapshot inside the existing 85/15 finance freeze', async () => {
    const snapshots = await postgres.query<{
      gst_rate: string;
      gst_calculation_basis: string;
      taxable_company_amount: string;
      gst_amount: string;
      operational_cost_amount: string;
      company_profit_amount: string;
    }>(
      `
      SELECT
        gst_rate::text AS gst_rate,
        gst_calculation_basis,
        taxable_company_amount::text AS taxable_company_amount,
        gst_amount::text AS gst_amount,
        operational_cost_amount::text AS operational_cost_amount,
        company_profit_amount::text AS company_profit_amount
      FROM order_tax_snapshots
      WHERE order_id = $1
      `,
      [frozen[0].orderId],
    );
    expect(snapshots.rows).toHaveLength(1);
    const snapshot = snapshots.rows[0];

    const finance = await postgres.query<{
      company_commission_amount: string;
      operational_cost_amount: string;
    }>(
      `
      SELECT
        company_commission_amount::text AS company_commission_amount,
        operational_cost_amount::text AS operational_cost_amount
      FROM order_finance_snapshots
      WHERE order_id = $1 AND snapshot_kind = 'ORIGINAL'
      `,
      [frozen[0].orderId],
    );

    // PostgreSQL wrote the snapshot; the pure formula must agree to the paisa.
    const expected = allocateGst({
      companyCommissionAmount: finance.rows[0].company_commission_amount,
      operationalCostAmount: finance.rows[0].operational_cost_amount,
      gstRate: snapshot.gst_rate,
      basis: snapshot.gst_calculation_basis as 'EXCLUSIVE',
    });
    expect(snapshot.taxable_company_amount).toBe(expected.taxable_company_amount);
    expect(snapshot.gst_amount).toBe(expected.gst_amount);
    expect(snapshot.company_profit_amount).toBe(expected.company_profit_amount);
    // Operational cost is copied from the existing rule, never recomputed.
    expect(snapshot.operational_cost_amount).toBe(
      finance.rows[0].operational_cost_amount,
    );
  });

  it('reports the documented split and keeps the arithmetic reconciled', async () => {
    const body = await fetchReport({ order_id: frozen[0].orderId });
    const record = recordFor(body, frozen[0].orderId);

    if (record.trip_fare === '100.00') {
      expect(record.rider_share).toBe('85.00');
      expect(record.company_commission).toBe('15.00');
      expect(record.operational_cost).toBe('7.50');
      if (record.gst_basis === 'EXCLUSIVE' && record.gst_rate === '18.00') {
        expect(record.gst_amount).toBe('2.70');
        expect(record.company_profit).toBe('4.80');
      }
    }

    // Whatever the fare, the two invariants must hold.
    expect(sumInr([record.rider_share, record.company_commission])).toBe(
      record.trip_fare,
    );
    expect(
      sumInr([record.company_profit, record.gst_amount, record.operational_cost]),
    ).toBe(record.company_commission);
  });

  it('labels the rate, basis, date basis and scope on every response', async () => {
    const body = await fetchReport();
    expect(body.scope).toContain('GST on the customer trip fare is 0');
    expect(body.period.date_basis).toBe('FINANCE_FREEZE');
    expect(body.period.time_zone).toBe(REPORT_TIME_ZONE);
    expect(body.gst_rates_applied.length).toBeGreaterThan(0);
    expect(body.active_tax_config).not.toBeNull();
    for (const record of body.records) {
      expect(['NONE', 'INCLUSIVE', 'EXCLUSIVE', 'UNCONFIGURED']).toContain(
        record.gst_basis,
      );
      expect(typeof record.tax_frozen).toBe('boolean');
    }
  });

  it('returns SQL totals that match the row it aggregated', async () => {
    const body = await fetchReport({ order_id: frozen[0].orderId, limit: 200 });
    expect(body.summary.order_count).toBe(1);
    const record = recordFor(body, frozen[0].orderId);
    expect(body.summary.total_trip_fare).toBe(record.trip_fare);
    expect(body.summary.total_rider_share).toBe(record.rider_share);
    expect(body.summary.total_company_commission).toBe(record.company_commission);
    expect(body.summary.total_gst).toBe(record.gst_amount);
    expect(body.summary.total_operational_cost).toBe(record.operational_cost);
    expect(body.summary.total_company_profit).toBe(record.company_profit);
    expect(body.summary.unconfigured_order_count).toBe(0);
  });

  it('aggregates multiple orders into totals that equal the sum of the rows', async () => {
    const body = await fetchReport({ limit: 200 });
    expect(mine(body.records)).toHaveLength(frozen.length);
    expect(body.summary.order_count).toBeGreaterThanOrEqual(frozen.length);

    // The page holds every matching row, so the rows must sum to the totals.
    if (body.page.returned === body.page.total) {
      const records = body.records as Record<string, string>[];
      expect(sumInr(records.map((row) => row.trip_fare))).toBe(
        body.summary.total_trip_fare,
      );
      expect(sumInr(records.map((row) => row.rider_share))).toBe(
        body.summary.total_rider_share,
      );
      expect(sumInr(records.map((row) => row.gst_amount ?? '0.00'))).toBe(
        body.summary.total_gst,
      );
      expect(sumInr(records.map((row) => row.company_profit ?? '0.00'))).toBe(
        body.summary.total_company_profit,
      );
    }
  });

  it('keeps the date-wise group totals equal to the summary totals', async () => {
    const body = await fetchReport({ limit: 200 });
    expect(body.group_by).toBe('day');
    const groups = body.groups as Record<string, string>[];
    expect(sumInr(groups.map((group) => group.trip_fare))).toBe(
      body.summary.total_trip_fare,
    );
    expect(sumInr(groups.map((group) => group.gst_amount))).toBe(
      body.summary.total_gst,
    );
    expect(sumInr(groups.map((group) => group.company_profit))).toBe(
      body.summary.total_company_profit,
    );
    expect(groups.map((group) => group.period)).toContain(
      localDateOf(new Date(), REPORT_TIME_ZONE),
    );
  });

  it('groups by month when asked, without changing the totals', async () => {
    const daily = await fetchReport({ limit: 200 });
    const monthly = await fetchReport({ group_by: 'month', limit: 200 });
    expect(monthly.group_by).toBe('month');
    expect(monthly.summary.total_gst).toBe(daily.summary.total_gst);
    expect(monthly.groups[0].period).toMatch(/^\d{4}-\d{2}$/);
  });

  it('excludes today orders from a past date range', async () => {
    const yesterday = await fetchReport({ preset: 'yesterday', limit: 200 });
    expect(mine(yesterday.records)).toHaveLength(0);

    const oldRange = await fetchReport({
      preset: 'custom',
      from: '2020-01-01',
      to: '2020-01-31',
      limit: 200,
    });
    expect(oldRange.summary.order_count).toBe(0);
    expect(oldRange.summary.total_gst).toBe('0.00');
    expect(oldRange.summary.total_trip_fare).toBe('0.00');
    expect(oldRange.records).toHaveLength(0);
  });

  it('treats both custom range boundaries as inclusive local days', async () => {
    const today = localDateOf(new Date(), REPORT_TIME_ZONE);
    const singleDay = await fetchReport({
      preset: 'custom',
      from: today,
      to: today,
      limit: 200,
    });
    expect(mine(singleDay.records)).toHaveLength(frozen.length);
    expect(singleDay.period.from_date).toBe(today);
    expect(singleDay.period.to_date).toBe(today);

    // A range that ends the day before must exclude the same orders.
    const endedYesterday = await fetchReport({
      preset: 'custom',
      from: '2020-01-01',
      to: yesterdayLocal(),
      limit: 200,
    });
    expect(mine(endedYesterday.records)).toHaveLength(0);
  });

  function yesterdayLocal(): string {
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
    return localDateOf(yesterday, REPORT_TIME_ZONE);
  }

  it('rejects an inverted custom range and an incomplete one', async () => {
    const inverted = await request(app.getHttpServer())
      .get('/v1/admin/reports/gst')
      .query({ preset: 'custom', from: '2026-08-31', to: '2026-08-01' })
      .set(adminAuth());
    expect(inverted.status).toBe(422);
    expect(inverted.body.error.code).toBe('REPORT_RANGE_INVALID');

    const incomplete = await request(app.getHttpServer())
      .get('/v1/admin/reports/gst')
      .query({ preset: 'custom', from: '2026-08-01' })
      .set(adminAuth());
    expect(incomplete.status).toBe(422);
    expect(incomplete.body.error.code).toBe('REPORT_RANGE_INVALID');
  });

  it('omits cancelled orders because they never receive a finance freeze', async () => {
    const token = customer.tokens.accessToken;
    const created = await request(app.getHttpServer())
      .post('/v1/orders')
      .set(bearer(token))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({
        city_id: catalog.cityId,
        vehicle_category_id: catalog.vehicleCategoryId,
        stops: sampleStops(catalog.zoneId),
      })
      .expect(201);
    await request(app.getHttpServer())
      .post(`/v1/admin/orders/${created.body.order_id}/cancel`)
      .set(adminAuth())
      .send({})
      .expect(200);

    const body = await fetchReport({ limit: 200 });
    const found = body.records.filter(
      (row: { order_id: string }) => row.order_id === created.body.order_id,
    );
    expect(found).toHaveLength(0);
  });

  it('does not treat a COD collection as a second revenue event', async () => {
    const target = frozen[1];
    const before = await fetchReport({ order_id: target.orderId, limit: 200 });
    const commissionBefore = before.summary.total_company_commission;
    const gstBefore = before.summary.total_gst;
    const profitBefore = before.summary.total_company_profit;

    await setCustomerBill(target, { cash: target.netPayable, online: '0.00' });
    await collectCash(target, target.netPayable);

    const after = await fetchReport({ order_id: target.orderId, limit: 200 });
    // Same single order, same allocation. Collection added no revenue.
    expect(after.summary.order_count).toBe(1);
    expect(after.summary.total_company_commission).toBe(commissionBefore);
    expect(after.summary.total_gst).toBe(gstBefore);
    expect(after.summary.total_company_profit).toBe(profitBefore);

    const record = recordFor(after, target.orderId);
    expect(record.payment_status).toBe('PAID');

    // The cash really was collected, as a settled transaction.
    const collected = await postgres.query<{ paid: string }>(
      `
      SELECT COALESCE(SUM(amount), 0)::text AS paid
      FROM payment_transactions
      WHERE order_id = $1 AND direction = 'CHARGE' AND transaction_status = 'PAID'
      `,
      [target.orderId],
    );
    expect(collected.rows[0].paid).toBe(target.netPayable);

    // Revenue still comes only from the finance snapshot, never from the
    // payment, wallet or COD tables.
    const snapshot = await postgres.query<{
      trip_fare: string;
      rider_amount: string;
      company_commission_amount: string;
    }>(
      `
      SELECT
        trip_fare::text AS trip_fare,
        rider_amount::text AS rider_amount,
        company_commission_amount::text AS company_commission_amount
      FROM order_finance_snapshots
      WHERE order_id = $1 AND snapshot_kind = 'ORIGINAL'
      `,
      [target.orderId],
    );
    expect(after.summary.total_trip_fare).toBe(snapshot.rows[0].trip_fare);
    expect(after.summary.total_rider_share).toBe(snapshot.rows[0].rider_amount);
    expect(after.summary.total_company_commission).toBe(
      snapshot.rows[0].company_commission_amount,
    );
  });

  it('reports the full commission on a partially collected order', async () => {
    const target = frozen[2];
    await setCustomerBill(target, { cash: target.netPayable, online: '0.00' });
    await collectCash(target, await halfOf(target.netPayable));

    const body = await fetchReport({ order_id: target.orderId, limit: 200 });
    const record = recordFor(body, target.orderId);
    expect(record.payment_status).toBe('PARTIALLY_PAID');
    // Half collected, but the company earned the whole commission.
    expect(sumInr([record.rider_share, record.company_commission])).toBe(
      record.trip_fare,
    );
    expect(body.summary.total_company_commission).toBe(record.company_commission);
  });

  it('filters by derived payment status without changing any allocation', async () => {
    const paid = await fetchReport({ payment_status: 'PAID', limit: 200 });
    for (const record of paid.records as Record<string, string>[]) {
      expect(record.payment_status).toBe('PAID');
      expect(sumInr([record.rider_share, record.company_commission])).toBe(
        record.trip_fare,
      );
    }

    const partial = await fetchReport({
      payment_status: 'PARTIALLY_PAID',
      limit: 200,
    });
    for (const record of partial.records as Record<string, string>[]) {
      expect(record.payment_status).toBe('PARTIALLY_PAID');
    }

    const unpaid = await fetchReport({ payment_status: 'UNPAID', limit: 200 });
    for (const record of unpaid.records as Record<string, string>[]) {
      expect(record.payment_status).toBe('UNPAID');
    }
    // Every order falls in exactly one bucket.
    expect(
      paid.summary.order_count +
        partial.summary.order_count +
        unpaid.summary.order_count,
    ).toBe((await fetchReport({ limit: 200 })).summary.order_count);
  });

  it('filters by payment method through settled transactions', async () => {
    const cash = await fetchReport({ payment_method: 'CASH', limit: 200 });
    const cashIds = cash.records.map((row: { order_id: string }) => row.order_id);
    expect(cashIds).toContain(frozen[1].orderId);

    const online = await fetchReport({ payment_method: 'ONLINE', limit: 200 });
    const onlineIds = online.records.map(
      (row: { order_id: string }) => row.order_id,
    );
    // Nothing here settled online, so the cash order must not appear.
    expect(onlineIds).not.toContain(frozen[1].orderId);
  });

  it('filters by city, vehicle category and order status', async () => {
    const matching = await fetchReport({ city_id: catalog.cityId, limit: 200 });
    expect(mine(matching.records)).toHaveLength(frozen.length);

    const otherCity = await fetchReport({
      city_id: catalog.secondCityId,
      limit: 200,
    });
    expect(mine(otherCity.records)).toHaveLength(0);

    const byCategory = await fetchReport({
      vehicle_category_id: catalog.vehicleCategoryId,
      limit: 200,
    });
    expect(mine(byCategory.records)).toHaveLength(frozen.length);

    const delivered = await fetchReport({
      order_status: 'DELIVERED',
      limit: 200,
    });
    for (const record of delivered.records as Record<string, string>[]) {
      expect(record.order_status).toBe('DELIVERED');
    }
  });

  it('filters by display id and paginates without changing the totals', async () => {
    const byDisplay = await fetchReport({ display_id: frozen[0].displayId });
    expect(byDisplay.summary.order_count).toBe(1);
    expect(byDisplay.records[0].display_id).toBe(frozen[0].displayId);

    const page = await fetchReport({ limit: 1, offset: 0 });
    expect(page.records).toHaveLength(1);
    expect(page.page.limit).toBe(1);
    // Totals describe the whole filter, not the page.
    expect(page.page.total).toBe(page.summary.order_count);
    expect(page.summary.order_count).toBeGreaterThanOrEqual(frozen.length);

    const second = await fetchReport({ limit: 1, offset: 1 });
    expect(second.records[0].order_id).not.toBe(page.records[0].order_id);
    expect(second.summary.total_gst).toBe(page.summary.total_gst);
  });

  it('keeps historical reports unchanged after the GST rate changes', async () => {
    const before = await fetchReport({ order_id: frozen[0].orderId, limit: 200 });
    const recordBefore = recordFor(before, frozen[0].orderId);
    expect(recordBefore.gst_rate).toBe('18.00');
    expect(recordBefore.tax_frozen).toBe(true);

    const published = await request(app.getHttpServer())
      .post('/v1/admin/tax-config')
      .set(adminAuth())
      .send({
        gst_rate: '5.00',
        gst_calculation_basis: 'EXCLUSIVE',
        notes: 'e2e historical stability check',
      });
    expect(published.status).toBe(201);
    expect(published.body.tax_config.gst_rate).toBe('5.00');

    const after = await fetchReport({ order_id: frozen[0].orderId, limit: 200 });
    const recordAfter = recordFor(after, frozen[0].orderId);

    // The historical record keeps its own rate, basis and amounts.
    expect(recordAfter.gst_rate).toBe(recordBefore.gst_rate);
    expect(recordAfter.gst_basis).toBe(recordBefore.gst_basis);
    expect(recordAfter.gst_amount).toBe(recordBefore.gst_amount);
    expect(recordAfter.taxable_company_amount).toBe(
      recordBefore.taxable_company_amount,
    );
    expect(recordAfter.company_profit).toBe(recordBefore.company_profit);
    expect(after.summary.total_gst).toBe(before.summary.total_gst);
    expect(after.summary.total_company_profit).toBe(
      before.summary.total_company_profit,
    );

    // The new rate is active, and only new freezes pick it up.
    expect(after.active_tax_config.gst_rate).toBe('5.00');
    const fresh = await createFrozenOrder();
    const freshBody = await fetchReport({ order_id: fresh.orderId, limit: 200 });
    const freshRecord = recordFor(freshBody, fresh.orderId);
    expect(freshRecord.gst_rate).toBe('5.00');
    if (freshRecord.company_commission === '15.00') {
      expect(freshRecord.gst_amount).toBe('0.75');
    }

    // Both rates coexist in one period and are reported separately.
    const period = await fetchReport({ limit: 200 });
    const rates = (period.gst_rates_applied as { gst_rate: string }[]).map(
      (row) => row.gst_rate,
    );
    expect(rates).toContain('18.00');
    expect(rates).toContain('5.00');
  });

  it('supersedes the previous version instead of editing it', async () => {
    const versions = await postgres.query<{
      version: number;
      status: string;
      gst_rate: string;
      effective_until: Date | null;
    }>(
      `
      SELECT version, status, gst_rate::text AS gst_rate, effective_until
      FROM tax_config_versions
      ORDER BY version
      `,
    );
    expect(versions.rows.length).toBeGreaterThanOrEqual(2);
    const active = versions.rows.filter((row) => row.status === 'ACTIVE');
    expect(active).toHaveLength(1);
    for (const row of versions.rows) {
      if (row.status === 'SUPERSEDED') {
        expect(row.effective_until).not.toBeNull();
      }
    }

    // The published row itself is immutable.
    await expect(
      postgres.query(
        `UPDATE tax_config_versions SET gst_rate = 1 WHERE status = 'ACTIVE'`,
      ),
    ).rejects.toThrow();
  });

  it('refuses to backdate a GST configuration', async () => {
    const response = await request(app.getHttpServer())
      .post('/v1/admin/tax-config')
      .set(adminAuth())
      .send({
        gst_rate: '12.00',
        gst_calculation_basis: 'EXCLUSIVE',
        effective_from: '2020-01-01T00:00:00.000Z',
      });
    expect(response.status).toBe(422);
    expect(response.body.error.code).toBe('TAX_CONFIG_INVALID');
  });

  it('requires the NONE basis for a zero rate so reports state it explicitly', async () => {
    const response = await request(app.getHttpServer())
      .post('/v1/admin/tax-config')
      .set(adminAuth())
      .send({ gst_rate: '0.00', gst_calculation_basis: 'EXCLUSIVE' });
    expect(response.status).toBe(422);
    expect(response.body.error.code).toBe('TAX_CONFIG_INVALID');

    const nonZeroNone = await request(app.getHttpServer())
      .post('/v1/admin/tax-config')
      .set(adminAuth())
      .send({ gst_rate: '18.00', gst_calculation_basis: 'NONE' });
    expect(nonZeroNone.status).toBe(422);
  });

  it('exports an Excel file that matches exactly the selected filters', async () => {
    const filtered = await fetchReport({ order_id: frozen[0].orderId, limit: 200 });
    expect(filtered.summary.order_count).toBe(1);

    const response = await request(app.getHttpServer())
      .get('/v1/admin/reports/gst/export')
      .query({ preset: 'today', order_id: frozen[0].orderId })
      .set(adminAuth())
      .responseType('blob');
    expect(response.status).toBe(200);
    expect(response.headers['content-type']).toContain('spreadsheetml.sheet');
    expect(response.headers['content-disposition']).toContain('.xlsx');

    const workbook = new Workbook();
    await workbook.xlsx.load(response.body);
    expect(workbook.worksheets.map((sheet) => sheet.name)).toEqual([
      'Summary',
      'Transactions',
    ]);

    const transactions = workbook.getWorksheet('Transactions')!;
    // Header row plus exactly the one matching record.
    expect(transactions.rowCount).toBe(2);

    const header = transactions.getRow(1).values as unknown[];
    const dataRow = transactions.getRow(2).values as unknown[];
    const cell = (name: string) => dataRow[header.indexOf(name)];
    const record = recordFor(filtered, frozen[0].orderId);

    expect(String(cell('Display ID'))).toBe(frozen[0].displayId);
    expect(String(cell('Order ID'))).toBe(frozen[0].orderId);
    expect(Number(cell('Trip Fare')).toFixed(2)).toBe(record.trip_fare);
    expect(Number(cell('Rider Share Amount')).toFixed(2)).toBe(record.rider_share);
    expect(Number(cell('Company Commission Amount')).toFixed(2)).toBe(
      record.company_commission,
    );
    expect(Number(cell('GST Rate')).toFixed(2)).toBe(record.gst_rate);
    expect(String(cell('GST Calculation Basis'))).toBe(record.gst_basis);
    expect(Number(cell('GST Amount')).toFixed(2)).toBe(record.gst_amount);
    expect(Number(cell('Operational Cost Amount')).toFixed(2)).toBe(
      record.operational_cost,
    );
    expect(Number(cell('Company Profit')).toFixed(2)).toBe(record.company_profit);
    expect(String(cell('Payment Status'))).toBe(record.payment_status);

    const summaryText = JSON.stringify(
      workbook.getWorksheet('Summary')!.getSheetValues(),
    );
    expect(summaryText).toContain('Total GST');
    expect(summaryText).toContain('Total Company Profit');
    expect(summaryText).toContain(REPORT_TIME_ZONE);
    // The applied filter is echoed so the file is self-describing.
    expect(summaryText).toContain('order_id');
    expect(summaryText).toContain(frozen[0].orderId);
  });

  it('exports the whole filtered set rather than the on-screen page', async () => {
    const page = await fetchReport({ limit: 1 });
    const workbook = await fetchWorkbook();
    const transactions = workbook.getWorksheet('Transactions')!;
    expect(page.records).toHaveLength(1);
    expect(transactions.rowCount - 1).toBe(page.summary.order_count);
  });

  it('excludes a city from the export when the city filter excludes it', async () => {
    const workbook = await fetchWorkbook({ city_id: catalog.secondCityId });
    const transactions = workbook.getWorksheet('Transactions')!;
    const raw = JSON.stringify(transactions.getSheetValues());
    for (const order of frozen) {
      expect(raw).not.toContain(order.orderId);
    }
  });

  it('never exports credentials, tokens or document data', async () => {
    const workbook = await fetchWorkbook();
    const raw = JSON.stringify(
      workbook.worksheets.map((sheet) => sheet.getSheetValues()),
    );
    expect(raw).not.toMatch(/password/i);
    expect(raw).not.toMatch(/\botp\b/i);
    expect(raw).not.toMatch(/access_token/i);
    expect(raw).not.toMatch(/refresh_token/i);
    expect(raw).not.toMatch(/bank/i);
    expect(raw).not.toMatch(/ifsc/i);
    expect(raw).not.toMatch(/document/i);
    expect(raw).not.toMatch(/https?:\/\//);
  });

  it('writes financial audit rows for a report run, an export and a config change', async () => {
    await fetchReport({ order_id: frozen[0].orderId });
    const viewed = await postgres.query<{ n: string }>(
      `
      SELECT count(*)::text AS n
      FROM audit_logs
      WHERE action = 'GST_REPORT_VIEWED'
        AND category = 'FINANCIAL'
        AND entity_type = 'GST_REPORT_RUN'
        AND actor_profile_id = $1
      `,
      [admin.profileId],
    );
    expect(Number(viewed.rows[0].n)).toBeGreaterThan(0);

    await fetchWorkbook({ order_id: frozen[0].orderId });
    const exported = await postgres.query<{ n: string }>(
      `
      SELECT count(*)::text AS n
      FROM audit_logs
      WHERE action = 'GST_REPORT_EXPORTED'
        AND category = 'FINANCIAL'
        AND actor_profile_id = $1
      `,
      [admin.profileId],
    );
    expect(Number(exported.rows[0].n)).toBeGreaterThan(0);

    const config = await postgres.query<{ n: string }>(
      `
      SELECT count(*)::text AS n
      FROM audit_logs
      WHERE action = 'TAX_CONFIG_PUBLISHED'
        AND entity_type = 'TAX_CONFIG_VERSION'
      `,
    );
    expect(Number(config.rows[0].n)).toBeGreaterThan(0);
  });

  it('records the report parameters in the audit row without secrets', async () => {
    await fetchReport({ order_id: frozen[0].orderId });
    const row = await postgres.query<{ new_value: Record<string, unknown> }>(
      `
      SELECT new_value
      FROM audit_logs
      WHERE action = 'GST_REPORT_VIEWED'
      ORDER BY created_at DESC
      LIMIT 1
      `,
    );
    const logged = row.rows[0].new_value;
    expect(logged.report_type).toBe('GST_TRIP_COMMISSION');
    expect(logged.date_basis).toBe('FINANCE_FREEZE');
    expect(logged.time_zone).toBe(REPORT_TIME_ZONE);
    expect(logged.from_date).toBe(localDateOf(new Date(), REPORT_TIME_ZONE));

    const raw = JSON.stringify(logged);
    expect(raw).not.toMatch(/password/i);
    expect(raw).not.toMatch(/token/i);
  });

  it('denies the report and the export to an admin without finance access', async () => {
    const restricted = await issueAdminSession(app, {
      role: 'SUPPORT',
      financeAccess: false,
    });
    const report = await request(app.getHttpServer())
      .get('/v1/admin/reports/gst')
      .query({ preset: 'today' })
      .set(bearer(restricted.tokens.accessToken));
    expect(report.status).toBe(403);
    expect(report.body.error.code).toBe('FORBIDDEN');

    const exported = await request(app.getHttpServer())
      .get('/v1/admin/reports/gst/export')
      .query({ preset: 'today' })
      .set(bearer(restricted.tokens.accessToken));
    expect(exported.status).toBe(403);
  });

  it('denies the report to customers and to unauthenticated callers', async () => {
    const asCustomer = await request(app.getHttpServer())
      .get('/v1/admin/reports/gst')
      .query({ preset: 'today' })
      .set(bearer(customer.tokens.accessToken));
    expect(asCustomer.status).toBe(403);

    const anonymous = await request(app.getHttpServer())
      .get('/v1/admin/reports/gst')
      .query({ preset: 'today' });
    expect(anonymous.status).toBe(401);

    const anonymousExport = await request(app.getHttpServer())
      .get('/v1/admin/reports/gst/export')
      .query({ preset: 'today' });
    expect(anonymousExport.status).toBe(401);
  });

  it('denies GST configuration writes to a non-finance admin role', async () => {
    const operations = await issueAdminSession(app, { role: 'OPERATIONS' });
    const response = await request(app.getHttpServer())
      .post('/v1/admin/tax-config')
      .set(bearer(operations.tokens.accessToken))
      .send({ gst_rate: '9.00', gst_calculation_basis: 'EXCLUSIVE' });
    expect(response.status).toBe(403);

    const read = await request(app.getHttpServer())
      .get('/v1/admin/tax-config')
      .set(bearer(operations.tokens.accessToken));
    expect(read.status).toBe(200);
  });

  it('leaves GST on the customer fare at zero', async () => {
    const fare = await postgres.query<{ tax: string }>(
      `SELECT tax::text AS tax FROM order_fare_snapshots WHERE order_id = $1`,
      [frozen[0].orderId],
    );
    expect(fare.rows[0].tax).toBe('0.00');

    // The tax snapshot taxes the commission only, never the fare.
    const applies = await postgres.query<{ applies_to: string }>(
      `
      SELECT DISTINCT v.applies_to
      FROM order_tax_snapshots t
      JOIN tax_config_versions v ON v.tax_config_version_id = t.tax_config_version_id
      `,
    );
    expect(applies.rows.map((row) => row.applies_to)).toEqual([
      'COMPANY_COMMISSION',
    ]);
  });

  it('rejects an unknown query parameter instead of ignoring it', async () => {
    const response = await request(app.getHttpServer())
      .get('/v1/admin/reports/gst')
      .query({ preset: 'today', gst_rate: '1.00' })
      .set(adminAuth());
    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');

    const badPreset = await request(app.getHttpServer())
      .get('/v1/admin/reports/gst')
      .query({ preset: 'last_decade' })
      .set(adminAuth());
    expect(badPreset.status).toBe(400);
  });
});
