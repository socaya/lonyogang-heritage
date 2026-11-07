import pg from 'pg';
import type { AppConfig } from './config.js';

export type Db = pg.Pool;

/**
 * Creates a Postgres connection pool with sensible defaults. We treat the
 * returned pool as the single source of DB access; services take it as a
 * constructor argument so tests can swap in a Testcontainers-backed pool.
 */
export function createPool(config: AppConfig): Db {
  return new pg.Pool({
    connectionString: config.DATABASE_URL,
    max: 20,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
    // Postgres's default ssl: false is fine for local docker-compose.
  });
}

/**
 * Convenience helper for one-shot parameterised queries that return 0 or 1
 * rows. Returns null when nothing matched, so callers can distinguish not-
 * found from an application error.
 */
export async function queryOne<T extends pg.QueryResultRow>(
  db: Db,
  sql: string,
  params: unknown[] = [],
): Promise<T | null> {
  const result = await db.query<T>(sql, params as pg.QueryConfig['values']);
  return result.rows[0] ?? null;
}

export async function queryMany<T extends pg.QueryResultRow>(
  db: Db,
  sql: string,
  params: unknown[] = [],
): Promise<T[]> {
  const result = await db.query<T>(sql, params as pg.QueryConfig['values']);
  return result.rows;
}

export async function withTx<T>(
  db: Db,
  fn: (client: pg.PoolClient) => Promise<T>,
): Promise<T> {
  const client = await db.connect();
  try {
    await client.query('begin');
    const result = await fn(client);
    await client.query('commit');
    return result;
  } catch (err) {
    await client.query('rollback');
    throw err;
  } finally {
    client.release();
  }
}
