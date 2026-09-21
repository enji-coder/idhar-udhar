import { ApiError } from '../common/errors/api-error';
import { RedisService } from '../redis/redis.service';
import { RiderLocationFix } from './location-store';
import { RedisLocationStore } from './redis-location.store';

const fix: RiderLocationFix = {
  riderProfileId: 'rider-1',
  identityId: 'identity-1',
  latitude: 23.0225,
  longitude: 72.5714,
  accuracyMeters: 8,
  heading: 90,
  speedMps: 4.2,
  recordedAt: new Date('2026-09-19T08:00:00.000Z'),
  receivedAt: new Date('2026-09-19T08:00:01.000Z'),
};

describe('RedisLocationStore', () => {
  it('stores and reads the last rider fix without writing PostgreSQL', async () => {
    const values = new Map<string, string>();
    const redis = {
      set: jest.fn(async (key: string, value: string) => {
        values.set(key, value);
      }),
      get: jest.fn(async (key: string) => values.get(key) ?? null),
    };
    const store = new RedisLocationStore(redis as unknown as RedisService);
    await store.upsert(fix);
    expect(redis.set).toHaveBeenCalledWith(
      'iu:rider:location:rider-1',
      expect.any(String),
    );
    const loaded = await store.get('rider-1');
    expect(loaded).toEqual(fix);
    expect(store.backend).toBe('redis');
    expect(store.durable).toBe(false);
  });

  it('does not pretend a GPS ping succeeded when Redis fails', async () => {
    const redis = {
      set: jest.fn(async () => {
        throw new ApiError('INTERNAL_ERROR', 'Location store is unavailable. Try again shortly.', 503);
      }),
      get: jest.fn(),
    };
    const store = new RedisLocationStore(redis as unknown as RedisService);
    await expect(store.upsert(fix)).rejects.toMatchObject({
      code: 'INTERNAL_ERROR',
      status: 503,
    });
    expect(redis.get).not.toHaveBeenCalled();
  });
});
