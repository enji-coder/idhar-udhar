import { Injectable } from '@nestjs/common';
import { AuthContext } from '../auth/types/auth-context';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { DeviceTokensRepository } from './device-tokens.repository';

const TOKEN_MIN = 32;
const TOKEN_MAX = 4096;

export type DevicePlatform = 'ANDROID' | 'IOS' | 'WEB';

@Injectable()
export class DeviceTokensService {
  constructor(private readonly tokens: DeviceTokensRepository) {}

  async register(
    auth: AuthContext,
    input: { token: string; platform?: DevicePlatform },
  ) {
    const token = this.requireToken(input.token);
    await this.tokens.upsert({
      identityId: auth.identityId,
      profileType: auth.role,
      profileId: auth.profileId,
      token,
      platform: input.platform ?? null,
    });
    return { registered: true };
  }

  async unregister(auth: AuthContext, tokenRaw: string) {
    const token = this.requireToken(tokenRaw);
    const deactivated = await this.tokens.deactivateOwned({
      identityId: auth.identityId,
      profileType: auth.role,
      profileId: auth.profileId,
      token,
    });
    return { unregistered: deactivated };
  }

  private requireToken(raw: string): string {
    const token = raw.trim();
    if (token.length < TOKEN_MIN || token.length > TOKEN_MAX) {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'Device token is invalid',
        400,
      );
    }
    if (!/^[\x21-\x7E]+$/.test(token)) {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'Device token is invalid',
        400,
      );
    }
    return token;
  }
}
