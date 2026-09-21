import { loadAppConfig } from './configuration';

describe('routing configuration', () => {
  const originalEnv = process.env.NODE_ENV;
  const originalProvider = process.env.ROUTING_PROVIDER;
  const originalKey = process.env.GOOGLE_MAPS_API_KEY;
  const originalStore = process.env.LOCATION_STORE;
  const originalRedis = process.env.REDIS_ENABLED;

  function restore(name: string, value: string | undefined): void {
    if (value === undefined) {
      delete process.env[name];
    } else {
      process.env[name] = value;
    }
  }

  afterEach(() => {
    restore('NODE_ENV', originalEnv);
    restore('ROUTING_PROVIDER', originalProvider);
    restore('GOOGLE_MAPS_API_KEY', originalKey);
    restore('LOCATION_STORE', originalStore);
    restore('REDIS_ENABLED', originalRedis);
  });

  it('defaults to mock outside production when ROUTING_PROVIDER is unset', () => {
    process.env.NODE_ENV = 'development';
    delete process.env.ROUTING_PROVIDER;
    delete process.env.GOOGLE_MAPS_API_KEY;
    const config = loadAppConfig();
    expect(config.routing.provider).toBe('mock');
    expect(config.routing.googleApiKey).toBeNull();
  });

  it('defaults to google in production when ROUTING_PROVIDER is unset', () => {
    process.env.NODE_ENV = 'production';
    delete process.env.ROUTING_PROVIDER;
    process.env.GOOGLE_MAPS_API_KEY = 'test-google-maps-key-not-real';
    const config = loadAppConfig();
    expect(config.routing.provider).toBe('google');
    expect(config.routing.googleApiKey).toBe('test-google-maps-key-not-real');
  });

  it('refuses production google default without an API key and does not fall back to mock', () => {
    process.env.NODE_ENV = 'production';
    delete process.env.ROUTING_PROVIDER;
    delete process.env.GOOGLE_MAPS_API_KEY;
    expect(() => loadAppConfig()).toThrow(/GOOGLE_MAPS_API_KEY/);
    expect(() => loadAppConfig()).toThrow(/fall back to mock/);
  });

  it('allows explicit mock in production without a Google key', () => {
    process.env.NODE_ENV = 'production';
    process.env.ROUTING_PROVIDER = 'mock';
    delete process.env.GOOGLE_MAPS_API_KEY;
    expect(loadAppConfig().routing.provider).toBe('mock');
  });

  it('refuses google without an API key and does not fall back to mock', () => {
    process.env.ROUTING_PROVIDER = 'google';
    delete process.env.GOOGLE_MAPS_API_KEY;
    expect(() => loadAppConfig()).toThrow(/GOOGLE_MAPS_API_KEY/);
    expect(() => loadAppConfig()).toThrow(/fall back to mock/);
  });

  it('refuses a Redis location store without REDIS_ENABLED and does not fall back to memory', () => {
    process.env.LOCATION_STORE = 'redis';
    process.env.REDIS_ENABLED = 'false';
    expect(() => loadAppConfig()).toThrow(/REDIS_ENABLED=true/);
    expect(() => loadAppConfig()).toThrow(/fall back to memory/);
  });
});
