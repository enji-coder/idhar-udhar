import { Injectable } from '@nestjs/common';
import { PostgresService } from '../database/postgres.service';
import { Queryable } from '../database/queryable';

export type StateRow = {
  state_id: string;
  name: string;
  code: string;
  active: boolean;
  created_at: Date;
};

@Injectable()
export class StatesRepository {
  constructor(private readonly postgres: PostgresService) {}

  async list(db: Queryable = this.postgres): Promise<StateRow[]> {
    const result = await db.query<StateRow>(
      `
      SELECT state_id, name, code, active, created_at
      FROM states
      ORDER BY name ASC
      `,
    );
    return result.rows;
  }

  async findById(
    id: string,
    db: Queryable = this.postgres,
  ): Promise<StateRow | null> {
    const result = await db.query<StateRow>(
      `
      SELECT state_id, name, code, active, created_at
      FROM states
      WHERE state_id = $1
      `,
      [id],
    );
    return result.rows[0] ?? null;
  }

  async findByCode(
    code: string,
    excludeId: string | null = null,
    db: Queryable = this.postgres,
  ): Promise<StateRow | null> {
    const result = await db.query<StateRow>(
      `
      SELECT state_id, name, code, active, created_at
      FROM states
      WHERE code = $1
        AND ($2::uuid IS NULL OR state_id <> $2)
      `,
      [code, excludeId],
    );
    return result.rows[0] ?? null;
  }

  async insert(
    input: { name: string; code: string; active: boolean },
    db: Queryable = this.postgres,
  ): Promise<{ state_id: string }> {
    const result = await db.query<{ state_id: string }>(
      `
      INSERT INTO states (name, code, active)
      VALUES ($1, $2, $3)
      RETURNING state_id
      `,
      [input.name, input.code, input.active],
    );
    return result.rows[0];
  }

  async update(
    id: string,
    input: { name: string; code: string; active: boolean },
    db: Queryable = this.postgres,
  ): Promise<void> {
    await db.query(
      `
      UPDATE states
      SET name = $2, code = $3, active = $4
      WHERE state_id = $1
      `,
      [id, input.name, input.code, input.active],
    );
  }
}
