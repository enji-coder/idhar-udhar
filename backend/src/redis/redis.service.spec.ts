import { ConfigService } from '@nestjs/config';
import { ApiError } from '../common/errors/api-error';
import { AppLogger } from '../common/logger/app-logger';
import { RedisClient, RedisSocketOptions } from './redis-client';
import { RedisService } from './redis.service';

function mockClient(overrides: Partial<RedisClient> = {}): RedisClient & {
  connect: jest.Mock;
  quit: jest.Mock;
  ping: jest.Mock;
  set: jest.Mock;
  get: jest.Mock;
  on: jest.Mock;
} {
  let open = false;
  const client = {
    connect: jest.fn(async () => {
      open = true;
    }),
    quit: jest.fn(async () => {
      open = false;
    }),
    ping: jest.fn(async () => 'PONG'),
    set: jest.fn(async () => 'OK'),
    get: jest.fn(async () => null),
    on: jest.fn(),
    get isOpen() {
      return open;
    },
    ...overrides,
  };
  if (overrides.connect) {
    client.connect = overrides.connect as jest.Mock;
  }
  return client as RedisClient & {
    connect: jest.Mock;
    quit: jest.Mock;
    ping: jest.Mock;
    set: jest.Mock;
    get: jest.Mock;
    on: jest.Mock;
  };
}

function serviceWith(
  redis: {
    enabled: boolean;
    host: string | null;
    port: number;
    tls: boolean;
  },
  factory: (options: RedisSocketOptions) => RedisClient,
): RedisService {
  const config = {
    getOrThrow: () => redis,
  };
  const logger = { info: jest.fn(), warn: jest.fn(), error: jest.fn() };
  const instance = new RedisService(
    config as unknown as ConfigService,
    logger as unknown as AppLogger,
  );
  instance.useClientFactory(factory);
  return instance;
}

describe('RedisService', () => {
  it('does not connect when Redis is disabled', async () => {
    const factory = jest.fn();
    const service = serviceWith(
      { enabled: false, host: null, port: 6379, tls: false },
      factory,
    );
    await service.onModuleInit();
    expect(factory).not.toHaveBeenCalled();
    expect(service.connected).toBe(false);
    await service.onModuleDestroy();
  });

  it('connects with TLS and no auth token', async () => {
    const seen: RedisSocketOptions[] = [];
    const client = mockClient();
    const service = serviceWith(
      {
        enabled: true,
        host: 'valkey.example.internal',
        port: 6379,
        tls: true,
      },
      (options) => {
        seen.push(options);
        return client;
      },
    );
    await service.onModuleInit();
    expect(seen).toEqual([
      { host: 'valkey.example.internal', port: 6379, tls: true },
    ]);
    expect(client.connect).toHaveBeenCalledTimes(1);
    expect(client.ping).toHaveBeenCalledTimes(1);
    expect(service.connected).toBe(true);
    await service.onModuleDestroy();
    expect(client.quit).toHaveBeenCalledTimes(1);
    expect(service.connected).toBe(false);
  });

  it('fails startup when Redis is enabled but unavailable', async () => {
    const service = serviceWith(
      {
        enabled: true,
        host: 'valkey.example.internal',
        port: 6379,
        tls: true,
      },
      () =>
        mockClient({
          connect: jest.fn(async () => {
            throw new Error('ECONNREFUSED');
          }),
        }),
    );
    await expect(service.onModuleInit()).rejects.toThrow(/ECONNREFUSED/);
    expect(service.connected).toBe(false);
  });

  it('does not fake a successful write when Redis is down', async () => {
    const service = serviceWith(
      { enabled: false, host: null, port: 6379, tls: false },
      jest.fn(),
    );
    await service.onModuleInit();
    await expect(service.set('k', 'v')).rejects.toBeInstanceOf(ApiError);
    await expect(service.set('k', 'v')).rejects.toMatchObject({
      code: 'INTERNAL_ERROR',
      status: 503,
    });
  });
});
