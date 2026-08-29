import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { PostgresService } from '../src/database/postgres.service';
import { CapturingPushProvider } from '../src/notifications/capturing-push.provider';
import { NotificationService } from '../src/notifications/notification.service';
import { NotificationWorkerService } from '../src/notifications/notification.worker';
import { NotificationsRepository } from '../src/notifications/notifications.repository';
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

describe('Notifications and worker (e2e)', () => {
  let app: INestApplication;
  let postgres: PostgresService;
  let notifications: NotificationService;
  let worker: NotificationWorkerService;
  let repo: NotificationsRepository;
  let push: CapturingPushProvider;
  let catalog: OrderCatalog;
  let admin: Awaited<ReturnType<typeof issueAdminSession>>;

  beforeAll(async () => {
    app = await createTestApp();
    postgres = app.get(PostgresService);
    notifications = app.get(NotificationService);
    worker = app.get(NotificationWorkerService);
    repo = app.get(NotificationsRepository);
    push = app.get(CapturingPushProvider);
    catalog = await ensureOrderCatalog(postgres);
    await ensureActivePaymentSettings(postgres);
    admin = await issueAdminSession(app);
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(() => {
    push.clear();
  });

  async function drainPending() {
    push.clear();
    for (let i = 0; i < 100; i += 1) {
      const stats = await worker.processBatch(100);
      if (stats.claimed === 0) {
        break;
      }
    }
    push.clear();
  }

  function bearer(token: string) {
    return { Authorization: `Bearer ${token}` };
  }

  async function createConfirmedOrder(
    token: string,
  ): Promise<{ orderId: string; displayId: string; netPayable: string }> {
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
      displayId: created.body.display_id as string,
      netPayable: quote.body.net_payable as string,
    };
  }

  it('creates, lists, counts unread, and marks in-app notifications as read', async () => {
    const customer = await issueCustomerSession(app);
    const created = await postgres.transaction((tx) =>
      notifications.notify(
        {
          eventKey: `test:inbox:${customer.profileId}:${Date.now()}`,
          type: 'ORDER_CONFIRMED',
          audience: 'CUSTOMER',
          recipient: {
            identityId: customer.identityId,
            profileType: 'CUSTOMER',
            profileId: customer.profileId,
          },
          displayId: 'IU-AMD-0000000001',
        },
        tx,
      ),
    );
    expect(created.created).toBe(true);
    expect(created.deliveries.map((row) => row.channel).sort()).toEqual([
      'IN_APP',
      'PUSH',
    ]);

    const listed = await request(app.getHttpServer())
      .get('/v1/notifications')
      .set(bearer(customer.tokens.accessToken));
    expect(listed.status).toBe(200);
    expect(listed.body.notifications.length).toBeGreaterThanOrEqual(1);
    expect(listed.body.notifications[0].notification_id).toBe(
      created.notification.notification_id,
    );
    expect(listed.body.notifications[0].read_at).toBeNull();

    const unread = await request(app.getHttpServer())
      .get('/v1/notifications/unread-count')
      .set(bearer(customer.tokens.accessToken));
    expect(unread.status).toBe(200);
    expect(unread.body.unread_count).toBeGreaterThanOrEqual(1);

    const read = await request(app.getHttpServer())
      .post(`/v1/notifications/${created.notification.notification_id}/read`)
      .set(bearer(customer.tokens.accessToken));
    expect(read.status).toBe(200);
    expect(read.body.read_at).toBeTruthy();

    const unreadAfter = await request(app.getHttpServer())
      .get('/v1/notifications/unread-count')
      .set(bearer(customer.tokens.accessToken));
    expect(unreadAfter.body.unread_count).toBe(unread.body.unread_count - 1);
  });

  it('ignores client-supplied identity_id and isolates customer vs rider inboxes', async () => {
    const customer = await issueCustomerSession(app);
    const rider = await issueRiderSession(app);
    await postgres.transaction(async (tx) => {
      await notifications.notify(
        {
          eventKey: `test:iso:customer:${customer.profileId}`,
          type: 'ORDER_CONFIRMED',
          audience: 'CUSTOMER',
          recipient: {
            identityId: customer.identityId,
            profileType: 'CUSTOMER',
            profileId: customer.profileId,
          },
        },
        tx,
      );
      await notifications.notify(
        {
          eventKey: `test:iso:rider:${rider.profileId}`,
          type: 'OFFER_NEW',
          audience: 'RIDER',
          recipient: {
            identityId: rider.identityId,
            profileType: 'RIDER',
            profileId: rider.profileId,
          },
        },
        tx,
      );
    });

    const leaked = await request(app.getHttpServer())
      .get(`/v1/notifications?identity_id=${rider.identityId}`)
      .set(bearer(customer.tokens.accessToken));
    expect(leaked.status).toBe(200);
    expect(
      leaked.body.notifications.every(
        (row: { recipient_profile_type: string }) =>
          row.recipient_profile_type === 'CUSTOMER',
      ),
    ).toBe(true);
    expect(
      leaked.body.notifications.some(
        (row: { type: string }) => row.type === 'OFFER_NEW',
      ),
    ).toBe(false);

    const riderList = await request(app.getHttpServer())
      .get('/v1/notifications')
      .set(bearer(rider.tokens.accessToken));
    expect(
      riderList.body.notifications.some(
        (row: { type: string }) => row.type === 'OFFER_NEW',
      ),
    ).toBe(true);

    const riderNotif = riderList.body.notifications[0];
    const forbidden = await request(app.getHttpServer())
      .post(`/v1/notifications/${riderNotif.notification_id}/read`)
      .set(bearer(customer.tokens.accessToken));
    expect(forbidden.status).toBe(404);
  });

  it('gets and updates the authenticated identity preferences only', async () => {
    const customer = await issueCustomerSession(app);
    const rider = await issueRiderSession(app);
    const initial = await request(app.getHttpServer())
      .get('/v1/notification-preferences')
      .set(bearer(customer.tokens.accessToken));
    expect(initial.status).toBe(200);
    expect(initial.body.in_app_enabled).toBe(true);
    expect(initial.body.push_enabled).toBe(true);

    const updated = await request(app.getHttpServer())
      .put('/v1/notification-preferences')
      .set(bearer(customer.tokens.accessToken))
      .send({ in_app_enabled: true, push_enabled: false });
    expect(updated.status).toBe(200);
    expect(updated.body.push_enabled).toBe(false);

    const riderPrefs = await request(app.getHttpServer())
      .get('/v1/notification-preferences')
      .set(bearer(rider.tokens.accessToken));
    expect(riderPrefs.body.push_enabled).toBe(true);
  });

  it('creates SKIPPED push deliveries when push is disabled', async () => {
    const rider = await issueRiderSession(app);
    await request(app.getHttpServer())
      .put('/v1/notification-preferences')
      .set(bearer(rider.tokens.accessToken))
      .send({ in_app_enabled: true, push_enabled: false });
    const created = await postgres.transaction((tx) =>
      notifications.notify(
        {
          eventKey: `test:skip-push:${rider.profileId}`,
          type: 'OFFER_NEW',
          audience: 'RIDER',
          recipient: {
            identityId: rider.identityId,
            profileType: 'RIDER',
            profileId: rider.profileId,
          },
        },
        tx,
      ),
    );
    const pushRow = created.deliveries.find((row) => row.channel === 'PUSH');
    const inApp = created.deliveries.find((row) => row.channel === 'IN_APP');
    expect(pushRow?.status).toBe('SKIPPED');
    expect(inApp?.status).toBe('PENDING');
  });

  it('worker marks IN_APP PENDING as SENT and PUSH capture as SENT', async () => {
    await drainPending();
    const customer = await issueCustomerSession(app);
    const created = await postgres.transaction((tx) =>
      notifications.notify(
        {
          eventKey: `test:worker-sent:${customer.profileId}`,
          type: 'ORDER_CONFIRMED',
          audience: 'CUSTOMER',
          recipient: {
            identityId: customer.identityId,
            profileType: 'CUSTOMER',
            profileId: customer.profileId,
          },
        },
        tx,
      ),
    );
    const stats = await worker.processBatch(10);
    expect(stats.sent).toBeGreaterThanOrEqual(2);
    const inApp = await repo.findDelivery(created.notification.notification_id, 'IN_APP');
    const pushRow = await repo.findDelivery(created.notification.notification_id, 'PUSH');
    expect(inApp?.status).toBe('SENT');
    expect(pushRow?.status).toBe('SENT');
    expect(pushRow?.provider_message_id).toMatch(/^capture:/);
    expect(push.peek().length).toBeGreaterThanOrEqual(1);
  });

  it('increments attempt_count, stores last_error, retries, then marks FAILED', async () => {
    await drainPending();
    const customer = await issueCustomerSession(app);
    const created = await postgres.transaction((tx) =>
      notifications.notify(
        {
          eventKey: `test:worker-fail:${customer.profileId}`,
          type: 'ORDER_CONFIRMED',
          audience: 'CUSTOMER',
          recipient: {
            identityId: customer.identityId,
            profileType: 'CUSTOMER',
            profileId: customer.profileId,
          },
        },
        tx,
      ),
    );
    await postgres.query(
      `
      UPDATE notification_deliveries
      SET status = 'SKIPPED'
      WHERE notification_id = $1 AND channel = 'IN_APP'
      `,
      [created.notification.notification_id],
    );
    push.failNext(2);
    await worker.processBatch(1);
    const afterFirst = await repo.findDelivery(
      created.notification.notification_id,
      'PUSH',
    );
    expect(afterFirst?.status).toBe('PENDING');
    expect(afterFirst?.attempt_count).toBe(1);
    expect(afterFirst?.last_error).toBe('captured push failure');

    await worker.processBatch(1);
    const afterSecond = await repo.findDelivery(
      created.notification.notification_id,
      'PUSH',
    );
    expect(afterSecond?.status).toBe('PENDING');
    expect(afterSecond?.attempt_count).toBe(2);

    push.failNext(1);
    await worker.processBatch(1);
    const afterThird = await repo.findDelivery(
      created.notification.notification_id,
      'PUSH',
    );
    expect(afterThird?.status).toBe('FAILED');
    expect(afterThird?.attempt_count).toBe(3);
    expect(afterThird?.last_error).toBe('captured push failure');
  });

  it('does not let two workers process the same delivery', async () => {
    await drainPending();
    const customer = await issueCustomerSession(app);
    const created = await postgres.transaction((tx) =>
      notifications.notify(
        {
          eventKey: `test:worker-race:${customer.profileId}`,
          type: 'ORDER_CONFIRMED',
          audience: 'CUSTOMER',
          recipient: {
            identityId: customer.identityId,
            profileType: 'CUSTOMER',
            profileId: customer.profileId,
          },
        },
        tx,
      ),
    );
    await postgres.query(
      `
      UPDATE notification_deliveries
      SET status = 'SKIPPED'
      WHERE notification_id = $1 AND channel = 'IN_APP'
      `,
      [created.notification.notification_id],
    );
    const [left, right] = await Promise.all([
      worker.processBatch(1),
      worker.processBatch(1),
    ]);
    const claimed = left.claimed + right.claimed;
    expect(claimed).toBe(1);
    const pushRow = await repo.findDelivery(
      created.notification.notification_id,
      'PUSH',
    );
    expect(pushRow?.status).toBe('SENT');
    expect(pushRow?.attempt_count).toBe(1);
  });

  it('does not create a duplicate notification for the same logical event', async () => {
    const customer = await issueCustomerSession(app);
    const key = `test:idempotent:${customer.profileId}`;
    const first = await postgres.transaction((tx) =>
      notifications.notify(
        {
          eventKey: key,
          type: 'ORDER_CONFIRMED',
          audience: 'CUSTOMER',
          recipient: {
            identityId: customer.identityId,
            profileType: 'CUSTOMER',
            profileId: customer.profileId,
          },
        },
        tx,
      ),
    );
    const second = await postgres.transaction((tx) =>
      notifications.notify(
        {
          eventKey: key,
          type: 'ORDER_CONFIRMED',
          audience: 'CUSTOMER',
          recipient: {
            identityId: customer.identityId,
            profileType: 'CUSTOMER',
            profileId: customer.profileId,
          },
        },
        tx,
      ),
    );
    expect(second.created).toBe(false);
    expect(second.notification.notification_id).toBe(
      first.notification.notification_id,
    );
  });

  it('notifies customer, rider, and admin from existing order events', async () => {
    const customer = await issueCustomerSession(app);
    const rider = await issueRiderSession(app);
    const order = await createConfirmedOrder(customer.tokens.accessToken);

    const afterConfirm = await request(app.getHttpServer())
      .get('/v1/notifications')
      .set(bearer(customer.tokens.accessToken));
    expect(
      afterConfirm.body.notifications.some(
        (row: { type: string }) => row.type === 'ORDER_CONFIRMED',
      ),
    ).toBe(true);

    const offer = await request(app.getHttpServer())
      .post(`/v1/admin/orders/${order.orderId}/offers`)
      .set(bearer(admin.tokens.accessToken))
      .send({ rider_profile_id: rider.profileId });
    expect(offer.status).toBe(201);
    const riderOffers = await request(app.getHttpServer())
      .get('/v1/notifications')
      .set(bearer(rider.tokens.accessToken));
    expect(
      riderOffers.body.notifications.some(
        (row: { type: string }) => row.type === 'OFFER_NEW',
      ),
    ).toBe(true);

    const accept = await request(app.getHttpServer())
      .post(`/v1/rider/offers/${offer.body.order_offer_id}/accept`)
      .set(bearer(rider.tokens.accessToken));
    expect(accept.status).toBe(200);

    const customerAssigned = await request(app.getHttpServer())
      .get('/v1/notifications')
      .set(bearer(customer.tokens.accessToken));
    expect(
      customerAssigned.body.notifications.some(
        (row: { type: string }) => row.type === 'ORDER_RIDER_ASSIGNED',
      ),
    ).toBe(true);
    const riderAssigned = await request(app.getHttpServer())
      .get('/v1/notifications')
      .set(bearer(rider.tokens.accessToken));
    expect(
      riderAssigned.body.notifications.some(
        (row: { type: string }) => row.type === 'ORDER_ASSIGNED',
      ),
    ).toBe(true);

    const pickup = await request(app.getHttpServer())
      .post(`/v1/rider/orders/${order.orderId}/status`)
      .set(bearer(rider.tokens.accessToken))
      .send({ to_status: 'EN_ROUTE_PICKUP' });
    expect(pickup.status).toBe(200);
    const arrived = await request(app.getHttpServer())
      .post(`/v1/rider/orders/${order.orderId}/status`)
      .set(bearer(rider.tokens.accessToken))
      .send({ to_status: 'ARRIVED_PICKUP' });
    expect(arrived.status).toBe(200);
    const afterArrived = await request(app.getHttpServer())
      .get('/v1/notifications')
      .set(bearer(customer.tokens.accessToken));
    expect(
      afterArrived.body.notifications.some(
        (row: { type: string }) => row.type === 'ORDER_RIDER_REACHED_PICKUP',
      ),
    ).toBe(true);

    const cancel = await request(app.getHttpServer())
      .post(`/v1/admin/orders/${order.orderId}/cancel`)
      .set(bearer(admin.tokens.accessToken));
    expect(cancel.status).toBe(200);
    const afterCancel = await request(app.getHttpServer())
      .get('/v1/notifications')
      .set(bearer(customer.tokens.accessToken));
    expect(
      afterCancel.body.notifications.some(
        (row: { type: string }) => row.type === 'ORDER_CANCELLED',
      ),
    ).toBe(true);
    const adminInbox = await request(app.getHttpServer())
      .get('/v1/notifications')
      .set(bearer(admin.tokens.accessToken));
    expect(
      adminInbox.body.notifications.some(
        (row: { type: string; body: string }) =>
          row.type === 'ORDER_CANCELLED' && row.body.includes(order.displayId),
      ),
    ).toBe(true);
  });

  it('notifies from authoritative payment PAID, FAILED, and refund rows', async () => {
    const customer = await issueCustomerSession(app);
    const rider = await issueRiderSession(app);
    const order = await createConfirmedOrder(customer.tokens.accessToken);
    const responsibility = await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/responsibility`)
      .set(bearer(customer.tokens.accessToken))
      .send({ who_pays: 'CUSTOMER' });
    expect(responsibility.status).toBe(201);
    const plan = await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/plan`)
      .set(bearer(customer.tokens.accessToken))
      .send({
        customer_planned_online: '0.00',
        customer_planned_cash: order.netPayable,
        receiver_planned_online: '0.00',
        receiver_planned_cash: '0.00',
      });
    expect(plan.status).toBe(201);
    await request(app.getHttpServer())
      .post(`/v1/admin/orders/${order.orderId}/assign`)
      .set(bearer(admin.tokens.accessToken))
      .send({ rider_profile_id: rider.profileId });

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
    const afterPaid = await request(app.getHttpServer())
      .get('/v1/notifications')
      .set(bearer(customer.tokens.accessToken));
    expect(
      afterPaid.body.notifications.some(
        (row: { type: string }) => row.type === 'PAYMENT_SUCCESSFUL',
      ),
    ).toBe(true);

    const onlineOrder = await createConfirmedOrder(customer.tokens.accessToken);
    await request(app.getHttpServer())
      .post(`/v1/orders/${onlineOrder.orderId}/payment/responsibility`)
      .set(bearer(customer.tokens.accessToken))
      .send({ who_pays: 'CUSTOMER' });
    await request(app.getHttpServer())
      .post(`/v1/orders/${onlineOrder.orderId}/payment/plan`)
      .set(bearer(customer.tokens.accessToken))
      .send({
        customer_planned_online: onlineOrder.netPayable,
        customer_planned_cash: '0.00',
        receiver_planned_online: '0.00',
        receiver_planned_cash: '0.00',
      });
    const failed = await request(app.getHttpServer())
      .post(`/v1/orders/${onlineOrder.orderId}/payment/transactions`)
      .set(bearer(admin.tokens.accessToken))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({
        payer_type: 'CUSTOMER',
        method: 'ONLINE',
        amount: onlineOrder.netPayable,
        transaction_status: 'FAILED',
      });
    expect(failed.status).toBe(201);
    const afterFail = await request(app.getHttpServer())
      .get('/v1/notifications')
      .set(bearer(customer.tokens.accessToken));
    expect(
      afterFail.body.notifications.some(
        (row: { type: string }) => row.type === 'PAYMENT_FAILED',
      ),
    ).toBe(true);

    const refund = await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/transactions`)
      .set(bearer(admin.tokens.accessToken))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({
        payer_type: 'CUSTOMER',
        method: 'CASH',
        amount: order.netPayable,
        direction: 'REFUND',
      });
    expect(refund.status).toBe(201);
    const afterRefund = await request(app.getHttpServer())
      .get('/v1/notifications')
      .set(bearer(customer.tokens.accessToken));
    expect(
      afterRefund.body.notifications.some(
        (row: { type: string }) => row.type === 'PAYMENT_REFUND_RECORDED',
      ),
    ).toBe(true);
  });

  it('notifies wallet recharge, COD settlement, suspension, and eligibility', async () => {
    const rider = await issueRiderSession(app);
    const recharge = await request(app.getHttpServer())
      .post('/v1/rider/wallet/recharge')
      .set(bearer(rider.tokens.accessToken))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({ amount: '50.00' });
    expect(recharge.status).toBe(201);
    const afterRecharge = await request(app.getHttpServer())
      .get('/v1/notifications')
      .set(bearer(rider.tokens.accessToken));
    expect(
      afterRecharge.body.notifications.some(
        (row: { type: string }) => row.type === 'WALLET_RECHARGE_COMPLETED',
      ),
    ).toBe(true);

    const customer = await issueCustomerSession(app);
    const order = await createConfirmedOrder(customer.tokens.accessToken);
    await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/responsibility`)
      .set(bearer(customer.tokens.accessToken))
      .send({ who_pays: 'CUSTOMER' });
    await request(app.getHttpServer())
      .post(`/v1/orders/${order.orderId}/payment/plan`)
      .set(bearer(customer.tokens.accessToken))
      .send({
        customer_planned_online: '0.00',
        customer_planned_cash: order.netPayable,
        receiver_planned_online: '0.00',
        receiver_planned_cash: '0.00',
      });
    await request(app.getHttpServer())
      .post(`/v1/admin/orders/${order.orderId}/assign`)
      .set(bearer(admin.tokens.accessToken))
      .send({ rider_profile_id: rider.profileId });
    const walletRepo = app.get(WalletCodRepository);
    await postgres.transaction(async (tx) => {
      const accounts = await walletRepo.lockAccounts(rider.profileId, tx);
      await walletRepo.increaseCod(accounts.cod.cod_account_id, '90.00', tx);
      await walletRepo.insertCodLedger(
        {
          codAccountId: accounts.cod.cod_account_id,
          direction: 'INCREASE',
          amount: '90.00',
          source: 'ADMIN_ADJUSTMENT',
          sourceTxnId: `test-cod-pre:${rider.profileId}`,
        },
        tx,
      );
      await walletRepo.syncOperationalStatus(
        rider.profileId,
        '90.00',
        accounts.threshold,
        tx,
      );
    });
    const freeze = await request(app.getHttpServer())
      .post(`/v1/admin/orders/${order.orderId}/finance/freeze`)
      .set(bearer(admin.tokens.accessToken));
    expect(freeze.status).toBe(201);
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
    const afterSuspend = await request(app.getHttpServer())
      .get('/v1/notifications')
      .set(bearer(rider.tokens.accessToken));
    expect(
      afterSuspend.body.notifications.some(
        (row: { type: string }) => row.type === 'COD_SUSPENDED',
      ),
    ).toBe(true);

    const settle = await request(app.getHttpServer())
      .post('/v1/rider/cod/settle')
      .set(bearer(rider.tokens.accessToken))
      .set('Idempotency-Key', uniqueIdempotencyKey())
      .send({ amount: '100.00' });
    expect(settle.status).toBe(201);
    const afterClear = await request(app.getHttpServer())
      .get('/v1/notifications')
      .set(bearer(rider.tokens.accessToken));
    expect(
      afterClear.body.notifications.some(
        (row: { type: string }) => row.type === 'COD_SETTLEMENT_COMPLETED',
      ),
    ).toBe(true);
    expect(
      afterClear.body.notifications.some(
        (row: { type: string }) => row.type === 'COD_ELIGIBLE',
      ),
    ).toBe(true);
  });

  it('rejects unauthenticated inbox access and does not expose worker payloads', async () => {
    const denied = await request(app.getHttpServer()).get('/v1/notifications');
    expect(denied.status).toBe(401);
    const health = await request(app.getHttpServer()).get('/health/worker');
    expect(health.status).toBe(200);
    expect(health.body.worker.pending_deliveries).toBeDefined();
    expect(JSON.stringify(health.body)).not.toMatch(/password/);
    expect(JSON.stringify(health.body)).not.toMatch(/secret/);
    expect(JSON.stringify(health.body)).not.toMatch(/title/);
    expect(JSON.stringify(health.body)).not.toMatch(/body/);
  });
});
