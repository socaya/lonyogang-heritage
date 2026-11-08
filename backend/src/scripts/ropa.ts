import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadConfig } from '../config.js';
import { createPool } from '../db.js';
import { ROPA_ACTIVITIES, type RopaRow } from '../services/ropa.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '..', '..', '..');
const target = path.join(repoRoot, 'docs', 'RoPA.csv');

function csv(value: unknown): string {
  const str = Array.isArray(value) ? value.join('; ') : String(value ?? '');
  if (/["\n,]/.test(str)) return `"${str.replace(/"/g, '""')}"`;
  return str;
}

async function main() {
  const config = loadConfig();
  const pool = createPool(config);
  try {
    const summary = await pool.query<{ tables: string }>(`
      select string_agg(table_name, ',' order by table_name) as tables
        from information_schema.tables
       where table_schema = 'public'
         and table_name not like 'pg_%'
    `);
    const tablesLoaded = summary.rows[0]?.tables ?? '';
    const rows: RopaRow[] = ROPA_ACTIVITIES.map((row) => ({
      ...row,
      sourceTables: row.sourceTables.filter((t) => tablesLoaded.includes(t)),
    }));
    mkdirSync(path.dirname(target), { recursive: true });
    const header = [
      'activity',
      'purpose',
      'lawful_basis',
      'data_categories',
      'recipients',
      'retention',
      'cross_border',
      'source_tables',
    ].map(csv).join(',');
    const body = rows.map((r) =>
      [
        r.activity,
        r.purpose,
        r.lawfulBasis,
        r.dataCategories,
        r.recipients,
        r.retention,
        r.crossBorder,
        r.sourceTables,
      ].map(csv).join(','),
    );
    writeFileSync(target, [header, ...body].join('\n') + '\n', 'utf-8');
    process.stdout.write(`Wrote ${rows.length} RoPA rows to ${target}\n`);
  } finally {
    await pool.end();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
