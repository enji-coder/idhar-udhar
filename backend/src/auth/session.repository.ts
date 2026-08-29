import { Injectable } from '@nestjs/common';
import { PostgresService } from '../database/postgres.service';
import { Queryable } from '../database/queryable';
import { ProfileRole, SessionRow } from './types/auth-context';

@Injectable()
export class SessionRepository {
  constructor(private readonly postgres: PostgresService) {}

  async insert(
    input: {
      identityId: string;
      role: ProfileRole;
      profileId: string;
      refreshTokenHash: string;
      expiresAt: Date;
    },
    db?: Queryable,
  ): Promise<SessionRow> {
    const conn = db ?? this.postgres;
    const columns = this.profileColumns(input.role, input.profileId);
    const result = await conn.query<SessionRow>(
      `
      INSERT INTO sessions (
        identity_id,
        active_profile_type,
        customer_profile_id,
        rider_profile_id,
        admin_profile_id,
        refresh_token_hash,
        expires_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING
        session_id,
        identity_id,
        active_profile_type,
        customer_profile_id,
        rider_profile_id,
        admin_profile_id,
        refresh_token_hash,
        expires_at,
        revoked_at,
        (SELECT auth_status FROM identities WHERE identity_id = $1) AS auth_status
      `,
      [
        input.identityId,
        input.role,
        columns.customer,
        columns.rider,
        columns.admin,
        input.refreshTokenHash,
        input.expiresAt,
      ],
    );
    return result.rows[0];
  }

  async findById(sessionId: string): Promise<SessionRow | null> {
    const result = await this.postgres.query<SessionRow>(
      `
      SELECT
        s.session_id,
        s.identity_id,
        s.active_profile_type,
        s.customer_profile_id,
        s.rider_profile_id,
        s.admin_profile_id,
        s.refresh_token_hash,
        s.expires_at,
        s.revoked_at,
        i.auth_status
      FROM sessions s
      JOIN identities i ON i.identity_id = s.identity_id
      WHERE s.session_id = $1
      `,
      [sessionId],
    );
    return result.rows[0] ?? null;
  }

  async rotateRefresh(input: {
    currentHash: string;
    nextHash: string;
    nextExpiresAt: Date;
  }): Promise<SessionRow | null> {
    const result = await this.postgres.query<SessionRow>(
      `
      UPDATE sessions s
      SET
        refresh_token_hash = $2,
        expires_at = $3
      FROM identities i
      WHERE s.refresh_token_hash = $1
        AND s.revoked_at IS NULL
        AND s.expires_at > now()
        AND i.identity_id = s.identity_id
      RETURNING
        s.session_id,
        s.identity_id,
        s.active_profile_type,
        s.customer_profile_id,
        s.rider_profile_id,
        s.admin_profile_id,
        s.refresh_token_hash,
        s.expires_at,
        s.revoked_at,
        i.auth_status
      `,
      [input.currentHash, input.nextHash, input.nextExpiresAt],
    );
    return result.rows[0] ?? null;
  }

  async revoke(sessionId: string): Promise<boolean> {
    const result = await this.postgres.query(
      `
      UPDATE sessions
      SET revoked_at = now()
      WHERE session_id = $1
        AND revoked_at IS NULL
      `,
      [sessionId],
    );
    return (result.rowCount ?? 0) > 0;
  }

  private profileColumns(
    role: ProfileRole,
    profileId: string,
  ): {
    customer: string | null;
    rider: string | null;
    admin: string | null;
  } {
    return {
      customer: role === 'CUSTOMER' ? profileId : null,
      rider: role === 'RIDER' ? profileId : null,
      admin: role === 'ADMIN' ? profileId : null,
    };
  }
}
