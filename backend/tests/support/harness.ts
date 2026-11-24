import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { generateKeyPairSync } from 'node:crypto';
import { PostgreSqlContainer } from '@testcontainers/postgresql';
import type { StartedTestContainer } from 'testcontainers';
import pg from 'pg';
import type { FastifyInstance } from 'fastify';
import { generateMasterKeyBase64, LocalKms } from '../../src/kms.js';
import { loadConfig } from '../../src/config.js';
import { assembleServices, buildServer } from '../../src/http/server.js';
import { MockBankProvider } from '../../src/services/aggregation.js';
import { LocalKeyStore } from '../../src/services/keystore.js';
import { ConsoleOtpDispatcher } from '../../src/services/otp_dispatcher.js';

const migrationsDir = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..', '..', 'migrations');

export interface Harness {
  app: FastifyInstance;
  pool: pg.Pool;
  teardown: () => Promise<void>;
  config: ReturnType<typeof loadConfig>;
  services: ReturnType<typeof assembleServices>;
  otp: ConsoleOtpDispatcher;
}

export async function startHarness(): Promise<Harness> {
  const container = await new PostgreSqlContainer('postgres:16-alpine')
    .withDatabase('lonyogang')
    .withUsername('lonyogang')
    .withPassword('lonyogang')
    .start();

  const pool = new pg.Pool({ connectionString: container.getConnectionUri() });
  await applyMigrations(pool);

  const { publicKey, privateKey } = generateKeyPairSync('ed25519');
  const jwtPrivatePem = privateKey.export({ format: 'pem', type: 'pkcs8' }).toString();
  const jwtPublicPem = publicKey.export({ format: 'pem', type: 'spki' }).toString();

  const env = {
    ...process.env,
    NODE_ENV: 'test',
    PORT: '0',
    LOG_LEVEL: 'error',
    DATABASE_URL: container.getConnectionUri(),
    JWT_PRIVATE_KEY_PEM: jwtPrivatePem,
    JWT_PUBLIC_KEY_PEM: jwtPublicPem,
    JWT_ACCESS_TTL_SECONDS: '900',
    JWT_REFRESH_TTL_SECONDS: '2592000',
    PASSWORD_PEPPER: 'test-pepper',
    RP_ID: 'localhost',
    RP_NAME: 'LonyoGang Test',
    RP_ORIGIN: 'http://localhost',
    KMS_MASTER_KEY_B64: generateMasterKeyBase64(),
    FX_PROVIDER: 'mock',
  };
  const config = loadConfig(env as NodeJS.ProcessEnv);
  const kms = new LocalKeyStore(new LocalKms(config.KMS_MASTER_KEY_B64));
  const otp = new ConsoleOtpDispatcher();
  const services = assembleServices(config, pool, kms, { otpDispatcher: otp });
  // Stub out S3 — we don't start a real MinIO in the test harness; attachment
  // tests use a null adapter test where the bucket pre-flight is skipped.
  const app = await buildServer(config, services, { db: pool, kms });
  await app.ready();

  return {
    app,
    pool,
    config,
    services,
    otp,
    teardown: async () => {
      await app.close();
      await pool.end();
      await (container as StartedTestContainer).stop();
    },
  };
}

async function applyMigrations(pool: pg.Pool): Promise<void> {
  const files = readdirSync(migrationsDir)
    .filter((f) => f.endsWith('.sql'))
    .sort();
  const client = await pool.connect();
  try {
    for (const file of files) {
      const sql = readFileSync(path.join(migrationsDir, file), 'utf-8');
      await client.query(sql);
    }
  } finally {
    client.release();
  }
}

export function freshMockBankProvider(): MockBankProvider {
  return new MockBankProvider();
}

/** Exercise real password validation, dispatch and verification in tests.
 * Negative password and rate-limit responses are returned unchanged.
 */
export async function signInForTest(harness: Harness, request: {
  method: 'POST'; url: string; payload: {email:string;password:string;deviceId:string;totpCode?:string}; remoteAddress?:string;
}) {
  const {totpCode,...payload}=request.payload;
  const begin=await harness.app.inject({...request,payload});
  if(begin.statusCode!==202)return begin;
  const challenge=begin.json<{challengeToken:string;method:string}>();
  const code=challenge.method==='totp'?totpCode:[...harness.otp.dispatched].reverse().find(d=>d.purpose==='signin'&&d.destination===payload.email.trim().toLowerCase())?.code;
  if(!code)throw new Error('Test sign-in requires a delivered verification code');
  return harness.app.inject({method:'POST',url:'/identity/sessions/challenge/verify',payload:{challengeToken:challenge.challengeToken,code},...(request.remoteAddress?{remoteAddress:request.remoteAddress}:{})});
}
