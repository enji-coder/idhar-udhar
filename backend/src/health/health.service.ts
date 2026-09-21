import { Injectable } from '@nestjs/common';
import { AppLogger } from '../common/logger/app-logger';
import { PostgresService } from '../database/postgres.service';
import { RedisService } from '../redis/redis.service';

export type HealthStatus = 'ok' | 'degraded';

export type HealthReport = {
  status: HealthStatus;
  service: string;
  checks: {
    process: 'ok';
    database: 'ok' | 'unavailable';
    redis?: 'ok' | 'unavailable';
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
    private readonly redis: RedisService,
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
    if (!this.redis.enabled) {
      return db;
    }
    const redisOk = await this.redis.ping();
    if (!redisOk) {
      this.logger.error('health_redis_failed', {});
      return {
        status: 'degraded',
        service: 'idhar-udhar-api',
        checks: { ...db.checks, redis: 'unavailable' },
        database: db.database,
      };
    }
    return {
      ...db,
      status: db.status === 'ok' ? 'ok' : 'degraded',
      checks: { ...db.checks, redis: 'ok' },
    };
  }
}
