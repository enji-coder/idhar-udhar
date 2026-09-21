import { Injectable } from '@nestjs/common';
import { ProfileRole } from '../auth/types/auth-context';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';

export type PushDeviceTokenRow = {
  push_device_token_id: string;
  identity_id: string;
  profile_type: ProfileRole;
  customer_profile_id: string | null;
  rider_profile_id: string | null;
  admin_profile_id: string | null;
  fcm_token: string;
  platform: 'ANDROID' | 'IOS' | 'WEB' | null;
  active: boolean;
  last_seen_at: Date;
  deactivated_at: Date | null;
  created_at: Date;
};

const TOKEN_COLUMNS = `
  push_device_token_id,
  identity_id,
  profile_type,
  customer_profile_id,
  rider_profile_id,
  admin_profile_id,
  fcm_token,
  platform,
  active,
  last_seen_at,
  deactivated_at,
  created_at
`;

@Injectable()
export class DeviceTokensRepository {
  constructor(private readonly postgres: PostgresService) {}

  async upsert(input: {
    identityId: string;
    profileType: ProfileRole;
    profileId: string;
    token: string;
    platform: 'ANDROID' | 'IOS' | 'WEB' | null;
  }): Promise<PushDeviceTokenRow> {
    const result = await this.postgres.query<PushDeviceTokenRow>(
      `
      INSERT INTO push_device_tokens (
        identity_id,
        profile_type,
        customer_profile_id,
        rider_profile_id,
        admin_profile_id,
        fcm_token,
        platform,
        active,
        last_seen_at,
        deactivated_at
      )
      VALUES (
        $1, $2,
        CASE WHEN $2 = 'CUSTOMER' THEN $3::uuid ELSE NULL END,
        CASE WHEN $2 = 'RIDER' THEN $3::uuid ELSE NULL END,
        CASE WHEN $2 = 'ADMIN' THEN $3::uuid ELSE NULL END,
        $4, $5, TRUE, now(), NULL
      )
      ON CONFLICT (fcm_token) DO UPDATE
      SET
        identity_id = EXCLUDED.identity_id,
        profile_type = EXCLUDED.profile_type,
        customer_profile_id = EXCLUDED.customer_profile_id,
        rider_profile_id = EXCLUDED.rider_profile_id,
        admin_profile_id = EXCLUDED.admin_profile_id,
        platform = COALESCE(EXCLUDED.platform, push_device_tokens.platform),
        active = TRUE,
        last_seen_at = now(),
        deactivated_at = NULL
      RETURNING ${TOKEN_COLUMNS}
      `,
      [
        input.identityId,
        input.profileType,
        input.profileId,
        input.token,
        input.platform,
      ],
    );
    return result.rows[0];
  }

  async deactivateOwned(input: {
    identityId: string;
    profileType: ProfileRole;
    profileId: string;
    token: string;
  }): Promise<boolean> {
    const profileColumn =
      input.profileType === 'CUSTOMER'
        ? 'customer_profile_id'
        : input.profileType === 'RIDER'
          ? 'rider_profile_id'
          : 'admin_profile_id';
    const result = await this.postgres.query(
      `
      UPDATE push_device_tokens
      SET active = FALSE, deactivated_at = COALESCE(deactivated_at, now())
      WHERE fcm_token = $1
        AND identity_id = $2
        AND profile_type = $3
        AND ${profileColumn} = $4
        AND active = TRUE
      `,
      [input.token, input.identityId, input.profileType, input.profileId],
    );
    return (result.rowCount ?? 0) > 0;
  }

  async listActive(
    identityId: string,
    profileType: ProfileRole,
    db: Queryable = this.postgres,
  ): Promise<Array<{ push_device_token_id: string; fcm_token: string }>> {
    const result = await db.query<{
      push_device_token_id: string;
      fcm_token: string;
    }>(
      `
      SELECT push_device_token_id, fcm_token
      FROM push_device_tokens
      WHERE identity_id = $1
        AND profile_type = $2
        AND active = TRUE
      ORDER BY last_seen_at DESC
      `,
      [identityId, profileType],
    );
    return result.rows;
  }

  async deactivateByIds(
    ids: string[],
    db: Queryable = this.postgres,
  ): Promise<number> {
    if (ids.length === 0) {
      return 0;
    }
    const result = await db.query(
      `
      UPDATE push_device_tokens
      SET active = FALSE, deactivated_at = COALESCE(deactivated_at, now())
      WHERE push_device_token_id = ANY($1::uuid[])
        AND active = TRUE
      `,
      [ids],
    );
    return result.rowCount ?? 0;
  }
}
