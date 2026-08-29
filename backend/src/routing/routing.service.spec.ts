import { ErrorCodes } from '../common/errors/error-codes';
import { ApiError } from '../common/errors/api-error';
import { MockRoutingProvider, mockRoadMeters } from './mock-routing.provider';
import { metersToKm } from './coordinates';
import { RoutingService } from './routing.service';

const pickup = { latitude: 23.0225, longitude: 72.5714 };
const drop1 = { latitude: 23.04, longitude: 72.52 };
const drop2 = { latitude: 23.05, longitude: 72.51 };
const drop3 = { latitude: 23.06, longitude: 72.51 };

describe('RoutingService', () => {
  let mock: MockRoutingProvider;
  let service: RoutingService;

  beforeEach(() => {
    mock = new MockRoutingProvider();
    service = new RoutingService(mock);
  });

  it('returns a mock route that is not labeled google', async () => {
    const result = await service.routePoints([pickup, drop1]);
    expect(result.provider).toBe('mock');
    expect(result.distanceMeters).toBe(mockRoadMeters([pickup, drop1]));
    expect(result.distanceMeters).toBeGreaterThan(0);
    expect(result.durationSeconds).toBeGreaterThan(0);
    expect(service.distanceKm(result)).toBe(metersToKm(result.distanceMeters));
  });

  it('preserves stop order for pickup + three drops and does not optimize', async () => {
    const points = [pickup, drop1, drop2, drop3];
    const result = await service.routeStops(
      points.map((point, sequence) => ({
        sequence,
        latitude: point.latitude,
        longitude: point.longitude,
      })),
    );
    expect(mock.lastRequest?.points).toEqual(points);
    expect(result.waypointCount).toBe(2);
    expect(result.origin).toEqual(pickup);
    expect(result.destination).toEqual(drop3);
    expect(result.distanceMeters).toBe(mockRoadMeters(points));
  });

  it('rejects invalid latitude', async () => {
    await expect(
      service.routePoints([{ latitude: 91, longitude: 72 }, drop1]),
    ).rejects.toMatchObject({
      code: ErrorCodes.INVALID_COORDINATES,
      status: 400,
    });
  });

  it('rejects invalid longitude', async () => {
    await expect(
      service.routePoints([pickup, { latitude: 23, longitude: 181 }]),
    ).rejects.toMatchObject({
      code: ErrorCodes.INVALID_COORDINATES,
      status: 400,
    });
  });

  it('maps provider unavailability', async () => {
    mock.enqueue('unavailable');
    await expect(service.routePoints([pickup, drop1])).rejects.toMatchObject({
      code: ErrorCodes.ROUTING_PROVIDER_UNAVAILABLE,
      status: 503,
    });
  });

  it('maps malformed provider responses', async () => {
    mock.enqueue('invalid_response');
    await expect(service.routePoints([pickup, drop1])).rejects.toBeInstanceOf(
      ApiError,
    );
    mock.enqueue('missing_distance');
    await expect(service.routePoints([pickup, drop1])).rejects.toMatchObject({
      code: ErrorCodes.ROUTING_INVALID_RESPONSE,
    });
    mock.enqueue('negative_distance');
    await expect(service.routePoints([pickup, drop1])).rejects.toMatchObject({
      code: ErrorCodes.ROUTING_INVALID_RESPONSE,
    });
    mock.enqueue('invalid_duration');
    await expect(service.routePoints([pickup, drop1])).rejects.toMatchObject({
      code: ErrorCodes.ROUTING_INVALID_RESPONSE,
    });
  });
});
