import { Injectable } from '@nestjs/common';
import { ProfileRole } from '../auth/types/auth-context';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';

export type NotificationRow = {
  notification_id: string;
  recipient_identity_id: string;
  recipient_profile_type: ProfileRole | null;
  customer_profile_id: string | null;
  rider_profile_id: string | null;
  admin_profile_id: string | null;
  type: string;
  title: string | null;
  body: string;
  order_id: string | null;
  read_at: Date | null;
  created_at: Date;
};

export type NotificationDeliveryRow = {
  notification_delivery_id: string;
  notification_id: string;
  channel: 'IN_APP' | 'PUSH';
  status: 'PENDING' | 'SENT' | 'FAILED' | 'SKIPPED';
  attempt_count: number;
  last_attempt_at: Date | null;
  last_error: string | null;
  provider_message_id: string | null;
  created_at: Date;
};

export type NotificationPreferenceRow = {
  notification_preference_id: string;
  identity_id: string;
  in_app_enabled: boolean;
  push_enabled: boolean;
  created_at: Date;
  updated_at: Date;
};

export type RecipientRef = {
  identityId: string;
  profileType: ProfileRole;
  profileId: string;
};

export type ClaimedDelivery = NotificationDeliveryRow & {
  recipient_identity_id: string;
  type: string;
  title: string | null;
  body: string;
  order_id: string | null;
};

const NOTIFICATION_COLUMNS = `
  notification_id,
  recipient_identity_id,
  recipient_profile_type,
  customer_profile_id,
  rider_profile_id,
  admin_profile_id,
  type,
  title,
  body,
  order_id,
  read_at,
  created_at
`;

const DELIVERY_COLUMNS = `
  notification_delivery_id,
  notification_id,
  channel,
  status,
  attempt_count,
  last_attempt_at,
  last_error,
  provider_message_id,
  created_at
`;

@Injectable()
export class NotificationsRepository {
  constructor(private readonly postgres: PostgresService) {}

  async findById(
    notificationId: string,
    db: Queryable = this.postgres,
  ): Promise<NotificationRow | null> {
    const result = await db.query<NotificationRow>(
      `
      SELECT ${NOTIFICATION_COLUMNS}
      FROM notifications
      WHERE notification_id = $1
      `,
      [notificationId],
    );
    return result.rows[0] ?? null;
  }

  async insertNotification(
    input: {
      notificationId: string;
      identityId: string;
      profileType: ProfileRole;
      profileId: string;
      type: string;
      title: string;
      body: string;
      orderId: string | null;
    },
    db: Queryable,
  ): Promise<{ row: NotificationRow; inserted: boolean }> {
    const result = await db.query<NotificationRow>(
      `
      INSERT INTO notifications (
        notification_id,
        recipient_identity_id,
        recipient_profile_type,
        customer_profile_id,
        rider_profile_id,
        admin_profile_id,
        type,
        title,
        body,
        order_id
      )
      VALUES (
        $1, $2, $3,
        CASE WHEN $3 = 'CUSTOMER' THEN $4::uuid ELSE NULL END,
        CASE WHEN $3 = 'RIDER' THEN $4::uuid ELSE NULL END,
        CASE WHEN $3 = 'ADMIN' THEN $4::uuid ELSE NULL END,
        $5, $6, $7, $8
      )
      ON CONFLICT (notification_id) DO NOTHING
      RETURNING ${NOTIFICATION_COLUMNS}
      `,
      [
        input.notificationId,
        input.identityId,
        input.profileType,
        input.profileId,
        input.type,
        input.title,
        input.body,
        input.orderId,
      ],
    );
    if (result.rows[0]) {
      return { row: result.rows[0], inserted: true };
    }
    const existing = await this.findById(input.notificationId, db);
    if (!existing) {
      throw new Error('Notification insert conflict but row was not found');
    }
    return { row: existing, inserted: false };
  }

  async insertDelivery(
    input: {
      notificationId: string;
      channel: 'IN_APP' | 'PUSH';
      status: 'PENDING' | 'SENT' | 'FAILED' | 'SKIPPED';
    },
    db: Queryable,
  ): Promise<NotificationDeliveryRow> {
    const result = await db.query<NotificationDeliveryRow>(
      `
      INSERT INTO notification_deliveries (
        notification_id, channel, status
      )
      VALUES ($1, $2, $3)
      ON CONFLICT (notification_id, channel) DO NOTHING
      RETURNING ${DELIVERY_COLUMNS}
      `,
      [input.notificationId, input.channel, input.status],
    );
    if (result.rows[0]) {
      return result.rows[0];
    }
    const existing = await this.findDelivery(
      input.notificationId,
      input.channel,
      db,
    );
    if (!existing) {
      throw new Error('Delivery insert conflict but row was not found');
    }
    return existing;
  }

  async findDelivery(
    notificationId: string,
    channel: 'IN_APP' | 'PUSH',
    db: Queryable = this.postgres,
  ): Promise<NotificationDeliveryRow | null> {
    const result = await db.query<NotificationDeliveryRow>(
      `
      SELECT ${DELIVERY_COLUMNS}
      FROM notification_deliveries
      WHERE notification_id = $1 AND channel = $2
      `,
      [notificationId, channel],
    );
    return result.rows[0] ?? null;
  }

  async listDeliveries(
    notificationId: string,
    db: Queryable = this.postgres,
  ): Promise<NotificationDeliveryRow[]> {
    const result = await db.query<NotificationDeliveryRow>(
      `
      SELECT ${DELIVERY_COLUMNS}
      FROM notification_deliveries
      WHERE notification_id = $1
      ORDER BY channel
      `,
      [notificationId],
    );
    return result.rows;
  }

  async listForSession(
    input: {
      identityId: string;
      role: ProfileRole;
      profileId: string;
      limit: number;
      cursorCreatedAt?: Date;
      cursorId?: string;
    },
    db: Queryable = this.postgres,
  ): Promise<NotificationRow[]> {
    const profileFilter = this.profileFilter(input.role);
    const cursorSql =
      input.cursorCreatedAt && input.cursorId
        ? `AND (created_at, notification_id) < ($5::timestamptz, $6::uuid)`
        : '';
    const params: unknown[] = [
      input.identityId,
      input.role,
      input.profileId,
      input.limit,
    ];
    if (input.cursorCreatedAt && input.cursorId) {
      params.push(input.cursorCreatedAt.toISOString(), input.cursorId);
    }
    const result = await db.query<NotificationRow>(
      `
      SELECT ${NOTIFICATION_COLUMNS}
      FROM notifications
      WHERE recipient_identity_id = $1
        AND recipient_profile_type = $2
        AND ${profileFilter} = $3
        ${cursorSql}
      ORDER BY created_at DESC, notification_id DESC
      LIMIT $4
      `,
      params,
    );
    return result.rows;
  }

  async unreadCount(
    input: { identityId: string; role: ProfileRole; profileId: string },
    db: Queryable = this.postgres,
  ): Promise<number> {
    const profileFilter = this.profileFilter(input.role);
    const result = await db.query<{ count: string }>(
      `
      SELECT count(*)::text AS count
      FROM notifications
      WHERE recipient_identity_id = $1
        AND recipient_profile_type = $2
        AND ${profileFilter} = $3
        AND read_at IS NULL
      `,
      [input.identityId, input.role, input.profileId],
    );
    return Number.parseInt(result.rows[0].count, 10);
  }

  async markRead(
    input: {
      notificationId: string;
      identityId: string;
      role: ProfileRole;
      profileId: string;
    },
    db: Queryable = this.postgres,
  ): Promise<NotificationRow | null> {
    const profileFilter = this.profileFilter(input.role);
    const result = await db.query<NotificationRow>(
      `
      UPDATE notifications
      SET read_at = COALESCE(read_at, now())
      WHERE notification_id = $1
        AND recipient_identity_id = $2
        AND recipient_profile_type = $3
        AND ${profileFilter} = $4
      RETURNING ${NOTIFICATION_COLUMNS}
      `,
      [input.notificationId, input.identityId, input.role, input.profileId],
    );
    return result.rows[0] ?? null;
  }

  async markAllRead(
    input: { identityId: string; role: ProfileRole; profileId: string },
    db: Queryable = this.postgres,
  ): Promise<number> {
    const profileFilter = this.profileFilter(input.role);
    const result = await db.query(
      `
      UPDATE notifications
      SET read_at = now()
      WHERE recipient_identity_id = $1
        AND recipient_profile_type = $2
        AND ${profileFilter} = $3
        AND read_at IS NULL
      `,
      [input.identityId, input.role, input.profileId],
    );
    return result.rowCount ?? 0;
  }

  async ensurePreferences(
    identityId: string,
    db: Queryable = this.postgres,
  ): Promise<NotificationPreferenceRow> {
    await db.query(
      `
      INSERT INTO notification_preferences (identity_id)
      VALUES ($1)
      ON CONFLICT (identity_id) DO NOTHING
      `,
      [identityId],
    );
    const result = await db.query<NotificationPreferenceRow>(
      `
      SELECT
        notification_preference_id,
        identity_id,
        in_app_enabled,
        push_enabled,
        created_at,
        updated_at
      FROM notification_preferences
      WHERE identity_id = $1
      `,
      [identityId],
    );
    if (!result.rows[0]) {
      throw new Error('Notification preferences row was not found after ensure');
    }
    return result.rows[0];
  }

  async updatePreferences(
    input: { identityId: string; inAppEnabled: boolean; pushEnabled: boolean },
    db: Queryable = this.postgres,
  ): Promise<NotificationPreferenceRow> {
    const result = await db.query<NotificationPreferenceRow>(
      `
      INSERT INTO notification_preferences (identity_id, in_app_enabled, push_enabled)
      VALUES ($1, $2, $3)
      ON CONFLICT (identity_id) DO UPDATE
      SET
        in_app_enabled = EXCLUDED.in_app_enabled,
        push_enabled = EXCLUDED.push_enabled
      RETURNING
        notification_preference_id,
        identity_id,
        in_app_enabled,
        push_enabled,
        created_at,
        updated_at
      `,
      [input.identityId, input.inAppEnabled, input.pushEnabled],
    );
    return result.rows[0];
  }

  async resolveRecipient(
    profileType: ProfileRole,
    profileId: string,
    db: Queryable = this.postgres,
  ): Promise<RecipientRef | null> {
    if (profileType === 'CUSTOMER') {
      const result = await db.query<{ identity_id: string }>(
        `
        SELECT identity_id
        FROM customer_profiles
        WHERE customer_profile_id = $1
        `,
        [profileId],
      );
      if (!result.rows[0]) {
        return null;
      }
      return {
        identityId: result.rows[0].identity_id,
        profileType,
        profileId,
      };
    }
    if (profileType === 'RIDER') {
      const result = await db.query<{ identity_id: string }>(
        `
        SELECT identity_id
        FROM rider_profiles
        WHERE rider_profile_id = $1
        `,
        [profileId],
      );
      if (!result.rows[0]) {
        return null;
      }
      return {
        identityId: result.rows[0].identity_id,
        profileType,
        profileId,
      };
    }
    const result = await db.query<{ identity_id: string }>(
      `
      SELECT identity_id
      FROM admin_profiles
      WHERE admin_profile_id = $1
      `,
      [profileId],
    );
    if (!result.rows[0]) {
      return null;
    }
    return {
      identityId: result.rows[0].identity_id,
      profileType,
      profileId,
    };
  }

  async assertRecipient(
    input: RecipientRef,
    db: Queryable,
  ): Promise<boolean> {
    if (input.profileType === 'CUSTOMER') {
      const result = await db.query(
        `
        SELECT 1
        FROM customer_profiles
        WHERE customer_profile_id = $1 AND identity_id = $2
        `,
        [input.profileId, input.identityId],
      );
      return result.rows.length > 0;
    }
    if (input.profileType === 'RIDER') {
      const result = await db.query(
        `
        SELECT 1
        FROM rider_profiles
        WHERE rider_profile_id = $1 AND identity_id = $2
        `,
        [input.profileId, input.identityId],
      );
      return result.rows.length > 0;
    }
    const result = await db.query(
      `
      SELECT 1
      FROM admin_profiles
      WHERE admin_profile_id = $1 AND identity_id = $2
      `,
      [input.profileId, input.identityId],
    );
    return result.rows.length > 0;
  }

  async listActiveAdmins(
    db: Queryable,
  ): Promise<RecipientRef[]> {
    const result = await db.query<{
      admin_profile_id: string;
      identity_id: string;
    }>(
      `
      SELECT a.admin_profile_id, a.identity_id
      FROM admin_profiles a
      JOIN identities i ON i.identity_id = a.identity_id
      WHERE a.active = TRUE
        AND i.auth_status = 'ACTIVE'
      `,
    );
    return result.rows.map((row) => ({
      identityId: row.identity_id,
      profileType: 'ADMIN' as const,
      profileId: row.admin_profile_id,
    }));
  }

  async claimPendingDelivery(
    backoffSeconds: number,
    db: Queryable,
  ): Promise<ClaimedDelivery | null> {
    const result = await db.query<ClaimedDelivery>(
      `
      WITH picked AS (
        SELECT d.notification_delivery_id
        FROM notification_deliveries d
        WHERE d.status = 'PENDING'
          AND (
            d.last_attempt_at IS NULL
            OR d.last_attempt_at <= now() - ($1::int * interval '1 second')
          )
        ORDER BY d.created_at ASC, d.notification_delivery_id ASC
        FOR UPDATE OF d SKIP LOCKED
        LIMIT 1
      ),
      updated AS (
        UPDATE notification_deliveries d
        SET
          attempt_count = d.attempt_count + 1,
          last_attempt_at = now()
        FROM picked
        WHERE d.notification_delivery_id = picked.notification_delivery_id
        RETURNING
          d.notification_delivery_id,
          d.notification_id,
          d.channel,
          d.status,
          d.attempt_count,
          d.last_attempt_at,
          d.last_error,
          d.provider_message_id,
          d.created_at
      )
      SELECT
        u.notification_delivery_id,
        u.notification_id,
        u.channel,
        u.status,
        u.attempt_count,
        u.last_attempt_at,
        u.last_error,
        u.provider_message_id,
        u.created_at,
        n.recipient_identity_id,
        n.type,
        n.title,
        n.body,
        n.order_id
      FROM updated u
      JOIN notifications n ON n.notification_id = u.notification_id
      `,
      [backoffSeconds],
    );
    return result.rows[0] ?? null;
  }

  async completeDelivery(
    input: {
      deliveryId: string;
      status: 'SENT' | 'FAILED' | 'PENDING';
      lastError: string | null;
      providerMessageId: string | null;
    },
    db: Queryable,
  ): Promise<NotificationDeliveryRow> {
    const result = await db.query<NotificationDeliveryRow>(
      `
      UPDATE notification_deliveries
      SET
        status = $2,
        last_error = $3,
        provider_message_id = COALESCE($4, provider_message_id)
      WHERE notification_delivery_id = $1
      RETURNING ${DELIVERY_COLUMNS}
      `,
      [
        input.deliveryId,
        input.status,
        input.lastError,
        input.providerMessageId,
      ],
    );
    return result.rows[0];
  }

  async countPending(db: Queryable = this.postgres): Promise<number> {
    const result = await db.query<{ count: string }>(
      `SELECT count(*)::text AS count FROM notification_deliveries WHERE status = 'PENDING'`,
    );
    return Number.parseInt(result.rows[0].count, 10);
  }

  private profileFilter(role: ProfileRole): string {
    if (role === 'CUSTOMER') {
      return 'customer_profile_id';
    }
    if (role === 'RIDER') {
      return 'rider_profile_id';
    }
    return 'admin_profile_id';
  }
}
