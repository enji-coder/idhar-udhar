import { Inject, Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppLogger } from '../common/logger/app-logger';
import { AppConfig } from '../config/configuration';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';
import { NotificationsRepository } from './notifications.repository';
import { PUSH_PROVIDER, PushProvider } from './push-provider';

export type WorkerCycleStats = {
  claimed: number;
  sent: number;
  failed: number;
  retried: number;
  at: string;
};

@Injectable()
export class NotificationWorkerService implements OnModuleInit, OnModuleDestroy {
  private timer: NodeJS.Timeout | null = null;
  private running = false;
  private lastCycle: WorkerCycleStats | null = null;

  constructor(
    private readonly postgres: PostgresService,
    private readonly repo: NotificationsRepository,
    private readonly logger: AppLogger,
    private readonly configService: ConfigService,
    @Inject(PUSH_PROVIDER) private readonly push: PushProvider,
  ) {}

  onModuleInit(): void {
    const worker = this.configService.getOrThrow<AppConfig['notifications']>('notifications');
    if (!worker.workerEnabled) {
      this.logger.info('notification_worker_disabled', {
        reason: 'NOTIFICATION_WORKER_ENABLED is false',
      });
      return;
    }
    this.timer = setInterval(() => {
      void this.safeCycle();
    }, worker.pollMs);
    this.logger.info('notification_worker_started', {
      poll_ms: worker.pollMs,
      batch_size: worker.batchSize,
      max_attempts: worker.maxAttempts,
    });
  }

  onModuleDestroy(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  lastCycleStats(): WorkerCycleStats | null {
    return this.lastCycle;
  }

  workerConfig() {
    return this.configService.getOrThrow<AppConfig['notifications']>('notifications');
  }

  async pendingCount(): Promise<number> {
    return this.repo.countPending();
  }

  async processBatch(limit?: number): Promise<WorkerCycleStats> {
    const worker = this.workerConfig();
    const max = limit ?? worker.batchSize;
    const stats: WorkerCycleStats = {
      claimed: 0,
      sent: 0,
      failed: 0,
      retried: 0,
      at: new Date().toISOString(),
    };
    for (let i = 0; i < max; i += 1) {
      const result = await this.processOne();
      if (result === 'empty') {
        break;
      }
      stats.claimed += 1;
      if (result === 'sent') {
        stats.sent += 1;
      } else if (result === 'failed') {
        stats.failed += 1;
      } else {
        stats.retried += 1;
      }
    }
    this.lastCycle = stats;
    return stats;
  }

  private async safeCycle(): Promise<void> {
    if (this.running) {
      return;
    }
    this.running = true;
    try {
      await this.processBatch();
    } catch (err) {
      this.logger.error('notification_worker_cycle_failed', {
        err: err instanceof Error ? err.message : 'unknown',
      });
    } finally {
      this.running = false;
    }
  }

  private async processOne(): Promise<'empty' | 'sent' | 'failed' | 'retried'> {
    const worker = this.workerConfig();
    return this.postgres.transaction(async (tx) => {
      const claimed = await this.repo.claimPendingDelivery(
        worker.retryBackoffSeconds,
        tx,
      );
      if (!claimed) {
        return 'empty';
      }

      this.logger.info('notification_delivery_claimed', {
        delivery_id: claimed.notification_delivery_id,
        notification_id: claimed.notification_id,
        channel: claimed.channel,
        attempt: claimed.attempt_count,
      });

      try {
        if (claimed.channel === 'IN_APP') {
          await this.repo.completeDelivery(
            {
              deliveryId: claimed.notification_delivery_id,
              status: 'SENT',
              lastError: null,
              providerMessageId: null,
            },
            tx,
          );
          this.logger.info('notification_delivery_sent', {
            delivery_id: claimed.notification_delivery_id,
            notification_id: claimed.notification_id,
            channel: claimed.channel,
            attempt: claimed.attempt_count,
            result: 'SENT',
          });
          return 'sent';
        }

        const pushResult = await this.push.send({
          deliveryId: claimed.notification_delivery_id,
          notificationId: claimed.notification_id,
          identityId: claimed.recipient_identity_id,
          type: claimed.type,
          title: claimed.title ?? '',
          body: claimed.body,
          orderId: claimed.order_id,
        });
        if (pushResult.ok) {
          await this.repo.completeDelivery(
            {
              deliveryId: claimed.notification_delivery_id,
              status: 'SENT',
              lastError: null,
              providerMessageId: pushResult.providerMessageId,
            },
            tx,
          );
          this.logger.info('notification_delivery_sent', {
            delivery_id: claimed.notification_delivery_id,
            notification_id: claimed.notification_id,
            channel: claimed.channel,
            attempt: claimed.attempt_count,
            result: 'SENT',
          });
          return 'sent';
        }
        return this.failOrRetry(
          claimed.notification_delivery_id,
          claimed.notification_id,
          claimed.channel,
          claimed.attempt_count,
          pushResult.error,
          worker.maxAttempts,
          tx,
        );
      } catch (err) {
        const message = err instanceof Error ? err.message : 'unknown';
        return this.failOrRetry(
          claimed.notification_delivery_id,
          claimed.notification_id,
          claimed.channel,
          claimed.attempt_count,
          message,
          worker.maxAttempts,
          tx,
        );
      }
    });
  }

  private async failOrRetry(
    deliveryId: string,
    notificationId: string,
    channel: string,
    attempt: number,
    error: string,
    maxAttempts: number,
    tx: Queryable,
  ): Promise<'failed' | 'retried'> {
    const terminal = attempt >= maxAttempts;
    await this.repo.completeDelivery(
      {
        deliveryId,
        status: terminal ? 'FAILED' : 'PENDING',
        lastError: error.slice(0, 500),
        providerMessageId: null,
      },
      tx,
    );
    this.logger.warn(
      terminal ? 'notification_delivery_failed' : 'notification_delivery_retry',
      {
        delivery_id: deliveryId,
        notification_id: notificationId,
        channel,
        attempt,
        result: terminal ? 'FAILED' : 'PENDING',
      },
    );
    return terminal ? 'failed' : 'retried';
  }
}
