import { Injectable } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { RedisService } from '../redis/redis.service';
import {
  LocationStore,
  LocationStoreBackend,
  RiderLocationFix,
} from './location-store';

type StoredFix = {
  riderProfileId: string;
  identityId: string;
  latitude: number;
  longitude: number;
  accuracyMeters: number | null;
  heading: number | null;
  speedMps: number | null;
  recordedAt: string;
  receivedAt: string;
};

/**
 * Hot last-known rider GPS in Redis/Valkey. Not PostgreSQL. Not fare/order state.
 */
@Injectable()
export class RedisLocationStore implements LocationStore {
  readonly backend: LocationStoreBackend = 'redis';
  readonly durable = false;

  constructor(private readonly redis: RedisService) {}

  async upsert(fix: RiderLocationFix): Promise<void> {
    const payload: StoredFix = {
      riderProfileId: fix.riderProfileId,
      identityId: fix.identityId,
      latitude: fix.latitude,
      longitude: fix.longitude,
      accuracyMeters: fix.accuracyMeters,
      heading: fix.heading,
      speedMps: fix.speedMps,
      recordedAt: fix.recordedAt.toISOString(),
      receivedAt: fix.receivedAt.toISOString(),
    };
    await this.redis.set(this.key(fix.riderProfileId), JSON.stringify(payload));
  }

  async get(riderProfileId: string): Promise<RiderLocationFix | null> {
    const raw = await this.redis.get(this.key(riderProfileId));
    if (!raw) {
      return null;
    }
    try {
      const parsed = JSON.parse(raw) as StoredFix;
      return {
        riderProfileId: parsed.riderProfileId,
        identityId: parsed.identityId,
        latitude: parsed.latitude,
        longitude: parsed.longitude,
        accuracyMeters: parsed.accuracyMeters ?? null,
        heading: parsed.heading ?? null,
        speedMps: parsed.speedMps ?? null,
        recordedAt: new Date(parsed.recordedAt),
        receivedAt: new Date(parsed.receivedAt),
      };
    } catch {
      throw new ApiError(
        ErrorCodes.INTERNAL_ERROR,
        'Location store is unavailable. Try again shortly.',
        503,
      );
    }
  }

  private key(riderProfileId: string): string {
    return `iu:rider:location:${riderProfileId}`;
  }
}
