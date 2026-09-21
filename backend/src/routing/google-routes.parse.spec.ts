import {
  GOOGLE_FIELD_MASK,
  GOOGLE_ROUTES_URL,
  buildGoogleComputeRoutesBody,
  parseGoogleComputeRoutesResponse,
  parseGoogleDuration,
} from './google-routes.parse';
import { RoutingProviderError } from './routing-provider';

const points = [
  { latitude: 23.0225, longitude: 72.5714 },
  { latitude: 23.04, longitude: 72.52 },
];

describe('Google Routes response parser', () => {
  it('builds a computeRoutes body from validated lat/lng only', () => {
    const via = { latitude: 23.03, longitude: 72.55 };
    const body = buildGoogleComputeRoutesBody([points[0], via, points[1]]);
    expect(body).toEqual({
      origin: {
        location: {
          latLng: { latitude: points[0].latitude, longitude: points[0].longitude },
        },
      },
      destination: {
        location: {
          latLng: { latitude: points[1].latitude, longitude: points[1].longitude },
        },
      },
      intermediates: [
        {
          location: {
            latLng: { latitude: via.latitude, longitude: via.longitude },
          },
        },
      ],
      travelMode: 'DRIVE',
      routingPreference: 'TRAFFIC_UNAWARE',
      computeAlternativeRoutes: false,
      optimizeWaypointOrder: false,
      units: 'METRIC',
    });
    expect(body).not.toHaveProperty('extraComputations');
    expect(GOOGLE_ROUTES_URL).toBe(
      'https://routes.googleapis.com/directions/v2:computeRoutes',
    );
    expect(GOOGLE_FIELD_MASK).toBe(
      'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
    );
    expect(GOOGLE_FIELD_MASK).not.toMatch(/toll|traffic|legs|viewport/i);
  });

  it('parses a successful computeRoutes payload', () => {
    const result = parseGoogleComputeRoutesResponse(
      {
        routes: [
          {
            distanceMeters: 5432,
            duration: '812s',
            polyline: { encodedPolyline: 'abc' },
          },
        ],
      },
      points,
      new Date('2026-08-25T10:00:00.000Z'),
    );
    expect(result.provider).toBe('google');
    expect(result.distanceMeters).toBe(5432);
    expect(result.durationSeconds).toBe(812);
    expect(result.encodedPolyline).toBe('abc');
    expect(result.waypointCount).toBe(0);
    expect(result.origin).toEqual(points[0]);
    expect(result.destination).toEqual(points[1]);
  });

  it('parses duration strings', () => {
    expect(parseGoogleDuration('12s')).toBe(12);
    expect(parseGoogleDuration(9)).toBe(9);
  });

  it('rejects provider error envelopes', () => {
    expect(() =>
      parseGoogleComputeRoutesResponse(
        { error: { code: 403, message: 'denied', status: 'PERMISSION_DENIED' } },
        points,
      ),
    ).toThrow(RoutingProviderError);
    try {
      parseGoogleComputeRoutesResponse({ error: { code: 403 } }, points);
    } catch (err) {
      expect(err).toBeInstanceOf(RoutingProviderError);
      expect((err as RoutingProviderError).kind).toBe('unavailable');
    }
  });

  it('rejects missing distance', () => {
    expect(() =>
      parseGoogleComputeRoutesResponse(
        { routes: [{ duration: '10s' }] },
        points,
      ),
    ).toThrow(/missing distance/);
  });

  it('rejects negative distance', () => {
    expect(() =>
      parseGoogleComputeRoutesResponse(
        { routes: [{ distanceMeters: -1, duration: '10s' }] },
        points,
      ),
    ).toThrow(/negative/);
  });

  it('rejects malformed distance and duration', () => {
    expect(() =>
      parseGoogleComputeRoutesResponse(
        { routes: [{ distanceMeters: 12.5, duration: '10s' }] },
        points,
      ),
    ).toThrow(/malformed/);
    expect(() => parseGoogleDuration('ten')).toThrow(/duration/);
    expect(() =>
      parseGoogleComputeRoutesResponse({ routes: [] }, points),
    ).toThrow(/missing routes/);
  });

  it('rejects a non-object payload', () => {
    expect(() => parseGoogleComputeRoutesResponse('nope', points)).toThrow(
      /not an object/,
    );
  });
});
