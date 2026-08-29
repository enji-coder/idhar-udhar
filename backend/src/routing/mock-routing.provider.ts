import { Injectable } from '@nestjs/common';
import { haversineMeters, LatLng } from './coordinates';
import {
  RoutingProvider,
  RoutingProviderError,
  RoutingRequest,
  RoutingResult,
} from './routing-provider';

/**
 * Deterministic stand-in. Never labeled as Google.
 * Inflates haversine by a fixed factor so tests have a stable "road" length
 * without pretending this is a mapped route.
 */
export const MOCK_ROAD_FACTOR = 1.25;

export type MockScript =
  | 'ok'
  | 'unavailable'
  | 'invalid_response'
  | 'missing_distance'
  | 'negative_distance'
  | 'invalid_duration';

@Injectable()
export class MockRoutingProvider implements RoutingProvider {
  readonly provider = 'mock' as const;
  lastRequest: RoutingRequest | null = null;
  private script: MockScript[] = [];

  enqueue(kind: MockScript): void {
    this.script.push(kind);
  }

  reset(): void {
    this.script = [];
    this.lastRequest = null;
  }

  async route(request: RoutingRequest): Promise<RoutingResult> {
    this.lastRequest = request;
    const next = this.script.shift() ?? 'ok';
    if (next === 'unavailable') {
      throw new RoutingProviderError(
        'unavailable',
        'mock routing provider is unavailable',
      );
    }
    if (next === 'invalid_response') {
      throw new RoutingProviderError(
        'invalid_response',
        'mock routing provider returned a malformed response',
      );
    }
    const points = request.points;
    const origin = points[0];
    const destination = points[points.length - 1];
    const waypointCount = Math.max(0, points.length - 2);
    if (next === 'missing_distance') {
      return {
        provider: 'mock',
        distanceMeters: Number.NaN,
        durationSeconds: 60,
        origin,
        destination,
        waypointCount,
        calculatedAt: new Date(),
        encodedPolyline: null,
        providerMetadata: { mockRoadFactor: MOCK_ROAD_FACTOR },
      };
    }
    if (next === 'negative_distance') {
      return {
        provider: 'mock',
        distanceMeters: -1,
        durationSeconds: 60,
        origin,
        destination,
        waypointCount,
        calculatedAt: new Date(),
        encodedPolyline: null,
        providerMetadata: { mockRoadFactor: MOCK_ROAD_FACTOR },
      };
    }
    if (next === 'invalid_duration') {
      return {
        provider: 'mock',
        distanceMeters: mockRoadMeters(points),
        durationSeconds: -5,
        origin,
        destination,
        waypointCount,
        calculatedAt: new Date(),
        encodedPolyline: null,
        providerMetadata: { mockRoadFactor: MOCK_ROAD_FACTOR },
      };
    }
    const distanceMeters = mockRoadMeters(points);
    return {
      provider: 'mock',
      distanceMeters,
      durationSeconds: mockDurationSeconds(distanceMeters),
      origin,
      destination,
      waypointCount,
      calculatedAt: new Date(),
      encodedPolyline: null,
      providerMetadata: { mockRoadFactor: MOCK_ROAD_FACTOR },
    };
  }
}

export function mockRoadMeters(points: LatLng[]): number {
  let sum = 0;
  for (let i = 0; i < points.length - 1; i += 1) {
    sum += haversineMeters(points[i], points[i + 1]);
  }
  return Math.max(1, Math.round(sum * MOCK_ROAD_FACTOR));
}

function mockDurationSeconds(distanceMeters: number): number {
  return Math.max(1, Math.round(distanceMeters / (30_000 / 3600)));
}
