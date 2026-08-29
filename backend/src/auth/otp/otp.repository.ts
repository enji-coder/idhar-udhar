import { Injectable } from '@nestjs/common';
import { Queryable } from '../../database/queryable';
import { PostgresService } from '../../database/postgres.service';

export type OtpChallengeRow = {
  otp_challenge_id: string;
  phone_normalized: string;
  identity_id: string | null;
  code_hash: string;
  expires_at: Date;
  attempt_count: number;
  max_attempts: number | null;
  cooldown_until: Date | null;
  ip: string | null;
  consumed_at: Date | null;
  created_at: Date;
};

@Injectable()
export class OtpRepository {
  constructor(private readonly postgres: PostgresService) {}

  async insert(
    input: {
      phoneNormalized: string;
      identityId: string | null;
      codeHash: string;
      expiresAt: Date;
      maxAttempts: number;
      cooldownUntil: Date;
      ip: string | null;
    },
    db: Queryable = this.postgres,
  ): Promise<OtpChallengeRow> {
    const result = await db.query<OtpChallengeRow>(
      `
      INSERT INTO otp_challenges (
        phone_normalized,
        identity_id,
        code_hash,
        expires_at,
        max_attempts,
        cooldown_until,
        ip
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING *
      `,
      [
        input.phoneNormalized,
        input.identityId,
        input.codeHash,
        input.expiresAt,
        input.maxAttempts,
        input.cooldownUntil,
        input.ip,
      ],
    );
    return result.rows[0];
  }

  async consumeOpenChallenges(
    phoneNormalized: string,
    db: Queryable = this.postgres,
  ): Promise<void> {
    await db.query(
      `
      UPDATE otp_challenges
      SET consumed_at = now()
      WHERE phone_normalized = $1
        AND consumed_at IS NULL
      `,
      [phoneNormalized],
    );
  }

  async latestForPhone(
    phoneNormalized: string,
    db: Queryable = this.postgres,
  ): Promise<OtpChallengeRow | null> {
    const result = await db.query<OtpChallengeRow>(
      `
      SELECT *
      FROM otp_challenges
      WHERE phone_normalized = $1
      ORDER BY created_at DESC
      LIMIT 1
      `,
      [phoneNormalized],
    );
    return result.rows[0] ?? null;
  }

  async lockLatestForPhone(
    phoneNormalized: string,
    db: Queryable,
  ): Promise<OtpChallengeRow | null> {
    const result = await db.query<OtpChallengeRow>(
      `
      SELECT *
      FROM otp_challenges
      WHERE phone_normalized = $1
      ORDER BY created_at DESC
      LIMIT 1
      FOR UPDATE
      `,
      [phoneNormalized],
    );
    return result.rows[0] ?? null;
  }

  async incrementAttempts(
    challengeId: string,
    db: Queryable,
  ): Promise<number> {
    const result = await db.query<{ attempt_count: number }>(
      `
      UPDATE otp_challenges
      SET attempt_count = attempt_count + 1
      WHERE otp_challenge_id = $1
      RETURNING attempt_count
      `,
      [challengeId],
    );
    return result.rows[0].attempt_count;
  }

  async consume(challengeId: string, db: Queryable): Promise<void> {
    await db.query(
      `
      UPDATE otp_challenges
      SET consumed_at = now()
      WHERE otp_challenge_id = $1
        AND consumed_at IS NULL
      `,
      [challengeId],
    );
  }

  async countRecentByIp(ip: string, since: Date): Promise<number> {
    const result = await this.postgres.query<{ count: string }>(
      `
      SELECT count(*)::text AS count
      FROM otp_challenges
      WHERE ip = $1
        AND created_at >= $2
      `,
      [ip, since],
    );
    return Number.parseInt(result.rows[0]?.count ?? '0', 10);
  }
}
