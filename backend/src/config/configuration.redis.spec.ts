import { loadAppConfig } from './configuration';

describe('Redis / location store configuration', () => {
  const originalEnv = process.env.NODE_ENV;
  const originalEnabled = process.env.REDIS_ENABLED;
  const originalHost = process.env.REDIS_HOST;
  const originalPort = process.env.REDIS_PORT;
  const originalTls = process.env.REDIS_TLS;
  const originalStore = process.env.LOCATION_STORE;

  function restore(name: string, value: string | undefined): void {
    if (value === undefined) {
      delete process.env[name];
    } else {
      process.env[name] = value;
    }
  }

  afterEach(() => {
    restore('NODE_ENV', originalEnv);
    restore('REDIS_ENABLED', originalEnabled);
    restore('REDIS_HOST', originalHost);
    restore('REDIS_PORT', originalPort);
    restore('REDIS_TLS', originalTls);
    restore('LOCATION_STORE', originalStore);
  });

  it('keeps Redis disabled and memory location store by default outside production', () => {
    process.env.NODE_ENV = 'development';
    delete process.env.REDIS_ENABLED;
    delete process.env.REDIS_HOST;
    delete process.env.REDIS_TLS;
    delete process.env.LOCATION_STORE;
    const config = loadAppConfig();
    expect(config.redis.enabled).toBe(false);
    expect(config.redis.host).toBeNull();
    expect(config.redis.tls).toBe(false);
    expect(config.location.store).toBe('memory');
  });

  it('enables TLS Redis when requested and does not invent a password', () => {
    process.env.REDIS_ENABLED = 'true';
    process.env.REDIS_HOST = 'valkey.example.internal';
    process.env.REDIS_PORT = '6379';
    process.env.REDIS_TLS = 'true';
    process.env.LOCATION_STORE = 'redis';
    const config = loadAppConfig();
    expect(config.redis.enabled).toBe(true);
    expect(config.redis.host).toBe('valkey.example.internal');
    expect(config.redis.port).toBe(6379);
    expect(config.redis.tls).toBe(true);
    expect(config.location.store).toBe('redis');
    expect(config).not.toHaveProperty('redis.password');
  });

  it('refuses LOCATION_STORE=redis without REDIS_ENABLED and does not fall back to memory', () => {
    process.env.LOCATION_STORE = 'redis';
    process.env.REDIS_ENABLED = 'false';
    process.env.REDIS_HOST = 'valkey.example.internal';
    expect(() => loadAppConfig()).toThrow(/REDIS_ENABLED=true/);
    expect(() => loadAppConfig()).toThrow(/fall back to memory/);
  });

  it('refuses REDIS_ENABLED without REDIS_HOST', () => {
    process.env.REDIS_ENABLED = 'true';
    delete process.env.REDIS_HOST;
    process.env.LOCATION_STORE = 'memory';
    expect(() => loadAppConfig()).toThrow(/REDIS_HOST/);
  });

  it('defaults to redis in production when LOCATION_STORE is unset and Redis is configured', () => {
    process.env.NODE_ENV = 'production';
    delete process.env.LOCATION_STORE;
    process.env.REDIS_ENABLED = 'true';
    process.env.REDIS_HOST = 'valkey.example.internal';
    process.env.REDIS_TLS = 'true';
    expect(loadAppConfig().location.store).toBe('redis');
  });

  it('refuses production redis default without REDIS_ENABLED and does not fall back to memory', () => {
    process.env.NODE_ENV = 'production';
    delete process.env.LOCATION_STORE;
    process.env.REDIS_ENABLED = 'false';
    expect(() => loadAppConfig()).toThrow(/REDIS_ENABLED=true/);
    expect(() => loadAppConfig()).toThrow(/fall back to memory/);
  });
});
