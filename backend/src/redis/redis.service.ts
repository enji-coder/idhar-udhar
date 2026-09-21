import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { AppLogger } from '../common/logger/app-logger';
import { AppConfig } from '../config/configuration';
import {
  defaultRedisClientFactory,
  RedisClient,
  RedisClientFactory,
} from './redis-client';

const UNAVAILABLE_MESSAGE = 'Location store is unavailable. Try again shortly.';

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private client: RedisClient | null = null;
  private factory: RedisClientFactory = defaultRedisClientFactory;

  constructor(
    private readonly configService: ConfigService,
    private readonly logger: AppLogger,
  ) {}

  useClientFactory(factory: RedisClientFactory): void {
    this.factory = factory;
  }

  get enabled(): boolean {
    return this.redisConfig().enabled;
  }

  get connected(): boolean {
    return this.client?.isOpen === true;
  }

  async onModuleInit(): Promise<void> {
    const redis = this.redisConfig();
    if (!redis.enabled) {
      return;
    }
    if (!redis.host) {
      throw new Error('REDIS_ENABLED=true requires REDIS_HOST');
    }
    const client = this.factory({
      host: redis.host,
      port: redis.port,
      tls: redis.tls,
    });
    client.on('error', (err) => {
      this.logger.error('redis_client_error', {
        err: err instanceof Error ? err.message : 'unknown',
      });
    });
    this.client = client;
    try {
      await client.connect();
      await client.ping();
      this.logger.info('redis_connected', {
        tls: redis.tls,
        port: redis.port,
      });
    } catch (err) {
      this.logger.error('redis_connect_failed', {
        err: err instanceof Error ? err.message : 'unknown',
        tls: redis.tls,
      });
      this.client = null;
      throw err;
    }
  }

  async onModuleDestroy(): Promise<void> {
    const client = this.client;
    this.client = null;
    if (!client) {
      return;
    }
    try {
      if (client.isOpen) {
        await client.quit();
      }
    } catch (err) {
      this.logger.error('redis_shutdown_failed', {
        err: err instanceof Error ? err.message : 'unknown',
      });
    }
  }

  async ping(): Promise<boolean> {
    if (!this.enabled) {
      return false;
    }
    try {
      await this.requireClient().ping();
      return true;
    } catch {
      return false;
    }
  }

  async set(key: string, value: string): Promise<void> {
    try {
      await this.requireClient().set(key, value);
    } catch (err) {
      if (err instanceof ApiError) {
        throw err;
      }
      this.logger.error('redis_command_failed', { command: 'set' });
      throw new ApiError(ErrorCodes.INTERNAL_ERROR, UNAVAILABLE_MESSAGE, 503);
    }
  }

  async get(key: string): Promise<string | null> {
    try {
      return await this.requireClient().get(key);
    } catch (err) {
      if (err instanceof ApiError) {
        throw err;
      }
      this.logger.error('redis_command_failed', { command: 'get' });
      throw new ApiError(ErrorCodes.INTERNAL_ERROR, UNAVAILABLE_MESSAGE, 503);
    }
  }

  private requireClient(): RedisClient {
    if (!this.enabled || !this.client || !this.client.isOpen) {
      throw new ApiError(ErrorCodes.INTERNAL_ERROR, UNAVAILABLE_MESSAGE, 503);
    }
    return this.client;
  }

  private redisConfig(): AppConfig['redis'] {
    return this.configService.getOrThrow<AppConfig['redis']>('redis');
  }
}
