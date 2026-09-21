import { ConfigService } from '@nestjs/config';
import { AppLogger } from '../common/logger/app-logger';
import {
  GOOGLE_FIELD_MASK,
  GOOGLE_ROUTES_URL,
} from './google-routes.parse';
import {
  GOOGLE_ROUTES_MAX_ATTEMPTS,
  GoogleRoutingProvider,
  RoutingHttpPost,
} from './google-routing.provider';
import { RoutingProviderError } from './routing-provider';

const API_KEY = 'test-not-a-real-key';
const points = [
  { latitude: 23.0225, longitude: 72.5714 },
  { latitude: 23.04, longitude: 72.52 },
];

function providerWith(http: RoutingHttpPost): {
  instance: GoogleRoutingProvider;
  logger: { info: jest.Mock; warn: jest.Mock; error: jest.Mock };
} {
  const config = {
    getOrThrow: () => ({
      provider: 'google' as const,
      googleApiKey: API_KEY,
      timeoutMs: 50,
    }),
  };
  const logger = { info: jest.fn(), warn: jest.fn(), error: jest.fn() };
  const instance = new GoogleRoutingProvider(
    config as unknown as ConfigService,
    logger as unknown as AppLogger,
  );
  instance.useHttpPost(http);
  return { instance, logger };
}

describe('GoogleRoutingProvider', () => {
  it('parses a successful HTTP payload and does not invent distance', async () => {
    const { instance } = providerWith(async () => ({
      status: 200,
      json: {
        routes: [{ distanceMeters: 4100, duration: '600s' }],
      },
    }));
    const result = await instance.route({ points });
    expect(result.provider).toBe('google');
    expect(result.distanceMeters).toBe(4100);
    expect(result.durationSeconds).toBe(600);
  });

  it('posts to Routes API with the field mask, metric units, and configured timeout', async () => {
    const http = jest.fn(async () => ({
      status: 200,
      json: { routes: [{ distanceMeters: 4100, duration: '600s' }] },
    }));
    const { instance, logger } = providerWith(http);
    await instance.route({ points });
    expect(http).toHaveBeenCalledTimes(1);
    expect(http).toHaveBeenCalledWith(
      GOOGLE_ROUTES_URL,
      expect.objectContaining({
        'X-Goog-FieldMask': GOOGLE_FIELD_MASK,
        'X-Goog-Api-Key': API_KEY,
      }),
      expect.objectContaining({
        travelMode: 'DRIVE',
        routingPreference: 'TRAFFIC_UNAWARE',
        computeAlternativeRoutes: false,
        units: 'METRIC',
      }),
      50,
    );
    const logged = JSON.stringify(logger.info.mock.calls);
    expect(logged).not.toContain(API_KEY);
    expect(logged).not.toMatch(/23\.0225|72\.5714/);
  });

  it('retries a transient 5xx once then fails unavailable', async () => {
    const http = jest.fn(async () => ({
      status: 503,
      json: { error: { message: 'unavailable' } },
    }));
    const { instance } = providerWith(http);
    await expect(instance.route({ points })).rejects.toMatchObject({
      kind: 'unavailable',
    });
    expect(http).toHaveBeenCalledTimes(GOOGLE_ROUTES_MAX_ATTEMPTS);
    expect(GOOGLE_ROUTES_MAX_ATTEMPTS).toBe(2);
  });

  it('retries a 429 once then fails unavailable', async () => {
    const http = jest.fn(async () => ({
      status: 429,
      json: { error: { status: 'RESOURCE_EXHAUSTED' } },
    }));
    const { instance } = providerWith(http);
    await expect(instance.route({ points })).rejects.toMatchObject({
      kind: 'unavailable',
    });
    expect(http).toHaveBeenCalledTimes(2);
  });

  it('retries a provider timeout once then fails unavailable', async () => {
    const http = jest.fn(async () => {
      throw new RoutingProviderError(
        'unavailable',
        'Google routing provider is unavailable',
      );
    });
    const { instance } = providerWith(http);
    await expect(instance.route({ points })).rejects.toMatchObject({
      kind: 'unavailable',
    });
    expect(http).toHaveBeenCalledTimes(2);
  });

  it('succeeds after one transient failure', async () => {
    const http = jest
      .fn()
      .mockResolvedValueOnce({
        status: 503,
        json: { error: { message: 'unavailable' } },
      })
      .mockResolvedValueOnce({
        status: 200,
        json: { routes: [{ distanceMeters: 4100, duration: '600s' }] },
      });
    const { instance } = providerWith(http);
    const result = await instance.route({ points });
    expect(result.distanceMeters).toBe(4100);
    expect(http).toHaveBeenCalledTimes(2);
  });

  it('does not retry client 4xx errors', async () => {
    const http = jest.fn(async () => ({
      status: 403,
      json: { error: { status: 'PERMISSION_DENIED' } },
    }));
    const { instance } = providerWith(http);
    await expect(instance.route({ points })).rejects.toMatchObject({
      kind: 'unavailable',
    });
    expect(http).toHaveBeenCalledTimes(1);
  });

  it('does not retry invalid_response parse failures', async () => {
    const http = jest.fn(async () => ({
      status: 200,
      json: { routes: [{ duration: '10s' }] },
    }));
    const { instance } = providerWith(http);
    await expect(instance.route({ points })).rejects.toMatchObject({
      kind: 'invalid_response',
    });
    expect(http).toHaveBeenCalledTimes(1);
  });

  it('fails clearly when the HTTP provider errors', async () => {
    const { instance } = providerWith(async () => ({
      status: 503,
      json: { error: { message: 'unavailable' } },
    }));
    await expect(instance.route({ points })).rejects.toMatchObject({
      kind: 'unavailable',
    });
  });

  it('does not fabricate a route when distance is missing', async () => {
    const { instance } = providerWith(async () => ({
      status: 200,
      json: { routes: [{ duration: '10s' }] },
    }));
    await expect(instance.route({ points })).rejects.toBeInstanceOf(
      RoutingProviderError,
    );
    await expect(instance.route({ points })).rejects.toMatchObject({
      kind: 'invalid_response',
    });
  });

  it('does not expose the API key in provider errors', async () => {
    const { instance } = providerWith(async () => ({
      status: 401,
      json: { error: { message: `key ${API_KEY}` } },
    }));
    await expect(instance.route({ points })).rejects.toMatchObject({
      kind: 'unavailable',
      message: expect.not.stringContaining(API_KEY),
    });
  });
});
