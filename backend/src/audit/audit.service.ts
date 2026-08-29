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
   * Writes one immutable audit_logs row.
   *
   * Audit is evidence, not control flow: a failure here must not fail the
   * financial action or the report the admin asked for, so it is logged and
   * swallowed. Callers that need audit to be transactional should pass the
   * surrounding transaction as `db`.
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
}
