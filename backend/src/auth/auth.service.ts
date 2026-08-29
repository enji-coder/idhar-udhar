import { Injectable } from '@nestjs/common';
import { Queryable } from '../database/queryable';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { SessionRepository } from './session.repository';
import { TokenService } from './token.service';
import {
  AuthContext,
  ProfileRole,
  SessionRow,
  TokenPair,
  profileIdFromRow,
} from './types/auth-context';

@Injectable()
export class AuthService {
  constructor(
    private readonly sessions: SessionRepository,
    private readonly tokens: TokenService,
  ) {}

  async createSession(
    input: {
      identityId: string;
      role: ProfileRole;
      profileId: string;
    },
    db?: Queryable,
  ): Promise<TokenPair> {
    const refresh = this.tokens.generateRefreshToken();
    const expiresAt = this.refreshExpiry();
    const row = await this.sessions.insert(
      {
        identityId: input.identityId,
        role: input.role,
        profileId: input.profileId,
        refreshTokenHash: refresh.hash,
        expiresAt,
      },
      db,
    );
    return this.pairFromRow(row, refresh.raw);
  }

  async rotateRefresh(rawRefreshToken: string): Promise<TokenPair> {
    const currentHash = this.tokens.hashRefreshToken(rawRefreshToken);
    const next = this.tokens.generateRefreshToken();
    const row = await this.sessions.rotateRefresh({
      currentHash,
      nextHash: next.hash,
      nextExpiresAt: this.refreshExpiry(),
    });
    if (!row) {
      throw new ApiError(
        ErrorCodes.INVALID_REFRESH_TOKEN,
        'Refresh token is invalid, expired, or already used',
        401,
      );
    }
    this.assertIdentityActive(row);
    return this.pairFromRow(row, next.raw);
  }

  async revokeSession(sessionId: string): Promise<void> {
    await this.sessions.revoke(sessionId);
  }

  async resolveAccessToken(rawJwt: string): Promise<AuthContext> {
    const claims = this.tokens.verifyAccessToken(rawJwt);
    const row = await this.sessions.findById(claims.sid);
    if (!row) {
      throw new ApiError(
        ErrorCodes.INVALID_TOKEN,
        'Session was not found',
        401,
      );
    }
    if (row.revoked_at) {
      throw new ApiError(
        ErrorCodes.SESSION_REVOKED,
        'Session has been revoked',
        401,
      );
    }
    if (row.expires_at.getTime() <= Date.now()) {
      throw new ApiError(
        ErrorCodes.SESSION_EXPIRED,
        'Session has expired',
        401,
      );
    }
    this.assertIdentityActive(row);
    if (row.identity_id !== claims.sub || row.active_profile_type !== claims.role) {
      throw new ApiError(ErrorCodes.INVALID_TOKEN, 'Access token is invalid', 401);
    }
    const profileId = profileIdFromRow(row);
    if (profileId !== claims.pid) {
      throw new ApiError(ErrorCodes.INVALID_TOKEN, 'Access token is invalid', 401);
    }
    return {
      identityId: row.identity_id,
      sessionId: row.session_id,
      role: row.active_profile_type,
      profileId,
    };
  }

  private pairFromRow(row: SessionRow, refreshToken: string): TokenPair {
    const context: AuthContext = {
      identityId: row.identity_id,
      sessionId: row.session_id,
      role: row.active_profile_type,
      profileId: profileIdFromRow(row),
    };
    return {
      accessToken: this.tokens.issueAccessToken(context),
      refreshToken,
      tokenType: 'Bearer',
      expiresIn: this.tokens.accessTtlSeconds(),
      sessionId: row.session_id,
      role: row.active_profile_type,
    };
  }

  private refreshExpiry(): Date {
    return new Date(Date.now() + this.tokens.refreshTtlSeconds() * 1000);
  }

  private assertIdentityActive(row: SessionRow): void {
    if (row.auth_status !== 'ACTIVE') {
      throw new ApiError(
        ErrorCodes.IDENTITY_INACTIVE,
        'Identity is locked or revoked',
        401,
      );
    }
  }
}
