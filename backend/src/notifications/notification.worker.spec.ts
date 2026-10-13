import { ConfigService } from '@nestjs/config';
import { AppLogger } from '../common/logger/app-logger';
import { PostgresService } from '../database/postgres.service';
import { NotificationsRepository } from './notifications.repository';
import { NotificationWorkerService } from './notification.worker';
import { PushProvider } from './push-provider';

describe('NotificationWorkerService FCM retry semantics', () => {
  const repo = {
    claimPendingDelivery: jest.fn(),
    completeDelivery: jest.fn(),
    findPendingOfferPushFacts: jest.fn(),
  };
  const push: PushProvider = {
    mode: 'fcm',
    send: jest.fn(),
  };
  const logger = {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
  } as unknown as AppLogger;
  const postgres = {
    transaction: jest.fn(async (work: (tx: object) => Promise<unknown>) =>
      work({}),
    ),
  };
  const config = {
    getOrThrow: (key: string) => {
      if (key === 'dispatch') {
        return { offerTtlSeconds: 30 };
      }
      return {
        workerEnabled: false,
        pollMs: 5000,
        batchSize: 20,
        maxAttempts: 5,
        retryBackoffSeconds: 2,
        pushProvider: 'fcm',
      };
    },
  };

  const worker = new NotificationWorkerService(
    postgres as unknown as PostgresService,
    repo as unknown as NotificationsRepository,
    logger,
    config as unknown as ConfigService,
    push,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    repo.completeDelivery.mockResolvedValue({});
  });

  it('marks permanent FCM token failures FAILED without exhausting retries', async () => {
    repo.claimPendingDelivery.mockResolvedValue({
      notification_delivery_id: 'd1',
      notification_id: 'n1',
      channel: 'PUSH',
      status: 'PENDING',
      attempt_count: 1,
      last_attempt_at: new Date(),
      last_error: null,
      provider_message_id: null,
      created_at: new Date(),
      recipient_identity_id: 'i1',
      recipient_profile_type: 'CUSTOMER',
      type: 'ORDER_CONFIRMED',
      title: 'Order confirmed',
      body: 'body',
      order_id: null,
      rider_profile_id: null,
    });
    (push.send as jest.Mock).mockResolvedValue({
      ok: false,
      error: 'fcm:all-tokens-unregistered',
      retryable: false,
    });
    const stats = await worker.processBatch(1);
    expect(stats.failed).toBe(1);
    expect(stats.retried).toBe(0);
    expect(repo.completeDelivery).toHaveBeenCalledWith(
      expect.objectContaining({
        deliveryId: 'd1',
        status: 'FAILED',
        lastError: 'fcm:all-tokens-unregistered',
      }),
      {},
    );
  });

  it('keeps PENDING on transient FCM failures before the attempt ceiling', async () => {
    repo.claimPendingDelivery.mockResolvedValue({
      notification_delivery_id: 'd1',
      notification_id: 'n1',
      channel: 'PUSH',
      status: 'PENDING',
      attempt_count: 1,
      last_attempt_at: new Date(),
      last_error: null,
      provider_message_id: null,
      created_at: new Date(),
      recipient_identity_id: 'i1',
      recipient_profile_type: 'CUSTOMER',
      type: 'ORDER_CONFIRMED',
      title: 'Order confirmed',
      body: 'body',
      order_id: null,
      rider_profile_id: null,
    });
    (push.send as jest.Mock).mockResolvedValue({
      ok: false,
      error: 'fcm:unavailable',
      retryable: true,
    });
    const stats = await worker.processBatch(1);
    expect(stats.retried).toBe(1);
    expect(repo.completeDelivery).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'PENDING', lastError: 'fcm:unavailable' }),
      {},
    );
  });

  it('does not send an OFFER_NEW the phone cannot display', async () => {
    repo.claimPendingDelivery.mockResolvedValue({
      notification_delivery_id: 'd1',
      notification_id: 'n1',
      channel: 'PUSH',
      status: 'PENDING',
      attempt_count: 1,
      last_attempt_at: new Date(),
      last_error: null,
      provider_message_id: null,
      created_at: new Date(),
      recipient_identity_id: 'i1',
      recipient_profile_type: 'RIDER',
      type: 'OFFER_NEW',
      title: 'New delivery request',
      body: 'You have a new delivery request.',
      order_id: 'order-1',
      rider_profile_id: null,
    });
    const stats = await worker.processBatch(1);
    expect(stats.failed).toBe(1);
    expect(push.send).not.toHaveBeenCalled();
    expect(repo.completeDelivery).toHaveBeenCalledWith(
      expect.objectContaining({
        status: 'FAILED',
        lastError: 'offer_facts_missing',
      }),
      {},
    );
  });

  it('sends OFFER_NEW with the pending offer payload', async () => {
    repo.claimPendingDelivery.mockResolvedValue({
      notification_delivery_id: 'd1',
      notification_id: 'n1',
      channel: 'PUSH',
      status: 'PENDING',
      attempt_count: 1,
      last_attempt_at: new Date(),
      last_error: null,
      provider_message_id: null,
      created_at: new Date(),
      recipient_identity_id: 'i1',
      recipient_profile_type: 'RIDER',
      type: 'OFFER_NEW',
      title: 'New delivery request',
      body: 'You have a new delivery request.',
      order_id: 'order-1',
      rider_profile_id: 'rider-1',
    });
    repo.findPendingOfferPushFacts.mockResolvedValue({
      offer_id: 'offer-1',
      expires_at: '2026-10-13T07:00:30.000Z',
      trip_fare: '500.00',
      pickup_address: 'CG Road',
      drop_address: 'Navrangpura',
    });
    (push.send as jest.Mock).mockResolvedValue({ ok: true, providerMessageId: 'm1' });
    const stats = await worker.processBatch(1);
    expect(stats.sent).toBe(1);
    expect(push.send).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'OFFER_NEW',
        data: expect.objectContaining({ offer_id: 'offer-1', trip_fare: '500.00' }),
      }),
    );
  });
});
