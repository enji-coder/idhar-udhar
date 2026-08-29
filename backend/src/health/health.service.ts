import { Injectable } from '@nestjs/common';
import { AppLogger } from '../common/logger/app-logger';
import { PostgresService } from '../database/postgres.service';

export type HealthStatus = 'ok' | 'degraded';

export type HealthReport = {
  status: HealthStatus;
  service: string;
  checks: {
    process: 'ok';
    database: 'ok' | 'unavailable';
  };
  database?: {
    name: string;
    version: string;
  };
};

@Injectable()
export class HealthService {
  constructor(
    private readonly postgres: PostgresService,
    private readonly logger: AppLogger,
  ) {}

  live(): Pick<HealthReport, 'status' | 'service' | 'checks'> {
    return {
      status: 'ok',
      service: 'idhar-udhar-api',
      checks: { process: 'ok', database: 'ok' },
    };
  }

  async database(): Promise<HealthReport> {
    try {
      const ping = await this.postgres.ping();
      return {
        status: 'ok',
        service: 'idhar-udhar-api',
        checks: { process: 'ok', database: 'ok' },
        database: { name: ping.database, version: ping.version },
      };
    } catch (err) {
      this.logger.error('health_database_failed', {
        err: err instanceof Error ? err.message : 'unknown',
      });
      return {
        status: 'degraded',
        service: 'idhar-udhar-api',
        checks: { process: 'ok', database: 'unavailable' },
      };
    }
  }

  async overall(): Promise<HealthReport> {
    const db = await this.database();
    return db;
  }
}
