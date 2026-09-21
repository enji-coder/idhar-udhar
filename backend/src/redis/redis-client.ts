import { createClient } from 'redis';

export type RedisClient = {
  connect(): Promise<unknown>;
  quit(): Promise<unknown>;
  ping(): Promise<unknown>;
  set(key: string, value: string): Promise<unknown>;
  get(key: string): Promise<string | null>;
  on(event: string, listener: (err: Error) => void): unknown;
  readonly isOpen: boolean;
};

export type RedisSocketOptions = {
  host: string;
  port: number;
  tls: boolean;
};

export type RedisClientFactory = (options: RedisSocketOptions) => RedisClient;

export const REDIS_RECONNECT_CAP_MS = 2000;

function reconnectStrategy(retries: number): number {
  return Math.min(retries * 50, REDIS_RECONNECT_CAP_MS);
}

export function buildRedisClientOptions(options: RedisSocketOptions) {
  if (options.tls) {
    return {
      socket: {
        host: options.host,
        port: options.port,
        tls: true as const,
        reconnectStrategy,
      },
    };
  }
  return {
    socket: {
      host: options.host,
      port: options.port,
      reconnectStrategy,
    },
  };
}

export function defaultRedisClientFactory(
  options: RedisSocketOptions,
): RedisClient {
  return createClient(
    buildRedisClientOptions(options),
  ) as unknown as RedisClient;
}
