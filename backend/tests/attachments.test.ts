import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import type { PoolClient } from 'pg';
import pg from 'pg';
import { PostgreSqlContainer } from '@testcontainers/postgresql';
import type { StartedTestContainer } from 'testcontainers';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { AttachmentService } from '../src/services/attachments.js';
import { AuditService } from '../src/services/audit.js';
import type { VirusScanner } from '../src/services/virus_scanner.js';
import { loadConfig } from '../src/config.js';
import { generateMasterKeyBase64 } from '../src/kms.js';
import { S3Client } from '@aws-sdk/client-s3';

const here = path.dirname(fileURLToPath(import.meta.url));
const migrationsDir = path.resolve(here, '..', 'migrations');

async function applyMigrations(client: PoolClient) {
  for (const file of readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort()) {
    const sql = readFileSync(path.join(migrationsDir, file), 'utf-8');
    await client.query(sql);
  }
}

/** In-memory stand-in for S3: records the bytes written at a given key and
 *  returns them on download. Used so attachments.commit can round-trip
 *  without a real MinIO. */
class InMemoryS3 extends S3Client {
  readonly store = new Map<string, Buffer>();
  constructor() {
    super({ region: 'us-east-1' });
  }
  override async send(command: unknown): Promise<unknown> {
    const name = (command as { constructor: { name: string } }).constructor.name;
    const input = (command as unknown as { input: Record<string, unknown> }).input ?? {};
    if (name === 'HeadBucketCommand' || name === 'CreateBucketCommand') return {};
    if (name === 'PutObjectCommand') {
      const body = input['Body'];
      const bytes = body instanceof Uint8Array ? Buffer.from(body) : Buffer.from(String(body));
      this.store.set(String(input['Key']), bytes);
      return {};
    }
    if (name === 'GetObjectCommand') {
      const bytes = this.store.get(String(input['Key'])) ?? Buffer.alloc(0);
      return {
        Body: (async function* () {
          yield bytes;
        })(),
      } as unknown;
    }
    if (name === 'DeleteObjectCommand') {
      this.store.delete(String(input['Key']));
      return {};
    }
    throw new Error(`Unexpected S3 command: ${name}`);
  }
}

class RejectEveryoneScanner implements VirusScanner {
  readonly name = 'reject';
  async scan(_bytes: Buffer) {
    return { clean: false, signature: 'Test.Threat', scanner: this.name };
  }
}

describe('AttachmentService.commit', () => {
  let container: StartedTestContainer;
  let pool: pg.Pool;
  let accountId: string;
  const s3Stub = new InMemoryS3();

  beforeAll(async () => {
    container = await new PostgreSqlContainer('postgres:16-alpine')
      .withDatabase('lonyogang')
      .withUsername('lonyogang')
      .withPassword('lonyogang')
      .start();
    pool = new pg.Pool({ connectionString: container.getConnectionUri() });
    const client = await pool.connect();
    try {
      await applyMigrations(client);
      const insert = await client.query<{ id: string }>(
        `insert into accounts (email, password_hash, status)
         values ('attach@example.com', 'dummy', 'active')
         returning id`,
      );
      accountId = insert.rows[0]!.id;
    } finally {
      client.release();
    }
  }, 120_000);

  afterAll(async () => {
    await pool.end();
    await container.stop();
  });

  it('rejects an attachment whose bytes fail the virus scan', async () => {
    const config = loadConfig({
      NODE_ENV: 'test',
      PORT: '0',
      LOG_LEVEL: 'error',
      DATABASE_URL: container.getConnectionUri(),
      JWT_PRIVATE_KEY_PEM: '-----BEGIN PRIVATE KEY-----\n-----END PRIVATE KEY-----',
      JWT_PUBLIC_KEY_PEM: '-----BEGIN PUBLIC KEY-----\n-----END PUBLIC KEY-----',
      PASSWORD_PEPPER: 'test',
      RP_ID: 'localhost',
      RP_NAME: 'Test',
      RP_ORIGIN: 'http://localhost',
      KMS_MASTER_KEY_B64: generateMasterKeyBase64(),
      FX_PROVIDER: 'mock',
    } as NodeJS.ProcessEnv);
    const audit = new AuditService(pool);
    const scanner = new RejectEveryoneScanner();
    const service = new AttachmentService(pool, config, audit, scanner);
    // Swap in the in-memory S3 stub.
    Object.defineProperty(service, 's3', { value: s3Stub, configurable: true });

    const presign = await service.presignUpload({
      accountId,
      sizeBytes: 11,
      sha256: Buffer.alloc(32),
      mimeType: 'application/octet-stream',
    });
    s3Stub.store.set(presign.bucketKey, Buffer.from('hello world'));

    await expect(service.commit(accountId, presign.attachmentId)).rejects.toThrow(
      /rejected by scanner/,
    );
    expect(s3Stub.store.has(presign.bucketKey)).toBe(false);

    const row = await pool.query(
      `select id from attachment_blobs where id = $1`,
      [presign.attachmentId],
    );
    expect(row.rowCount).toBe(0);

    const auditEntries = await audit.listRecent(accountId, 10);
    expect(auditEntries.some((e) => e.action === 'attachment.rejected')).toBe(true);
  });
});
