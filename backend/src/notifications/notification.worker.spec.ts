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
    getOrThrow: () => ({
      workerEnabled: false,
      pollMs: 5000,
      batchSize: 20,
      maxAttempts: 5,
      retryBackoffSeconds: 2,
      pushProvider: 'fcm',
    }),
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
});
