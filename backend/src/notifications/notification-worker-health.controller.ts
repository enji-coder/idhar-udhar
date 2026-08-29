import { Controller, Get, Header } from '@nestjs/common';
import { Public } from '../common/decorators/public.decorator';
import { NotificationWorkerService } from './notification.worker';

@Public()
@Controller()
export class NotificationWorkerHealthController {
  constructor(private readonly worker: NotificationWorkerService) {}

  @Get('health/worker')
  @Header('cache-control', 'no-store')
  async workerHealth() {
    const config = this.worker.workerConfig();
    const pending = await this.worker.pendingCount();
    const last = this.worker.lastCycleStats();
    return {
      status: 'ok',
      service: 'idhar-udhar-api',
      worker: {
        enabled: config.workerEnabled,
        pending_deliveries: pending,
        last_cycle_at: last?.at ?? null,
        last_cycle_claimed: last?.claimed ?? 0,
        last_cycle_sent: last?.sent ?? 0,
        last_cycle_failed: last?.failed ?? 0,
        last_cycle_retried: last?.retried ?? 0,
      },
    };
  }
}
