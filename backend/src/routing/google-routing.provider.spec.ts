import { ConfigService } from '@nestjs/config';
import { AppLogger } from '../common/logger/app-logger';
import {
  GoogleRoutingProvider,
  RoutingHttpPost,
} from './google-routing.provider';
import { RoutingProviderError } from './routing-provider';

const points = [
  { latitude: 23.0225, longitude: 72.5714 },
  { latitude: 23.04, longitude: 72.52 },
];

function providerWith(http: RoutingHttpPost): GoogleRoutingProvider {
  const config = {
    getOrThrow: () => ({
      provider: 'google' as const,
      googleApiKey: 'test-not-a-real-key',
      timeoutMs: 50,
    }),
  };
  const logger = { info: jest.fn(), warn: jest.fn(), error: jest.fn() };
  const instance = new GoogleRoutingProvider(
    config as unknown as ConfigService,
    logger as unknown as AppLogger,
  );
  instance.useHttpPost(http);
  return instance;
}

describe('GoogleRoutingProvider', () => {
  it('parses a successful HTTP payload and does not invent distance', async () => {
    const instance = providerWith(async () => ({
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

  it('fails clearly when the HTTP provider errors', async () => {
    const instance = providerWith(async () => ({
      status: 503,
      json: { error: { message: 'unavailable' } },
    }));
    await expect(instance.route({ points })).rejects.toMatchObject({
      kind: 'unavailable',
    });
    expect.assertions(1);
  });

  it('does not fabricate a route when distance is missing', async () => {
    const instance = providerWith(async () => ({
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
});
