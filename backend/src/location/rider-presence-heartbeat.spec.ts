import { ConfigService } from '@nestjs/config';
import { IdentityRepository } from '../auth/identity/identity.repository';
import { LocationService } from './location.service';
import { LocationStore } from './location-store';

const riderId = '11111111-1111-4111-8111-111111111111';

describe('LocationService presence heartbeat', () => {
  const store = {
    backend: 'memory',
    durable: false,
    get: jest.fn(),
    upsert: jest.fn(),
  };
  const identities = {
    findRiderProfile: jest.fn(async () => ({
      rider_profile_id: riderId,
      identity_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    })),
    findRiderGate: jest.fn(),
    touchRiderLastSeen: jest.fn(async () => undefined),
  };
  const config = {
    getOrThrow: () => ({ store: 'memory', presenceStaleMs: 180_000 }),
  } as unknown as ConfigService;
  const service = new LocationService(
    store as unknown as LocationStore,
    identities as unknown as IdentityRepository,
    config,
  );

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('touches last_seen for an Online rider without inventing GPS', async () => {
    identities.findRiderGate.mockResolvedValue({
      rider_profile_id: riderId,
      approval_status: 'APPROVED',
      online_status: 'ONLINE',
      deactivated_at: null,
    });

    const body = await service.heartbeat({
      identityId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      sessionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      role: 'RIDER',
      profileId: riderId,
    });

    expect(identities.touchRiderLastSeen).toHaveBeenCalledWith(riderId);
    expect(store.upsert).not.toHaveBeenCalled();
    expect(body.online_status).toBe('ONLINE');
    expect(body.presence_fresh).toBe(true);
  });

  it('does not revive an explicitly Offline rider', async () => {
    identities.findRiderGate.mockResolvedValue({
      rider_profile_id: riderId,
      approval_status: 'APPROVED',
      online_status: 'OFFLINE',
      deactivated_at: null,
    });

    const body = await service.heartbeat({
      identityId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      sessionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      role: 'RIDER',
      profileId: riderId,
    });

    expect(identities.touchRiderLastSeen).not.toHaveBeenCalled();
    expect(body.online_status).toBe('OFFLINE');
    expect(body.presence_fresh).toBe(false);
  });

  it('marks location stale with the shared presence window', async () => {
    store.get.mockResolvedValue({
      riderProfileId: riderId,
      identityId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      latitude: 23.02,
      longitude: 72.57,
      accuracyMeters: null,
      heading: null,
      speedMps: null,
      recordedAt: new Date(Date.now() - 200_000),
      receivedAt: new Date(Date.now() - 200_000),
    });

    const body = await service.getRiderLocationForConsumer(riderId);
    expect(body.stale).toBe(true);
    expect(body.location?.latitude).toBe(23.02);
  });
});
