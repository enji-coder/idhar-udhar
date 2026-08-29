import { LatLng } from './coordinates';

export const ROUTING_PROVIDER = 'ROUTING_PROVIDER';

export type RoutingProviderName = 'mock' | 'google';

export type RoutingRequest = {
  points: LatLng[];
};

export type RoutingResult = {
  provider: RoutingProviderName;
  distanceMeters: number;
  durationSeconds: number;
  origin: LatLng;
  destination: LatLng;
  waypointCount: number;
  calculatedAt: Date;
  encodedPolyline: string | null;
  providerMetadata: {
    travelMode?: string;
    mockRoadFactor?: number;
  };
};

export type RoutingFailureKind = 'unavailable' | 'invalid_response';

export class RoutingProviderError extends Error {
  constructor(
    readonly kind: RoutingFailureKind,
    message: string,
  ) {
    super(message);
    this.name = 'RoutingProviderError';
  }
}

export interface RoutingProvider {
  readonly provider: RoutingProviderName;
  route(request: RoutingRequest): Promise<RoutingResult>;
}

export function serializeRouting(result: RoutingResult) {
  return {
    provider: result.provider,
    distance_meters: result.distanceMeters,
    estimated_duration_seconds: result.durationSeconds,
    origin: result.origin,
    destination: result.destination,
    waypoint_count: result.waypointCount,
    calculated_at: result.calculatedAt.toISOString(),
    encoded_polyline: result.encodedPolyline,
  };
}
