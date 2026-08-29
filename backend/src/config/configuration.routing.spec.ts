import { loadAppConfig } from './configuration';

describe('routing configuration', () => {
  const originalProvider = process.env.ROUTING_PROVIDER;
  const originalKey = process.env.GOOGLE_MAPS_API_KEY;
  const originalStore = process.env.LOCATION_STORE;

  afterEach(() => {
    if (originalProvider === undefined) {
      delete process.env.ROUTING_PROVIDER;
    } else {
      process.env.ROUTING_PROVIDER = originalProvider;
    }
    if (originalKey === undefined) {
      delete process.env.GOOGLE_MAPS_API_KEY;
    } else {
      process.env.GOOGLE_MAPS_API_KEY = originalKey;
    }
    if (originalStore === undefined) {
      delete process.env.LOCATION_STORE;
    } else {
      process.env.LOCATION_STORE = originalStore;
    }
  });

  it('refuses google without an API key and does not fall back to mock', () => {
    process.env.ROUTING_PROVIDER = 'google';
    delete process.env.GOOGLE_MAPS_API_KEY;
    expect(() => loadAppConfig()).toThrow(/GOOGLE_MAPS_API_KEY/);
    expect(() => loadAppConfig()).toThrow(/fall back to mock/);
  });

  it('refuses a Redis location store until that phase exists', () => {
    process.env.LOCATION_STORE = 'redis';
    expect(() => loadAppConfig()).toThrow(/not implemented/);
  });
});
