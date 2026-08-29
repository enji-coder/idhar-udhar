import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Pool, PoolClient, QueryResult, QueryResultRow } from 'pg';
import { AppLogger } from '../common/logger/app-logger';
import { AppConfig } from '../config/configuration';
import { Queryable } from './queryable';

@Injectable()
export class PostgresService implements OnModuleInit, OnModuleDestroy, Queryable {
  private pool!: Pool;

  constructor(
    private readonly configService: ConfigService,
    private readonly logger: AppLogger,
  ) {}

  onModuleInit(): void {
    const database = this.configService.getOrThrow<AppConfig['database']>('database');
    this.pool = new Pool({
      host: database.host,
      port: database.port,
      database: database.name,
      user: database.user,
      password: database.password,
      ssl: database.ssl ? { rejectUnauthorized: true } : false,
      max: database.poolMax,
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 5_000,
    });
    this.pool.on('error', (err) => {
      this.logger.error('postgres_pool_error', { err: err.message });
    });
  }

  async onModuleDestroy(): Promise<void> {
    if (this.pool) {
      await this.pool.end();
    }
  }

  async query<T extends QueryResultRow = QueryResultRow>(
    text: string,
    params?: unknown[],
  ): Promise<QueryResult<T>> {
    return this.pool.query<T>(text, params);
  }

  async transaction<T>(work: (tx: Queryable) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const tx: Queryable = {
        query: <R extends QueryResultRow = QueryResultRow>(
          text: string,
          params?: unknown[],
        ) => client.query<R>(text, params),
      };
      const result = await work(tx);
      await client.query('COMMIT');
      return result;
    } catch (err) {
      try {
        await client.query('ROLLBACK');
      } catch {
        /* keep original error */
      }
      throw err;
    } finally {
      client.release();
    }
  }

  async ping(): Promise<{ ok: true; version: string; database: string }> {
    const result = await this.query<{ version: string; database: string }>(
      `SELECT current_setting('server_version') AS version, current_database() AS database`,
    );
    const row = result.rows[0];
    return { ok: true, version: row.version, database: row.database };
  }
}

export type { PoolClient };
