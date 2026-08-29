import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiError } from '../../common/errors/api-error';
import { ErrorCodes } from '../../common/errors/error-codes';
import { AppLogger } from '../../common/logger/app-logger';
import { AppConfig } from '../../config/configuration';
import { PostgresService } from '../../database/postgres.service';
import { Queryable } from '../../database/queryable';
import { AuthService } from '../auth.service';
import { IdentityRepository } from '../identity/identity.repository';
import { maskPhone, normalizePhone } from '../phone';
import { ProfileRole, TokenPair } from '../types/auth-context';
import { OTP_DELIVERY, OtpDeliveryProvider } from './otp-delivery';
import { OtpHashService } from './otp-hash.service';
import { OtpChallengeRow, OtpRepository } from './otp.repository';

export type MarketplaceActor = Extract<ProfileRole, 'CUSTOMER' | 'RIDER'>;

export type OtpVerifyResult = TokenPair & {
  identityId: string;
  profileId: string;
};

@Injectable()
export class OtpService {
  constructor(
    private readonly configService: ConfigService,
    private readonly postgres: PostgresService,
    private readonly otps: OtpRepository,
    private readonly hashes: OtpHashService,
    private readonly identities: IdentityRepository,
    private readonly auth: AuthService,
    private readonly logger: AppLogger,
    @Inject(OTP_DELIVERY) private readonly delivery: OtpDeliveryProvider,
  ) {}

  async request(input: {
    phone: string;
    actorType: MarketplaceActor;
    ip?: string;
  }): Promise<{
    requested: true;
    expires_in_seconds: number;
    cooldown_seconds: number;
    delivery: 'capture' | 'unconfigured';
  }> {
    const phoneNormalized = normalizePhone(input.phone);
    const otp = this.otpConfig();

    if (input.ip) {
      const since = new Date(Date.now() - 60 * 60 * 1000);
      const recent = await this.otps.countRecentByIp(input.ip, since);
      if (recent >= otp.maxRequestsPerHour) {
        throw new ApiError(
          ErrorCodes.OTP_RATE_LIMITED,
          'Too many OTP requests from this network. Try again later.',
          429,
        );
      }
    }

    const latest = await this.otps.latestForPhone(phoneNormalized);
    if (latest?.cooldown_until && latest.cooldown_until.getTime() > Date.now()) {
      throw new ApiError(
        ErrorCodes.OTP_COOLDOWN,
        'Please wait before requesting another code.',
        429,
      );
    }

    const existing = await this.identities.findByPhone(phoneNormalized);
    if (existing && existing.auth_status !== 'ACTIVE') {
      throw new ApiError(
        ErrorCodes.IDENTITY_INACTIVE,
        'Identity is locked or revoked',
        401,
      );
    }

    const code = this.hashes.generateCode();
    const codeHash = this.hashes.hash(phoneNormalized, code);
    const now = Date.now();
    const expiresAt = new Date(now + otp.ttlSeconds * 1000);
    const cooldownUntil = new Date(now + otp.cooldownSeconds * 1000);

    await this.postgres.transaction(async (tx) => {
      await this.otps.consumeOpenChallenges(phoneNormalized, tx);
      await this.otps.insert(
        {
          phoneNormalized,
          identityId: existing?.identity_id ?? null,
          codeHash,
          expiresAt,
          maxAttempts: otp.maxAttempts,
          cooldownUntil,
          ip: input.ip ?? null,
        },
        tx,
      );
    });

    await this.delivery.send({ phoneNormalized, code });
    this.logger.info('otp_challenge_created', {
      phone_suffix: maskPhone(phoneNormalized),
      actor_type: input.actorType,
      delivery: this.delivery.mode,
    });

    return {
      requested: true,
      expires_in_seconds: otp.ttlSeconds,
      cooldown_seconds: otp.cooldownSeconds,
      delivery: this.delivery.mode,
    };
  }

  async verify(input: {
    phone: string;
    actorType: MarketplaceActor;
    code: string;
  }): Promise<OtpVerifyResult> {
    const phoneNormalized = normalizePhone(input.phone);
    const code = input.code.trim();

    const outcome = await this.postgres.transaction(async (tx) => {
      const challenge = await this.otps.lockLatestForPhone(phoneNormalized, tx);
      this.assertChallengeUsable(challenge);

      const maxAttempts =
        challenge.max_attempts && challenge.max_attempts > 0
          ? challenge.max_attempts
          : this.otpConfig().maxAttempts;

      if (challenge.attempt_count >= maxAttempts) {
        return { kind: 'exceeded' as const };
      }

      if (!this.hashes.matches(phoneNormalized, code, challenge.code_hash)) {
        const attempts = await this.otps.incrementAttempts(
          challenge.otp_challenge_id,
          tx,
        );
        return {
          kind: 'invalid' as const,
          exceeded: attempts >= maxAttempts,
        };
      }

      await this.otps.consume(challenge.otp_challenge_id, tx);
      const resolved = await this.resolveMarketplaceProfile(
        phoneNormalized,
        input.actorType,
        tx,
      );
      const pair = await this.auth.createSession(
        {
          identityId: resolved.identityId,
          role: input.actorType,
          profileId: resolved.profileId,
        },
        tx,
      );
      return {
        kind: 'ok' as const,
        result: {
          ...pair,
          identityId: resolved.identityId,
          profileId: resolved.profileId,
        },
      };
    });

    if (outcome.kind === 'exceeded' || (outcome.kind === 'invalid' && outcome.exceeded)) {
      throw new ApiError(
        ErrorCodes.OTP_ATTEMPTS_EXCEEDED,
        'Too many verification attempts for this code.',
        401,
      );
    }
    if (outcome.kind === 'invalid') {
      throw new ApiError(
        ErrorCodes.OTP_INVALID,
        'Invalid verification code',
        401,
      );
    }

    this.logger.info('otp_verified', {
      phone_suffix: maskPhone(phoneNormalized),
      actor_type: input.actorType,
      session_id: outcome.result.sessionId,
    });

    return outcome.result;
  }

  private assertChallengeUsable(
    challenge: OtpChallengeRow | null,
  ): asserts challenge is OtpChallengeRow {
    if (!challenge) {
      throw new ApiError(
        ErrorCodes.OTP_NOT_FOUND,
        'No verification challenge was found for this phone.',
        401,
      );
    }
    if (challenge.consumed_at) {
      throw new ApiError(
        ErrorCodes.OTP_ALREADY_USED,
        'This verification code has already been used.',
        401,
      );
    }
    if (challenge.expires_at.getTime() <= Date.now()) {
      throw new ApiError(
        ErrorCodes.OTP_EXPIRED,
        'This verification code has expired.',
        401,
      );
    }
  }

  private async resolveMarketplaceProfile(
    phoneNormalized: string,
    actorType: MarketplaceActor,
    tx: Queryable,
  ): Promise<{ identityId: string; profileId: string }> {
    const identity = await this.identities.insertPhoneIdentity(
      phoneNormalized,
      tx,
    );
    if (identity.auth_status !== 'ACTIVE') {
      throw new ApiError(
        ErrorCodes.IDENTITY_INACTIVE,
        'Identity is locked or revoked',
        401,
      );
    }
    if (actorType === 'CUSTOMER') {
      const profile = await this.identities.ensureCustomerProfile(
        identity.identity_id,
        tx,
      );
      return {
        identityId: identity.identity_id,
        profileId: profile.customer_profile_id,
      };
    }
    const profile = await this.identities.ensureRiderProfile(
      identity.identity_id,
      tx,
    );
    return {
      identityId: identity.identity_id,
      profileId: profile.rider_profile_id,
    };
  }

  private otpConfig(): AppConfig['otp'] {
    return this.configService.getOrThrow<AppConfig['otp']>('otp');
  }
}
