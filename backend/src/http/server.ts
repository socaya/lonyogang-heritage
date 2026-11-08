import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import sensible from '@fastify/sensible';
import rateLimit from '@fastify/rate-limit';
import type { AppConfig } from '../config.js';
import type { Db } from '../db.js';
import type { KeyStore } from '../services/keystore.js';
import { IdentityService } from '../services/identity.js';
import { AuditService } from '../services/audit.js';
import { PasskeyService } from '../services/passkeys.js';
import { SyncService } from '../services/sync.js';
import { AttachmentService } from '../services/attachments.js';
import { FxService, pickProvider, MockFxProvider } from '../services/fx.js';
import { RecoveryService } from '../services/recovery.js';
import { AggregationService, MockBankProvider, StanbicProvider, MtnMomoProvider } from '../services/aggregation.js';
import { PaymentsService } from '../services/payments.js';
import { PushService, ConsolePushTransport, FcmTransport, ApnsTransport } from '../services/push.js';
import {
  AfricasTalkingSmsDispatcher,
  CompositeOtpDispatcher,
  ConsoleOtpDispatcher,
  SmtpOtpDispatcher,
  type OtpDispatcher,
} from '../services/otp_dispatcher.js';
import { ClamAvScanner, NoopVirusScanner, type VirusScanner } from '../services/virus_scanner.js';
import {
  InMemoryNotary,
  OpenTimestampsNotary,
  TransparencyService,
  type TransparencyNotary,
} from '../services/transparency.js';
import { AccountService } from '../services/account.js';
import { ResourcesService } from '../services/resources.js';
import { registerIdentityRoutes } from './routes/identity.js';
import { registerSyncRoutes } from './routes/sync.js';
import { registerMiscRoutes } from './routes/misc.js';
import { registerResourceRoutes } from './routes/resources.js';
import { buildOpenApi } from './openapi.js';
import { HeadBucketCommand } from '@aws-sdk/client-s3';

export interface ServerDependencies {
  identity: IdentityService;
  audit: AuditService;
  passkeys: PasskeyService;
  sync: SyncService;
  attachments: AttachmentService;
  fx: FxService;
  recovery: RecoveryService;
  aggregation: AggregationService;
  payments: PaymentsService;
  push: PushService;
  virusScanner: VirusScanner;
  transparency: TransparencyService;
  account: AccountService;
  resources: ResourcesService;
}

export interface AssembleOverrides {
  otpDispatcher?: OtpDispatcher;
  virusScanner?: VirusScanner;
  notary?: TransparencyNotary;
}

export function assembleServices(
  config: AppConfig,
  db: Db,
  kms: KeyStore,
  overrides: AssembleOverrides = {},
): ServerDependencies {
  const audit = new AuditService(db);
  const otpDispatcher = overrides.otpDispatcher ?? defaultOtpDispatcher(config);
  const virusScanner = overrides.virusScanner ?? defaultVirusScanner(config);
  const notary = overrides.notary ?? defaultNotary(config);
  const identity = new IdentityService(db, config, kms, audit, otpDispatcher);
  const passkeys = new PasskeyService(db, config, audit);
  const sync = new SyncService(db, audit);
  const attachments = new AttachmentService(db, config, audit, virusScanner);
  const transparency = new TransparencyService(db, audit, notary);
  const account = new AccountService(db, audit, attachments);
  const resources = new ResourcesService(db, audit);
  const fx = new FxService(db, config.NODE_ENV === 'test' ? new MockFxProvider() : pickProvider(config), config);
  const recovery = new RecoveryService(db, kms, audit);
  const aggregation = new AggregationService(db, kms, audit);
  aggregation.register(new MockBankProvider());
  aggregation.register(new StanbicProvider());
  aggregation.register(new MtnMomoProvider());
  const payments = new PaymentsService(db, config, audit);
  const push = new PushService(db, audit);
  if (config.FCM_PROJECT_ID && config.FCM_SERVICE_ACCOUNT_JSON) {
    push.register(new FcmTransport(config.FCM_PROJECT_ID, config.FCM_SERVICE_ACCOUNT_JSON));
  } else {
    push.register(new ConsolePushTransport('fcm'));
  }
  if (config.APNS_TEAM_ID && config.APNS_KEY_ID && config.APNS_PRIVATE_KEY_PEM) {
    push.register(
      new ApnsTransport(
        config.APNS_TEAM_ID,
        config.APNS_KEY_ID,
        config.APNS_PRIVATE_KEY_PEM,
        config.APNS_BUNDLE_ID,
      ),
    );
  } else {
    push.register(new ConsolePushTransport('apns'));
  }
  return {
    identity,
    audit,
    passkeys,
    sync,
    attachments,
    fx,
    recovery,
    aggregation,
    payments,
    push,
    virusScanner,
    transparency,
    account,
    resources,
  };
}

function defaultVirusScanner(config: AppConfig): VirusScanner {
  if (config.CLAMAV_HOST) {
    return new ClamAvScanner({
      host: config.CLAMAV_HOST,
      port: config.CLAMAV_PORT,
    });
  }
  return new NoopVirusScanner();
}

function defaultNotary(config: AppConfig): TransparencyNotary {
  if (config.TRANSPARENCY_NOTARY === 'opentimestamps') return new OpenTimestampsNotary();
  return new InMemoryNotary();
}

function defaultOtpDispatcher(config: AppConfig): OtpDispatcher {
  const children: { email?: OtpDispatcher; sms?: OtpDispatcher } = {};
  if (config.SMTP_HOST && config.SMTP_FROM) {
    children.email = new SmtpOtpDispatcher({
      host: config.SMTP_HOST,
      port: config.SMTP_PORT,
      user: config.SMTP_USER,
      pass: config.SMTP_PASS,
      secure: config.SMTP_SECURE,
      from: config.SMTP_FROM,
    });
  }
  if (config.AFRICASTALKING_API_KEY && config.AFRICASTALKING_USERNAME) {
    children.sms = new AfricasTalkingSmsDispatcher({
      username: config.AFRICASTALKING_USERNAME,
      apiKey: config.AFRICASTALKING_API_KEY,
      senderId: config.AFRICASTALKING_SENDER_ID,
    });
  }
  if (!children.email && !children.sms) {
    return new ConsoleOtpDispatcher();
  }
  return new CompositeOtpDispatcher(children);
}

export async function buildServer(
  config: AppConfig,
  deps: ServerDependencies,
  options: { db?: Db; kms?: KeyStore } = {},
) {
  const app = Fastify({
    logger: {
      level: config.LOG_LEVEL,
      redact: {
        paths: ['req.headers.authorization', 'req.headers.cookie'],
        censor: '[redacted]',
      },
    },
    disableRequestLogging: config.NODE_ENV === 'test',
    bodyLimit: 2 * 1024 * 1024,
    trustProxy: true,
  });

  // Collect live route paths so the OpenAPI-drift test can walk them.
  const liveRoutes = new Set<string>();
  app.addHook('onRoute', (routeOptions) => {
    if (routeOptions.url && routeOptions.url !== '*') {
      liveRoutes.add(routeOptions.url);
    }
  });
  (app as unknown as { liveRoutes: Set<string> }).liveRoutes = liveRoutes;

  // Replace Fastify's default JSON parser with one that also keeps the raw
  // bytes on the request under `rawBody`. Needed for Stripe webhook
  // signature verification — the stringified representation of the parsed
  // body is not byte-equivalent to what Stripe signed.
  app.addContentTypeParser(
    'application/json',
    { parseAs: 'buffer' },
    (req, body, done) => {
      const buf = body as Buffer;
      (req as unknown as { rawBody: string }).rawBody = buf.toString('utf8');
      try {
        done(null, buf.length === 0 ? undefined : JSON.parse(buf.toString('utf8')));
      } catch (err) {
        done(err as Error);
      }
    },
  );

  await app.register(helmet, { global: true });
  await app.register(cors, { origin: true, credentials: true });
  await app.register(sensible);
  await app.register(rateLimit, {
    global: true,
    max: 180,
    timeWindow: '1 minute',
    allowList: [],
    keyGenerator: (req) => {
      const authHeader = req.headers.authorization;
      return authHeader ? `auth:${authHeader}` : `ip:${req.ip}`;
    },
  });

  (app as unknown as { opsSecret?: string }).opsSecret = config.OPS_SHARED_SECRET;

  app.get('/healthz', async (_req, reply) => {
    const checks: Record<string, { status: 'ok' | 'degraded' | 'fail'; latencyMs: number; error?: string }> = {};
    const start = (): [bigint] => [process.hrtime.bigint()];
    const stop = (t: [bigint]) => Number(process.hrtime.bigint() - t[0]) / 1_000_000;

    // Database
    const dbTimer = start();
    try {
      if (!options.db) throw new Error('no db configured');
      await options.db.query('select 1');
      checks['database'] = { status: 'ok', latencyMs: stop(dbTimer) };
    } catch (err) {
      checks['database'] = { status: 'fail', latencyMs: stop(dbTimer), error: (err as Error).message };
    }

    // KMS
    const kmsTimer = start();
    try {
      if (!options.kms) throw new Error('no kms configured');
      const probe = await options.kms.seal(Buffer.from('healthcheck'));
      await options.kms.unseal(probe);
      checks['kms'] = { status: 'ok', latencyMs: stop(kmsTimer) };
    } catch (err) {
      checks['kms'] = { status: 'degraded', latencyMs: stop(kmsTimer), error: (err as Error).message };
    }

    // Object storage (via the attachments service's S3 client).
    const s3Timer = start();
    try {
      await (deps.attachments as unknown as { s3: { send: (c: unknown) => Promise<unknown> } }).s3.send(
        new HeadBucketCommand({ Bucket: config.S3_BUCKET }),
      );
      checks['objectStorage'] = { status: 'ok', latencyMs: stop(s3Timer) };
    } catch (err) {
      checks['objectStorage'] = { status: 'degraded', latencyMs: stop(s3Timer), error: (err as Error).message };
    }

    const statuses = Object.values(checks).map((c) => c.status);
    const overall: 'ok' | 'degraded' | 'fail' = statuses.includes('fail')
      ? 'fail'
      : statuses.includes('degraded')
        ? 'degraded'
        : 'ok';
    await reply
      .code(overall === 'fail' ? 503 : 200)
      .send({
        status: overall,
        version: '0.5.0-dev',
        dpoContact: 'privacy@lonyogang.com',
        checks,
      });
  });

  app.get('/openapi.json', async () => buildOpenApi(config));

  await registerIdentityRoutes(app, { identity: deps.identity, passkeys: deps.passkeys });
  await registerSyncRoutes(app, {
    sync: deps.sync,
    attachments: deps.attachments,
    identity: deps.identity,
  });
  await registerMiscRoutes(app, deps);
  await registerResourceRoutes(app, {
    identity: deps.identity,
    resources: deps.resources,
  });

  app.setErrorHandler(async (err, req, reply) => {
    req.log.error({ err }, 'unhandled request error');
    if (reply.sent) return;
    await reply.code(500).send({ error: 'internal', message: 'Something went wrong' });
  });

  return app;
}
