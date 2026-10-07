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
  const service = new ProfilesService(identities as unknown as IdentityRepository);

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

    expect(identities.updateRiderOnlineStatus).toHaveBeenCalledWith(riderId, 'OFFLINE');
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