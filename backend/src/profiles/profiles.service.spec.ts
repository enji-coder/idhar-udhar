import { ConfigService } from '@nestjs/config';
import { ApiError } from '../common/errors/api-error';
import { AuthContext } from '../auth/types/auth-context';
import { IdentityRepository } from '../auth/identity/identity.repository';
import { ProfilesService } from './profiles.service';

const riderId = '11111111-1111-4111-8111-111111111111';

function riderAuth(): AuthContext {
  return {
    identityId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    sessionId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    role: 'RIDER',
    profileId: riderId,
  };
}

function presenceConfig(onlineTimeEnabled = false): ConfigService {
  return {
    getOrThrow: () => ({
      presenceStaleMs: 180_000,
      store: 'memory',
      onlineTimeEnabled,
    }),
  } as unknown as ConfigService;
}

describe('ProfilesService rider availability', () => {
  const identities = {
    findRiderProfile: jest.fn(async () => ({
      rider_profile_id: riderId,
      identity_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    })),
    findRiderGate: jest.fn(),
    updateRiderOnlineStatus: jest.fn(),
    updateRiderLanguage: jest.fn(),
    findAdminProfile: jest.fn(),
    deactivateRider: jest.fn(),
  };
  const service = new ProfilesService(
    identities as unknown as IdentityRepository,
    presenceConfig(),
  );

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('refuses to put a pending rider online', async () => {
    identities.findRiderGate.mockResolvedValue({
      rider_profile_id: riderId,
      approval_status: 'PENDING',
      online_status: 'OFFLINE',
      deactivated_at: null,
    });

    await expect(service.setRiderAvailability(riderAuth(), true)).rejects.toBeInstanceOf(
      ApiError,
    );
    await expect(service.setRiderAvailability(riderAuth(), true)).rejects.toMatchObject({
      code: 'RIDER_NOT_ELIGIBLE',
    });
    expect(identities.updateRiderOnlineStatus).not.toHaveBeenCalled();
  });

  it('lets a pending rider go offline', async () => {
    identities.findRiderGate.mockResolvedValue({
      rider_profile_id: riderId,
      approval_status: 'PENDING',
      online_status: 'ONLINE',
      deactivated_at: null,
    });
    identities.updateRiderOnlineStatus.mockResolvedValue({
      approval_status: 'PENDING',
      online_status: 'OFFLINE',
    });

    const result = await service.setRiderAvailability(riderAuth(), false);

    expect(identities.updateRiderOnlineStatus).toHaveBeenCalledWith(
      riderId,
      'OFFLINE',
      180_000,
    );
    expect(result.online_status).toBe('OFFLINE');
  });

  it('lets an approved rider go online', async () => {
    identities.findRiderGate.mockResolvedValue({
      rider_profile_id: riderId,
      approval_status: 'APPROVED',
      online_status: 'OFFLINE',
      deactivated_at: null,
    });
    identities.updateRiderOnlineStatus.mockResolvedValue({
      approval_status: 'APPROVED',
      online_status: 'ONLINE',
    });

    const result = await service.setRiderAvailability(riderAuth(), true);

    expect(result.online_status).toBe('ONLINE');
  });

  it('blocks going online when the wallet is financially suspended', async () => {
    const walletCod = {
      assertCanAcceptService: jest.fn(async () => {
        throw new ApiError(
          'RIDER_NOT_ELIGIBLE',
          'Wallet balance is -108.60. Recharge at least 8.61 to resume service.',
          409,
        );
      }),
    };
    const gated = new ProfilesService(
      identities as unknown as IdentityRepository,
      presenceConfig(),
      walletCod as never,
    );
    identities.findRiderGate.mockResolvedValue({
      rider_profile_id: riderId,
      approval_status: 'APPROVED',
      online_status: 'OFFLINE',
      deactivated_at: null,
    });

    await expect(gated.setRiderAvailability(riderAuth(), true)).rejects.toMatchObject({
      code: 'RIDER_NOT_ELIGIBLE',
      message: 'Wallet balance is -108.60. Recharge at least 8.61 to resume service.',
    });
    expect(identities.updateRiderOnlineStatus).not.toHaveBeenCalled();
  });

  it('refuses a deactivated rider', async () => {
    identities.findRiderGate.mockResolvedValue({
      rider_profile_id: riderId,
      approval_status: 'APPROVED',
      online_status: 'OFFLINE',
      deactivated_at: new Date(),
    });

    await expect(service.setRiderAvailability(riderAuth(), true)).rejects.toMatchObject({
      code: 'RIDER_NOT_ELIGIBLE',
    });
    expect(identities.updateRiderOnlineStatus).not.toHaveBeenCalled();
  });

  it('updates only the signed-in rider language and leaves approval untouched', async () => {
    identities.updateRiderLanguage.mockResolvedValue({
      preferred_language: 'hi',
      approval_status: 'APPROVED',
      online_status: 'ONLINE',
    });

    const result = await service.setRiderLanguage(riderAuth(), 'hi');

    expect(identities.updateRiderLanguage).toHaveBeenCalledWith(riderId, 'hi');
    expect(result).toEqual({
      preferred_language: 'hi',
      approval_status: 'APPROVED',
      online_status: 'ONLINE',
    });
  });

  it('soft-deletes an active rider and keeps the stored deactivation', async () => {
    const adminId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
    identities.findAdminProfile.mockResolvedValue({
      admin_profile_id: adminId,
      active: true,
    });
    const deactivatedAt = new Date('2026-10-07T10:00:00.000Z');
    identities.deactivateRider.mockResolvedValue({
      rider_profile_id: riderId,
      deactivated_at: deactivatedAt,
      online_status: 'OFFLINE',
    });

    const result = await service.deactivateRider(
      {
        identityId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        sessionId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        role: 'ADMIN',
        profileId: adminId,
      },
      riderId,
    );

    expect(identities.deactivateRider).toHaveBeenCalledWith(riderId);
    expect(result).toEqual({
      deleted: true,
      rider_profile_id: riderId,
      deactivated_at: deactivatedAt,
      online_status: 'OFFLINE',
    });
  });

  it('does not pretend a missing rider was deleted', async () => {
    const adminId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
    identities.findAdminProfile.mockResolvedValue({
      admin_profile_id: adminId,
      active: true,
    });
    identities.deactivateRider.mockResolvedValue(null);

    await expect(
      service.deactivateRider(
        {
          identityId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
          sessionId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
          role: 'ADMIN',
          profileId: adminId,
        },
        riderId,
      ),
    ).rejects.toMatchObject({ code: 'NOT_FOUND', status: 404 });
  });

  it('refuses rider deletion without an admin role', async () => {
    await expect(service.deactivateRider(riderAuth(), riderId)).rejects.toMatchObject({
      code: 'FORBIDDEN',
    });
    expect(identities.deactivateRider).not.toHaveBeenCalled();
  });

  it('refuses a non-rider language update', async () => {
    await expect(
      service.setRiderLanguage({ ...riderAuth(), role: 'CUSTOMER' }, 'en'),
    ).rejects.toMatchObject({ code: 'FORBIDDEN' });
    expect(identities.updateRiderLanguage).not.toHaveBeenCalled();
  });
});

describe('ProfilesService Admin online presence', () => {
  const service = new ProfilesService(
    {} as unknown as IdentityRepository,
    presenceConfig(),
  );

  function serialize(row: Record<string, unknown>) {
    return (
      service as unknown as {
        serializeRiderDirectory: (input: Record<string, unknown>) => {
          online_status: string;
        };
      }
    ).serializeRiderDirectory(row);
  }

  it('reports ONLINE only while last_seen is fresh', () => {
    const base = {
      rider_profile_id: riderId,
      identity_id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      phone_normalized: '919999999999',
      onboarding_kyc_status: 'PENDING',
      approval_status: 'APPROVED',
      online_status: 'ONLINE',
      cod_operational_status: 'CLEAR',
      home_city_id: null,
      home_zone_id: null,
      city_code: null,
      zone_name: null,
    };

    expect(serialize({ ...base, last_seen_at: new Date() }).online_status).toBe(
      'ONLINE',
    );
    expect(
      serialize({
        ...base,
        last_seen_at: new Date(Date.now() - 180_000 - 1),
      }).online_status,
    ).toBe('OFFLINE');
  });
});

describe('ProfilesService online time access', () => {
  const adminId = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
  const identities = {
    findRiderProfile: jest.fn(),
    ensureRiderProfile: jest.fn(),
    expireStaleOnlineRiders: jest.fn(async () => 0),
    listOnlineSessionsOverlapping: jest.fn(async () => []),
    findAdminProfile: jest.fn(),
  };
  const service = new ProfilesService(
    identities as unknown as IdentityRepository,
    presenceConfig(),
  );

  beforeEach(() => {
    jest.clearAllMocks();
    identities.expireStaleOnlineRiders.mockResolvedValue(0);
    identities.listOnlineSessionsOverlapping.mockResolvedValue([]);
  });

  function customerAuth(): AuthContext {
    return {
      identityId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      sessionId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      role: 'CUSTOMER',
      profileId: '99999999-9999-4999-8999-999999999999',
    };
  }

  function adminAuth(): AuthContext {
    return {
      identityId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      sessionId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
      role: 'ADMIN',
      profileId: adminId,
    };
  }

  it('does not read sessions while online time is disabled', async () => {
    identities.findRiderProfile.mockResolvedValue({ rider_profile_id: riderId });

    await expect(service.riderOnlineTime(riderAuth(), '2026-11-06')).rejects.toMatchObject({
      code: 'NOT_FOUND',
    });
    expect(identities.findRiderProfile).not.toHaveBeenCalled();
    expect(identities.expireStaleOnlineRiders).not.toHaveBeenCalled();
    expect(identities.listOnlineSessionsOverlapping).not.toHaveBeenCalled();
  });

  it('does not read the admin report while online time is disabled', async () => {
    identities.findAdminProfile.mockResolvedValue({
      admin_profile_id: adminId,
      active: true,
    });

    await expect(service.adminRiderOnlineTime(adminAuth(), '2026-11-06')).rejects.toMatchObject({
      code: 'NOT_FOUND',
    });
    expect(identities.expireStaleOnlineRiders).not.toHaveBeenCalled();
    expect(identities.listOnlineSessionsOverlapping).not.toHaveBeenCalled();
  });

  it('refuses a non-rider before reading sessions', async () => {
    await expect(service.riderOnlineTime(customerAuth())).rejects.toMatchObject({
      code: 'FORBIDDEN',
    });
    expect(identities.findRiderProfile).not.toHaveBeenCalled();
    expect(identities.listOnlineSessionsOverlapping).not.toHaveBeenCalled();
  });

  it('lists only the signed-in rider inside the Kolkata day', async () => {
    identities.findRiderProfile.mockResolvedValue({ rider_profile_id: riderId });
    const enabled = new ProfilesService(
      identities as unknown as IdentityRepository,
      presenceConfig(true),
    );

    const report = await enabled.riderOnlineTime(riderAuth(), '2026-11-06');

    expect(identities.listOnlineSessionsOverlapping).toHaveBeenCalledWith(
      '2026-11-05T18:30:00.000Z',
      '2026-11-06T18:30:00.000Z',
      riderId,
      '',
    );
    expect(report.date).toBe('2026-11-06');
    expect(report.time_zone).toBe('Asia/Kolkata');
    expect(report.total_seconds).toBe(0);
  });

  it('rejects an invalid day before expiring presence', async () => {
    identities.findRiderProfile.mockResolvedValue({ rider_profile_id: riderId });
    const enabled = new ProfilesService(
      identities as unknown as IdentityRepository,
      presenceConfig(true),
    );

    await expect(
      enabled.riderOnlineTime(riderAuth(), '06-11-2026'),
    ).rejects.toMatchObject({ code: 'REPORT_RANGE_INVALID' });
    expect(identities.expireStaleOnlineRiders).not.toHaveBeenCalled();
  });

  it('refuses a rider on the admin report', async () => {
    await expect(
      service.adminRiderOnlineTime(riderAuth(), '2026-11-06'),
    ).rejects.toMatchObject({ code: 'FORBIDDEN' });
    expect(identities.listOnlineSessionsOverlapping).not.toHaveBeenCalled();
  });

  it('refuses an inactive admin profile', async () => {
    identities.findAdminProfile.mockResolvedValue({
      admin_profile_id: adminId,
      active: false,
    });

    await expect(service.adminRiderOnlineTime(adminAuth())).rejects.toMatchObject({
      code: 'FORBIDDEN',
    });
    expect(identities.listOnlineSessionsOverlapping).not.toHaveBeenCalled();
  });
});