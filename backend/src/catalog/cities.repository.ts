import { Injectable } from '@nestjs/common';
import { PostgresService } from '../database/postgres.service';
import { Queryable } from '../database/queryable';

export type CityRow = {
  city_id: string;
  state_id: string;
  state_code: string;
  state_name: string;
  name: string;
  city_code: string;
  active: boolean;
  created_at: Date;
};

@Injectable()
export class CitiesRepository {
  constructor(private readonly postgres: PostgresService) {}

  async list(db: Queryable = this.postgres): Promise<CityRow[]> {
    const result = await db.query<CityRow>(
      `
      SELECT
        c.city_id,
        c.state_id,
        s.code AS state_code,
        s.name AS state_name,
        c.name,
        c.city_code,
        c.active,
        c.created_at
      FROM cities c
      JOIN states s ON s.state_id = c.state_id
      ORDER BY s.name ASC, c.name ASC
      `,
    );
    return result.rows;
  }

  async findById(
    id: string,
    db: Queryable = this.postgres,
  ): Promise<CityRow | null> {
    const result = await db.query<CityRow>(
      `
      SELECT
        c.city_id,
        c.state_id,
        s.code AS state_code,
        s.name AS state_name,
        c.name,
        c.city_code,
        c.active,
        c.created_at
      FROM cities c
      JOIN states s ON s.state_id = c.state_id
      WHERE c.city_id = $1
      `,
      [id],
    );
    return result.rows[0] ?? null;
  }

  async findByCode(
    cityCode: string,
    excludeId: string | null = null,
    db: Queryable = this.postgres,
  ): Promise<{ city_id: string } | null> {
    const result = await db.query<{ city_id: string }>(
      `
      SELECT city_id
      FROM cities
      WHERE city_code = $1
        AND ($2::uuid IS NULL OR city_id <> $2)
      LIMIT 1
      `,
      [cityCode, excludeId],
    );
    return result.rows[0] ?? null;
  }

  async insert(
    input: {
      stateId: string;
      name: string;
      cityCode: string;
      active: boolean;
    },
    db: Queryable = this.postgres,
  ): Promise<{ city_id: string }> {
    const result = await db.query<{ city_id: string }>(
      `
      INSERT INTO cities (state_id, name, city_code, active)
      VALUES ($1, $2, $3, $4)
      RETURNING city_id
      `,
      [input.stateId, input.name, input.cityCode, input.active],
    );
    return result.rows[0];
  }

  async update(
    id: string,
    input: {
      stateId: string;
      name: string;
      cityCode: string;
      active: boolean;
    },
    db: Queryable = this.postgres,
  ): Promise<void> {
    await db.query(
      `
      UPDATE cities
      SET state_id = $2, name = $3, city_code = $4, active = $5
      WHERE city_id = $1
      `,
      [id, input.stateId, input.name, input.cityCode, input.active],
    );
  }
}
