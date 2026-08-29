import { createHash } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { Queryable } from '../database/queryable';
import { PostgresService } from '../database/postgres.service';

export type IdempotencyScope =
  | 'create-order'
  | 'accept-offer'
  | 'status'
  | 'cancel'
  | 'payment'
  | 'finance-freeze'
  | 'recharge'
  | 'cod-settlement';

export type IdempotencyRow = {
  idempotency_id: string;
  scope: string;
  key: string;
  actor_identity_id: string | null;
  request_hash: string;
  result_entity_id: string | null;
  result_payload: unknown;
};

export function canonicalJson(value: unknown): string {
  if (value === null || typeof value !== 'object') {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return `[${value.map((item) => canonicalJson(item)).join(',')}]`;
  }
  const entries = Object.entries(value as Record<string, unknown>).sort(
    ([left], [right]) => left.localeCompare(right),
  );
  return `{${entries
    .map(([key, nested]) => `${JSON.stringify(key)}:${canonicalJson(nested)}`)
    .join(',')}}`;
}

export function hashRequest(value: unknown): string {
  return createHash('sha256').update(canonicalJson(value)).digest('hex');
}

@Injectable()
export class IdempotencyRepository {
  constructor(private readonly postgres: PostgresService) {}

  async find(
    scope: IdempotencyScope,
    key: string,
    db: Queryable = this.postgres,
  ): Promise<IdempotencyRow | null> {
    const result = await db.query<IdempotencyRow>(
      `
      SELECT
        idempotency_id,
        scope,
        key,
        actor_identity_id,
        request_hash,
        result_entity_id,
        result_payload
      FROM idempotency_keys
      WHERE scope = $1 AND key = $2
      `,
      [scope, key],
    );
    return result.rows[0] ?? null;
  }

  async insert(
    input: {
      scope: IdempotencyScope;
      key: string;
      actorIdentityId: string;
      requestHash: string;
      resultEntityId: string;
      resultPayload: unknown;
    },
    db: Queryable,
  ): Promise<void> {
    await db.query(
      `
      INSERT INTO idempotency_keys (
        scope, key, actor_identity_id, request_hash, result_entity_id, result_payload
      )
      VALUES ($1, $2, $3, $4, $5, $6::jsonb)
      `,
      [
        input.scope,
        input.key,
        input.actorIdentityId,
        input.requestHash,
        input.resultEntityId,
        JSON.stringify(input.resultPayload),
      ],
    );
  }
}
