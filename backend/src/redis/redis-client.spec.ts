import { buildRedisClientOptions, REDIS_RECONNECT_CAP_MS } from './redis-client';

describe('Redis client options', () => {
  it('enables TLS without an auth token', () => {
    const options = buildRedisClientOptions({
      host: 'valkey.example.internal',
      port: 6379,
      tls: true,
    });
    expect(options.socket.host).toBe('valkey.example.internal');
    expect(options.socket.port).toBe(6379);
    expect(options.socket.tls).toBe(true);
    expect(options).not.toHaveProperty('password');
    expect(options.socket.reconnectStrategy(3)).toBeLessThanOrEqual(
      REDIS_RECONNECT_CAP_MS,
    );
  });
});
