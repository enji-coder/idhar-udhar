import { Injectable } from '@nestjs/common';
import { AuthContext, ProfileRole } from '../auth/types/auth-context';
import { ApiError } from '../common/errors/api-error';
import { ErrorCodes } from '../common/errors/error-codes';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';
import { notificationIdFromEventKey } from './event-id';
import {
  NotificationAudience,
  NotificationType,
  renderNotification,
} from './templates';
import {
  NotificationDeliveryRow,
  NotificationRow,
  NotificationsRepository,
  RecipientRef,
} from './notifications.repository';

export type NotifyInput = {
  eventKey: string;
  type: NotificationType;
  audience: NotificationAudience;
  recipient: RecipientRef;
  orderId?: string | null;
  displayId?: string | null;
  amount?: string | null;
};

export type NotifyResult = {
  notification: NotificationRow;
  created: boolean;
  deliveries: NotificationDeliveryRow[];
};

@Injectable()
export class NotificationService {
  constructor(
    private readonly postgres: PostgresService,
    private readonly repo: NotificationsRepository,
  ) {}

  async notify(input: NotifyInput, db: Queryable = this.postgres): Promise<NotifyResult> {
    const notificationId = notificationIdFromEventKey(input.eventKey);
    const existing = await this.repo.findById(notificationId, db);
    const valid = await this.repo.assertRecipient(input.recipient, db);
    if (!valid) {
      throw new ApiError(
        ErrorCodes.NOT_FOUND,
        'Notification recipient was not found',
        404,
      );
    }

    const prefs = await this.repo.ensurePreferences(input.recipient.identityId, db);
    if (existing) {
      const inApp = await this.repo.insertDelivery(
        {
          notificationId: existing.notification_id,
          channel: 'IN_APP',
          status: prefs.in_app_enabled ? 'PENDING' : 'SKIPPED',
        },
        db,
      );
      const push = await this.repo.insertDelivery(
        {
          notificationId: existing.notification_id,
          channel: 'PUSH',
          status: prefs.push_enabled ? 'PENDING' : 'SKIPPED',
        },
        db,
      );
      return { notification: existing, created: false, deliveries: [inApp, push] };
    }

    const rendered = renderNotification(input.type, input.audience, {
      displayId: input.displayId,
      amount: input.amount,
    });
    const inserted = await this.repo.insertNotification(
      {
        notificationId,
        identityId: input.recipient.identityId,
        profileType: input.recipient.profileType,
        profileId: input.recipient.profileId,
        type: rendered.type,
        title: rendered.title,
        body: rendered.body,
        orderId: input.orderId ?? null,
      },
      db,
    );
    const inApp = await this.repo.insertDelivery(
      {
        notificationId: inserted.row.notification_id,
        channel: 'IN_APP',
        status: prefs.in_app_enabled ? 'PENDING' : 'SKIPPED',
      },
      db,
    );
    const push = await this.repo.insertDelivery(
      {
        notificationId: inserted.row.notification_id,
        channel: 'PUSH',
        status: prefs.push_enabled ? 'PENDING' : 'SKIPPED',
      },
      db,
    );
    return {
      notification: inserted.row,
      created: inserted.inserted,
      deliveries: [inApp, push],
    };
  }

  async notifyIfRecipient(
    input: Omit<NotifyInput, 'recipient'> & {
      profileType: ProfileRole;
      profileId: string | null | undefined;
    },
    db: Queryable,
  ): Promise<NotifyResult | null> {
    if (!input.profileId) {
      return null;
    }
    const recipient = await this.repo.resolveRecipient(
      input.profileType,
      input.profileId,
      db,
    );
    if (!recipient) {
      return null;
    }
    return this.notify({ ...input, recipient }, db);
  }

  async list(auth: AuthContext, limitRaw?: string, cursor?: string) {
    const limit = this.parseLimit(limitRaw);
    const parsed = this.parseCursor(cursor);
    const rows = await this.repo.listForSession({
      identityId: auth.identityId,
      role: auth.role,
      profileId: auth.profileId,
      limit,
      cursorCreatedAt: parsed?.createdAt,
      cursorId: parsed?.id,
    });
    const next =
      rows.length === limit
        ? this.encodeCursor(rows[rows.length - 1].created_at, rows[rows.length - 1].notification_id)
        : null;
    return {
      notifications: rows.map((row) => this.serialize(row)),
      next_cursor: next,
    };
  }

  async unreadCount(auth: AuthContext) {
    const count = await this.repo.unreadCount({
      identityId: auth.identityId,
      role: auth.role,
      profileId: auth.profileId,
    });
    return { unread_count: count };
  }

  async markRead(auth: AuthContext, notificationId: string) {
    const row = await this.repo.markRead({
      notificationId,
      identityId: auth.identityId,
      role: auth.role,
      profileId: auth.profileId,
    });
    if (!row) {
      throw new ApiError(ErrorCodes.NOT_FOUND, 'Notification was not found', 404);
    }
    return this.serialize(row);
  }

  async markAllRead(auth: AuthContext) {
    const updated = await this.repo.markAllRead({
      identityId: auth.identityId,
      role: auth.role,
      profileId: auth.profileId,
    });
    return { updated };
  }

  async getPreferences(auth: AuthContext) {
    const row = await this.repo.ensurePreferences(auth.identityId);
    return this.serializePreferences(row);
  }

  async updatePreferences(
    auth: AuthContext,
    body: { in_app_enabled: boolean; push_enabled: boolean },
  ) {
    const row = await this.repo.updatePreferences({
      identityId: auth.identityId,
      inAppEnabled: body.in_app_enabled,
      pushEnabled: body.push_enabled,
    });
    return this.serializePreferences(row);
  }

  serialize(row: NotificationRow) {
    return {
      notification_id: row.notification_id,
      type: row.type,
      title: row.title,
      body: row.body,
      order_id: row.order_id,
      recipient_profile_type: row.recipient_profile_type,
      read_at: row.read_at ? row.read_at.toISOString() : null,
      created_at: row.created_at.toISOString(),
    };
  }

  private serializePreferences(row: {
    in_app_enabled: boolean;
    push_enabled: boolean;
    updated_at: Date;
  }) {
    return {
      in_app_enabled: row.in_app_enabled,
      push_enabled: row.push_enabled,
      updated_at: row.updated_at.toISOString(),
    };
  }

  private parseLimit(raw?: string): number {
    if (!raw) {
      return 50;
    }
    const parsed = Number.parseInt(raw, 10);
    if (!Number.isFinite(parsed) || parsed < 1) {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'limit must be a positive integer',
        400,
      );
    }
    return Math.min(parsed, 100);
  }

  private parseCursor(
    cursor?: string,
  ): { createdAt: Date; id: string } | null {
    if (!cursor) {
      return null;
    }
    const sep = cursor.indexOf('_');
    if (sep < 1) {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'cursor is invalid',
        400,
      );
    }
    const createdAt = new Date(cursor.slice(0, sep));
    const id = cursor.slice(sep + 1);
    if (Number.isNaN(createdAt.getTime()) || id.length < 32) {
      throw new ApiError(
        ErrorCodes.VALIDATION_ERROR,
        'cursor is invalid',
        400,
      );
    }
    return { createdAt, id };
  }

  private encodeCursor(createdAt: Date, id: string): string {
    return `${createdAt.toISOString()}_${id}`;
  }
}
