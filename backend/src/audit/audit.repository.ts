import { Injectable } from '@nestjs/common';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';

export type AuditCategory = 'ADMIN' | 'FINANCIAL';

export type AuditLogInput = {
  actorIdentityId: string | null;
  actorProfileId: string | null;
  actorRole: string | null;
  action: string;
  entityType: string;
  entityId: string;
  oldValue: unknown | null;
  newValue: unknown | null;
  reason: string | null;
  requestId: string | null;
  ip: string | null;
  userAgent: string | null;
  category: AuditCategory | null;
};

export type AuditLogRow = {
  audit_log_id: string;
  created_at: Date;
};

@Injectable()
export class AuditRepository {
  constructor(private readonly postgres: PostgresService) {}

  async insert(
    input: AuditLogInput,
    db: Queryable = this.postgres,
  ): Promise<AuditLogRow> {
    const result = await db.query<AuditLogRow>(
      `
      INSERT INTO audit_logs (
        actor_identity_id,
        actor_profile_id,
        actor_role,
        action,
        entity_type,
        entity_id,
        old_value,
        new_value,
        reason,
        request_id,
        ip,
        user_agent,
        category
      )
      VALUES (
        $1, $2, $3, $4, $5, $6,
        $7::jsonb, $8::jsonb,
        $9, $10, $11, $12, $13
      )
      RETURNING audit_log_id, created_at
      `,
      [
        input.actorIdentityId,
        input.actorProfileId,
        input.actorRole,
        input.action,
        input.entityType,
        input.entityId,
        input.oldValue == null ? null : JSON.stringify(input.oldValue),
        input.newValue == null ? null : JSON.stringify(input.newValue),
        input.reason,
        input.requestId,
        input.ip,
        input.userAgent,
        input.category,
      ],
    );
    return result.rows[0];
  }

  /** audit_logs.entity_id is NOT NULL, so report runs get their own generated id. */
  async newEntityId(db: Queryable = this.postgres): Promise<string> {
    const result = await db.query<{ id: string }>(
      `SELECT uuid_generate_v7()::text AS id`,
    );
    return result.rows[0].id;
  }
}
