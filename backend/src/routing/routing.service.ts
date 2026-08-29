import { Inject, Injectable } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import {
  assertLatLng,
  CoordinateError,
  LatLng,
  metersToKm,
} from './coordinates';
import {
  ROUTING_PROVIDER,
  RoutingProvider,
  RoutingProviderError,
  RoutingResult,
  serializeRouting,
} from './routing-provider';

export type RouteStop = {
  sequence: number;
  latitude: string | number;
  longitude: string | number;
};

@Injectable()
export class RoutingService {
  constructor(
    @Inject(ROUTING_PROVIDER) private readonly provider: RoutingProvider,
  ) {}

  async routePoints(points: LatLng[]): Promise<RoutingResult> {
    if (points.length < 2) {
      throw new ApiError(
        ErrorCodes.INVALID_STOPS,
        'A route requires at least pickup and one drop',
        400,
      );
    }
    let validated: LatLng[];
    try {
      validated = points.map((point) => assertLatLng(point));
    } catch (err) {
      throw this.coordinateError(err);
    }
    let result: RoutingResult;
    try {
      result = await this.provider.route({ points: validated });
    } catch (err) {
      throw this.providerError(err);
    }
    return this.assertResult(result, validated);
  }

  async routeStops(stops: RouteStop[]): Promise<RoutingResult> {
    const ordered = [...stops].sort((left, right) => left.sequence - right.sequence);
    const points: LatLng[] = [];
    try {
      for (const stop of ordered) {
        points.push(
          assertLatLng({
            latitude: stop.latitude,
            longitude: stop.longitude,
          }),
        );
      }
    } catch (err) {
      throw this.coordinateError(err);
    }
    return this.routePoints(points);
  }

  distanceKm(result: RoutingResult): string {
    try {
      return metersToKm(result.distanceMeters);
    } catch {
      throw new ApiError(
        ErrorCodes.ROUTING_INVALID_RESPONSE,
        'Routing distance is not a usable positive integer',
        502,
      );
    }
  }

  toResponse(result: RoutingResult) {
    return serializeRouting(result);
  }

  private assertResult(result: RoutingResult, points: LatLng[]): RoutingResult {
    if (result.provider !== 'mock' && result.provider !== 'google') {
      throw new ApiError(
        ErrorCodes.ROUTING_INVALID_RESPONSE,
        'Routing provider name is invalid',
        502,
      );
    }
    if (
      !Number.isInteger(result.distanceMeters) ||
      !Number.isFinite(result.distanceMeters) ||
      result.distanceMeters <= 0
    ) {
      throw new ApiError(
        ErrorCodes.ROUTING_INVALID_RESPONSE,
        'Routing distance is missing or invalid',
        502,
      );
    }
    if (
      !Number.isInteger(result.durationSeconds) ||
      !Number.isFinite(result.durationSeconds) ||
      result.durationSeconds < 0
    ) {
      throw new ApiError(
        ErrorCodes.ROUTING_INVALID_RESPONSE,
        'Routing duration is invalid',
        502,
      );
    }
    if (result.waypointCount !== Math.max(0, points.length - 2)) {
      throw new ApiError(
        ErrorCodes.ROUTING_INVALID_RESPONSE,
        'Routing waypoint count does not match the stop sequence',
        502,
      );
    }
    return result;
  }

  private coordinateError(err: unknown): ApiError {
    const message =
      err instanceof CoordinateError ? err.message : 'Coordinates are invalid';
    return new ApiError(ErrorCodes.INVALID_COORDINATES, message, 400);
  }

  private providerError(err: unknown): ApiError {
    if (err instanceof ApiError) {
      return err;
    }
    if (err instanceof RoutingProviderError) {
      if (err.kind === 'unavailable') {
        return new ApiError(
          ErrorCodes.ROUTING_PROVIDER_UNAVAILABLE,
          'Routing provider is unavailable',
          503,
        );
      }
      return new ApiError(
        ErrorCodes.ROUTING_INVALID_RESPONSE,
        'Routing provider returned an invalid response',
        502,
      );
    }
    return new ApiError(
      ErrorCodes.ROUTING_PROVIDER_UNAVAILABLE,
      'Routing provider is unavailable',
      503,
    );
  }
}
