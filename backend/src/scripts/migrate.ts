import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import pg from 'pg';
import { loadConfig } from '../config.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const migrationsDir = path.resolve(here, '..', '..', 'migrations');

async function ensureTable(client: pg.PoolClient) {
  await client.query(`
    create table if not exists schema_migrations (
      version    text primary key,
      applied_at timestamptz not null default now()
    );
  `);
}

async function alreadyApplied(client: pg.PoolClient): Promise<Set<string>> {
  const { rows } = await client.query<{ version: string }>(
    'select version from schema_migrations',
  );
  return new Set(rows.map((r) => r.version));
}

async function main() {
  const reset = process.argv.includes('--reset');
  const config = loadConfig();
  const pool = new pg.Pool({ connectionString: config.DATABASE_URL });
  const client = await pool.connect();
  try {
    if (reset) {
      await client.query('drop schema public cascade; create schema public;');
    }
    await ensureTable(client);
    const applied = await alreadyApplied(client);
    const files = readdirSync(migrationsDir)
      .filter((f) => f.endsWith('.sql'))
      .sort();
    for (const file of files) {
      const version = file.replace(/\.sql$/i, '');
      if (applied.has(version)) continue;
      const sql = readFileSync(path.join(migrationsDir, file), 'utf-8');
      process.stdout.write(`Applying ${version}... `);
      await client.query('begin');
      try {
        await client.query(sql);
        await client.query(
          'insert into schema_migrations(version) values ($1) on conflict do nothing',
          [version],
        );
        await client.query('commit');
      } catch (err) {
        await client.query('rollback');
        throw err;
      }
      process.stdout.write('ok\n');
    }
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
