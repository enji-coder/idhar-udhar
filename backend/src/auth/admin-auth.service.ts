import { Injectable } from '@nestjs/common';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { AppLogger } from '../common/logger/app-logger';
import { AuthService } from './auth.service';
import { IdentityRepository } from './identity/identity.repository';
import { PasswordService } from './password.service';
import { TokenPair } from './types/auth-context';

@Injectable()
export class AdminAuthService {
  constructor(
    private readonly identities: IdentityRepository,
    private readonly passwords: PasswordService,
    private readonly auth: AuthService,
    private readonly logger: AppLogger,
  ) {}

  async login(email: string, password: string): Promise<TokenPair> {
    const admin = await this.identities.findAdminByEmail(email.trim());
    const dummy =
      '$argon2id$v=19$m=65536,t=3,p=4$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
    const hash = admin?.password_hash ?? dummy;
    const matches = await this.passwords.verify(hash, password);

    if (
      !admin ||
      !admin.active ||
      admin.auth_status !== 'ACTIVE' ||
      !matches
    ) {
      this.logger.info('admin_login_failed');
      throw new ApiError(
        ErrorCodes.INVALID_CREDENTIALS,
        'Invalid email or password',
        401,
      );
    }

    const pair = await this.auth.createSession({
      identityId: admin.identity_id,
      role: 'ADMIN',
      profileId: admin.admin_profile_id,
    });
    this.logger.info('admin_login_succeeded', {
      admin_profile_id: admin.admin_profile_id,
      role: admin.role,
    });
    return pair;
  }
}
