import { Injectable } from '@nestjs/common';
import { AuthContext } from '../auth/types/auth-context';
import { AppLogger } from '../common/logger/app-logger';
import { currentRequestId } from '../common/http/request-context';
import { Queryable } from '../database/queryable';
import { AuditCategory, AuditRepository } from './audit.repository';

export type AuditWriteInput = {
  auth: AuthContext;
  action: string;
  entityType: string;
  entityId: string;
  category: AuditCategory;
  oldValue?: unknown;
  newValue?: unknown;
  reason?: string | null;
  ip?: string | null;
  userAgent?: string | null;
};

@Injectable()
export class AuditService {
  constructor(
    private readonly repo: AuditRepository,
    private readonly logger: AppLogger,
  ) {}

  async newEntityId(db?: Queryable): Promise<string> {
    return this.repo.newEntityId(db);
  }

  /**
   * Best-effort audit for reports and non-financial admin actions.
   * A failure is logged and does not abort the caller, even when `db` is a
   * transaction. Order purge, order hide, and wallet reversal must use
   * recordRequired so a failed insert rolls the operation back.
   */
  async record(input: AuditWriteInput, db?: Queryable): Promise<void> {
    try {
      await this.repo.insert(
        {
          actorIdentityId: input.auth.identityId,
          actorProfileId: input.auth.profileId,
          actorRole: input.auth.role,
          action: input.action,
          entityType: input.entityType,
          entityId: input.entityId,
          oldValue: input.oldValue ?? null,
          newValue: input.newValue ?? null,
          reason: input.reason ?? null,
          requestId: currentRequestId(),
          ip: input.ip ?? null,
          userAgent: input.userAgent ?? null,
          category: input.category,
        },
        db,
      );
    } catch (err) {
      this.logger.error('audit_write_failed', {
        action: input.action,
        entity_type: input.entityType,
        entity_id: input.entityId,
        error: err instanceof Error ? err.message : 'unknown',
      });
    }
  }

  /**
   * Mandatory security or financial audit. Uses the caller's transaction
   * connection. Throws on failure so PostgresService.transaction rolls back
   * the purge, hide, or reversal that required this row.
   */
  async recordRequired(input: AuditWriteInput, db: Queryable): Promise<void> {
    await this.repo.insert(
      {
        actorIdentityId: input.auth.identityId,
        actorProfileId: input.auth.profileId,
        actorRole: input.auth.role,
        action: input.action,
        entityType: input.entityType,
        entityId: input.entityId,
        oldValue: input.oldValue ?? null,
        newValue: input.newValue ?? null,
        reason: input.reason ?? null,
        requestId: currentRequestId(),
        ip: input.ip ?? null,
        userAgent: input.userAgent ?? null,
        category: input.category,
      },
      db,
    );
  }
}
