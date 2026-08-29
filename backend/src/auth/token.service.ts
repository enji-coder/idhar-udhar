import { createHash, randomBytes } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { AppConfig } from '../config/configuration';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { AuthContext, ProfileRole } from './types/auth-context';

export type AccessClaims = {
  sub: string;
  sid: string;
  role: ProfileRole;
  pid: string;
};

@Injectable()
export class TokenService {
  constructor(
    private readonly jwt: JwtService,
    private readonly configService: ConfigService,
  ) {}

  issueAccessToken(context: AuthContext): string {
    const jwt = this.jwtConfig();
    return this.jwt.sign(
      {
        sub: context.identityId,
        sid: context.sessionId,
        role: context.role,
        pid: context.profileId,
      } satisfies AccessClaims,
      {
        secret: jwt.accessSecret,
        issuer: jwt.issuer,
        expiresIn: jwt.accessTtlSeconds,
      },
    );
  }

  verifyAccessToken(token: string): AccessClaims {
    const jwt = this.jwtConfig();
    try {
      const payload = this.jwt.verify<AccessClaims>(token, {
        secret: jwt.accessSecret,
        issuer: jwt.issuer,
      });
      if (!payload.sub || !payload.sid || !payload.role || !payload.pid) {
        throw new ApiError(
          ErrorCodes.INVALID_TOKEN,
          'Access token is invalid',
          401,
        );
      }
      return payload;
    } catch (err) {
      if (err instanceof ApiError) {
        throw err;
      }
      throw new ApiError(
        ErrorCodes.INVALID_TOKEN,
        'Access token is invalid or expired',
        401,
      );
    }
  }

  generateRefreshToken(): { raw: string; hash: string } {
    const raw = randomBytes(32).toString('base64url');
    return { raw, hash: this.hashRefreshToken(raw) };
  }

  hashRefreshToken(raw: string): string {
    const pepper = this.jwtConfig().refreshPepper;
    return createHash('sha256').update(`${pepper}:${raw}`).digest('hex');
  }

  accessTtlSeconds(): number {
    return this.jwtConfig().accessTtlSeconds;
  }

  refreshTtlSeconds(): number {
    return this.jwtConfig().refreshTtlSeconds;
  }

  private jwtConfig(): AppConfig['jwt'] {
    return this.configService.getOrThrow<AppConfig['jwt']>('jwt');
  }
}
