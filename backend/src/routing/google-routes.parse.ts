import { LatLng } from './coordinates';
import { RoutingProviderError, RoutingResult } from './routing-provider';

export const GOOGLE_ROUTES_URL =
  'https://routes.googleapis.com/directions/v2:computeRoutes';

export const GOOGLE_FIELD_MASK =
  'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline';

export function buildGoogleComputeRoutesBody(points: LatLng[]) {
  const origin = points[0];
  const destination = points[points.length - 1];
  const intermediates = points.slice(1, -1).map((point) => ({
    location: {
      latLng: { latitude: point.latitude, longitude: point.longitude },
    },
  }));
  return {
    origin: waypoint(origin),
    destination: waypoint(destination),
    ...(intermediates.length > 0 ? { intermediates } : {}),
    travelMode: 'DRIVE',
    routingPreference: 'TRAFFIC_UNAWARE',
    computeAlternativeRoutes: false,
    optimizeWaypointOrder: false,
  };
}

function waypoint(point: LatLng) {
  return {
    location: {
      latLng: { latitude: point.latitude, longitude: point.longitude },
    },
  };
}

export function parseGoogleDuration(value: unknown): number {
  if (typeof value === 'number' && Number.isFinite(value) && value >= 0) {
    return Math.round(value);
  }
  if (typeof value === 'string') {
    const match = /^(\d+)(?:\.\d+)?s$/.exec(value.trim());
    if (match) {
      return Number.parseInt(match[1], 10);
    }
  }
  throw new RoutingProviderError(
    'invalid_response',
    'Google routing response duration is invalid',
  );
}

export function parseGoogleComputeRoutesResponse(
  json: unknown,
  points: LatLng[],
  calculatedAt = new Date(),
): RoutingResult {
  if (json === null || typeof json !== 'object') {
    throw new RoutingProviderError(
      'invalid_response',
      'Google routing response is not an object',
    );
  }
  const body = json as {
    error?: { code?: number; message?: string; status?: string };
    routes?: Array<{
      distanceMeters?: unknown;
      duration?: unknown;
      polyline?: { encodedPolyline?: unknown };
    }>;
  };
  if (body.error) {
    throw new RoutingProviderError(
      'unavailable',
      'Google routing provider returned an error',
    );
  }
  const route = body.routes?.[0];
  if (!route) {
    throw new RoutingProviderError(
      'invalid_response',
      'Google routing response is missing routes',
    );
  }
  if (
    typeof route.distanceMeters !== 'number' ||
    !Number.isFinite(route.distanceMeters)
  ) {
    throw new RoutingProviderError(
      'invalid_response',
      'Google routing response is missing distance',
    );
  }
  if (!Number.isInteger(route.distanceMeters)) {
    throw new RoutingProviderError(
      'invalid_response',
      'Google routing response distance is malformed',
    );
  }
  if (route.distanceMeters < 0) {
    throw new RoutingProviderError(
      'invalid_response',
      'Google routing response distance is negative',
    );
  }
  if (route.distanceMeters === 0) {
    throw new RoutingProviderError(
      'invalid_response',
      'Google routing response is missing distance',
    );
  }
  const durationSeconds = parseGoogleDuration(route.duration);
  const polylineRaw = route.polyline?.encodedPolyline;
  const encodedPolyline =
    typeof polylineRaw === 'string' && polylineRaw.length > 0
      ? polylineRaw
      : null;
  return {
    provider: 'google',
    distanceMeters: route.distanceMeters,
    durationSeconds,
    origin: points[0],
    destination: points[points.length - 1],
    waypointCount: Math.max(0, points.length - 2),
    calculatedAt,
    encodedPolyline,
    providerMetadata: { travelMode: 'DRIVE' },
  };
}
