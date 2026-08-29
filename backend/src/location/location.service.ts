import { Inject, Injectable } from '@nestjs/common';
import { AuthContext } from '../auth/types/auth-context';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { assertLatLng, CoordinateError } from '../routing/coordinates';
import { UpdateRiderLocationDto } from './dto/update-rider-location.dto';
import { LOCATION_STORE, LocationStore, RiderLocationFix } from './location-store';

@Injectable()
export class LocationService {
  constructor(@Inject(LOCATION_STORE) private readonly store: LocationStore) {}

  async updateRiderLocation(auth: AuthContext, body: UpdateRiderLocationDto) {
    if (auth.role !== 'RIDER') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Rider role required', 403);
    }
    let coords;
    try {
      coords = assertLatLng({
        latitude: body.latitude,
        longitude: body.longitude,
      });
    } catch (err) {
      const message =
        err instanceof CoordinateError ? err.message : 'Coordinates are invalid';
      throw new ApiError(ErrorCodes.INVALID_COORDINATES, message, 400);
    }
    const recordedAt = this.parseTimestamp(body.timestamp);
    const receivedAt = new Date();
    const fix: RiderLocationFix = {
      riderProfileId: auth.profileId,
      identityId: auth.identityId,
      latitude: coords.latitude,
      longitude: coords.longitude,
      accuracyMeters:
        body.accuracy_meters === undefined ? null : body.accuracy_meters,
      heading: body.heading === undefined ? null : body.heading,
      speedMps: body.speed === undefined ? null : body.speed,
      recordedAt,
      receivedAt,
    };
    await this.store.upsert(fix);
    return this.serialize(fix);
  }

  async getOwnLocation(auth: AuthContext) {
    if (auth.role !== 'RIDER') {
      throw new ApiError(ErrorCodes.FORBIDDEN, 'Rider role required', 403);
    }
    const fix = await this.store.get(auth.profileId);
    return {
      store: this.store.backend,
      durable: this.store.durable,
      location: fix ? this.serializeFix(fix) : null,
    };
  }

  private parseTimestamp(raw: string): Date {
    const recordedAt = new Date(raw);
    if (Number.isNaN(recordedAt.getTime())) {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'timestamp is invalid',
        400,
      );
    }
    const skewMs = recordedAt.getTime() - Date.now();
    if (skewMs > 60 * 60 * 1000) {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'timestamp is too far in the future',
        400,
      );
    }
    return recordedAt;
  }

  private serialize(fix: RiderLocationFix) {
    return {
      accepted: true,
      store: this.store.backend,
      durable: this.store.durable,
      rider_profile_id: fix.riderProfileId,
      ...this.serializeFix(fix),
    };
  }

  private serializeFix(fix: RiderLocationFix) {
    return {
      latitude: fix.latitude,
      longitude: fix.longitude,
      accuracy_meters: fix.accuracyMeters,
      heading: fix.heading,
      speed: fix.speedMps,
      recorded_at: fix.recordedAt.toISOString(),
      received_at: fix.receivedAt.toISOString(),
    };
  }
}
