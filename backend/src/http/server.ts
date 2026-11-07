import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import sensible from '@fastify/sensible';
import rateLimit from '@fastify/rate-limit';
import type { AppConfig } from '../config.js';
import type { Db } from '../db.js';
import type { LocalKms } from '../kms.js';
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
import { registerIdentityRoutes } from './routes/identity.js';
import { registerSyncRoutes } from './routes/sync.js';
import { registerMiscRoutes } from './routes/misc.js';

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
}

export function assembleServices(config: AppConfig, db: Db, kms: LocalKms): ServerDependencies {
  const audit = new AuditService(db);
  const identity = new IdentityService(db, config, kms, audit);
  const passkeys = new PasskeyService(db, config, audit);
  const sync = new SyncService(db, audit);
  const attachments = new AttachmentService(db, config, audit);
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
  return { identity, audit, passkeys, sync, attachments, fx, recovery, aggregation, payments, push };
}

export async function buildServer(config: AppConfig, deps: ServerDependencies) {
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

  app.get('/healthz', async () => ({ status: 'ok' }));

  await registerIdentityRoutes(app, { identity: deps.identity, passkeys: deps.passkeys });
  await registerSyncRoutes(app, {
    sync: deps.sync,
    attachments: deps.attachments,
    identity: deps.identity,
  });
  await registerMiscRoutes(app, deps);

  app.setErrorHandler(async (err, req, reply) => {
    req.log.error({ err }, 'unhandled request error');
    if (reply.sent) return;
    await reply.code(500).send({ error: 'internal', message: 'Something went wrong' });
  });

  return app;
}
