import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppLogger } from '../common/logger/app-logger';
import { AppConfig } from '../config/configuration';
import { WalletCodService } from './wallet-cod.service';

/**
 * Polls PROCESSING withdrawals that already have a merchant_transfer_id and
 * asks Cashfree for authoritative status. Never refunds on transport errors.
 */
@Injectable()
export class WithdrawalReconcileWorkerService
  implements OnModuleInit, OnModuleDestroy
{
  private timer: NodeJS.Timeout | null = null;
  private running = false;

  constructor(
    private readonly config: ConfigService,
    private readonly walletCod: WalletCodService,
    private readonly logger: AppLogger,
  ) {}

  onModuleInit(): void {
    const reconcile =
      this.config.getOrThrow<AppConfig['payment']>('payment').payoutReconcile;
    if (!reconcile.workerEnabled) {
      this.logger.info('payout_reconcile_worker_disabled', {
        reason: 'PAYOUT_RECONCILE_WORKER_ENABLED is false',
      });
      return;
    }
    this.timer = setInterval(() => {
      void this.tick();
    }, reconcile.pollMs);
    this.logger.info('payout_reconcile_worker_started', {
      poll_ms: reconcile.pollMs,
      min_age_seconds: reconcile.minAgeSeconds,
      batch_size: reconcile.batchSize,
    });
  }

  onModuleDestroy(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  async processBatch(): Promise<{
    claimed: number;
    applied: number;
    requires_review: number;
  }> {
    return this.walletCod.reconcileDueWithdrawals();
  }

  private async tick(): Promise<void> {
    if (this.running) {
      return;
    }
    this.running = true;
    try {
      const stats = await this.processBatch();
      if (stats.claimed > 0) {
        this.logger.info('payout_reconcile_cycle', stats);
      }
    } catch (err) {
      this.logger.warn('payout_reconcile_cycle_failed', {
        error: err instanceof Error ? err.message : 'unknown',
      });
    } finally {
      this.running = false;
    }
  }
}
