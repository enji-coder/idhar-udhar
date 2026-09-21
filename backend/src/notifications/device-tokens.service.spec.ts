import { AuthContext } from '../auth/types/auth-context';
import { DeviceTokensRepository } from './device-tokens.repository';
import { DeviceTokensService } from './device-tokens.service';

const token = 'fcm-token-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

function customerAuth(): AuthContext {
  return {
    identityId: '11111111-1111-4111-8111-111111111111',
    sessionId: '22222222-2222-4222-8222-222222222222',
    role: 'CUSTOMER',
    profileId: '33333333-3333-4333-8333-333333333333',
  };
}

function riderAuth(): AuthContext {
  return {
    identityId: '44444444-4444-4444-8444-444444444444',
    sessionId: '55555555-5555-4555-8555-555555555555',
    role: 'RIDER',
    profileId: '66666666-6666-4666-8666-666666666666',
  };
}

describe('DeviceTokensService', () => {
  const tokens = {
    upsert: jest.fn(),
    deactivateOwned: jest.fn(),
  };
  const service = new DeviceTokensService(
    tokens as unknown as DeviceTokensRepository,
  );

  beforeEach(() => {
    jest.clearAllMocks();
    tokens.upsert.mockResolvedValue({});
    tokens.deactivateOwned.mockResolvedValue(true);
  });

  it('registers a token for the authenticated profile only', async () => {
    const result = await service.register(customerAuth(), {
      token,
      platform: 'ANDROID',
    });
    expect(result).toEqual({ registered: true });
    expect(tokens.upsert).toHaveBeenCalledWith({
      identityId: customerAuth().identityId,
      profileType: 'CUSTOMER',
      profileId: customerAuth().profileId,
      token,
      platform: 'ANDROID',
    });
    expect(JSON.stringify(result)).not.toContain(token);
  });

  it('does not let a rider unregister another account token', async () => {
    tokens.deactivateOwned.mockResolvedValue(false);
    const result = await service.unregister(riderAuth(), token);
    expect(result).toEqual({ unregistered: false });
    expect(tokens.deactivateOwned).toHaveBeenCalledWith({
      identityId: riderAuth().identityId,
      profileType: 'RIDER',
      profileId: riderAuth().profileId,
      token,
    });
  });

  it('rejects a short token without storing it', async () => {
    await expect(
      service.register(customerAuth(), { token: 'short' }),
    ).rejects.toMatchObject({ code: 'VALIDATION_ERROR', status: 400 });
    expect(tokens.upsert).not.toHaveBeenCalled();
  });
});
