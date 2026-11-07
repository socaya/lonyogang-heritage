import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { AuditService } from '../../services/audit.js';
import type { FxService } from '../../services/fx.js';
import type { RecoveryService } from '../../services/recovery.js';
import type { AggregationService } from '../../services/aggregation.js';
import type { PaymentsService } from '../../services/payments.js';
import type { PushService } from '../../services/push.js';
import type { IdentityService } from '../../services/identity.js';
import type { TransparencyService } from '../../services/transparency.js';
import type { AccountService } from '../../services/account.js';
import { requireAuth } from '../auth.js';

export async function registerMiscRoutes(
  app: FastifyInstance,
  deps: {
    identity: IdentityService;
    audit: AuditService;
    fx: FxService;
    recovery: RecoveryService;
    aggregation: AggregationService;
    payments: PaymentsService;
    push: PushService;
    transparency: TransparencyService;
    account: AccountService;
  },
): Promise<void> {
  const auth = requireAuth(deps.identity.tokens);

  // ---- /me (data-subject rights) ----
  app.get('/me', { preHandler: auth }, async (req, reply) => {
    const profile = await deps.account.getProfile(req.auth!.accountId);
    if (!profile) return reply.code(404).send({ error: 'not_found' });
    return profile;
  });

  app.patch('/me', { preHandler: auth }, async (req) => {
    const body = z
      .object({
        displayName: z.string().min(1).max(120).nullable().optional(),
        phone: z.string().min(6).max(32).nullable().optional(),
        marketingConsent: z.boolean().optional(),
      })
      .parse(req.body);
    return deps.account.updateProfile(req.auth!.accountId, body);
  });

  app.get('/me/export', { preHandler: auth }, async (req) => {
    return deps.account.exportProfile(req.auth!.accountId);
  });

  app.delete('/me', { preHandler: auth }, async (req, reply) => {
    await deps.account.eraseAccount(req.auth!.accountId);
    return reply.code(204).send();
  });

  // ---- Audit ----
  app.get('/audit/entries', { preHandler: auth }, async (req) => {
    const query = z
      .object({ limit: z.coerce.number().int().positive().max(500).optional() })
      .parse(req.query);
    const rows = await deps.audit.listRecent(req.auth!.accountId, query.limit ?? 50);
    return {
      entries: rows.map((e) => ({
        id: e.id,
        action: e.action,
        resource: e.resource,
        createdAt: e.createdAt.toISOString(),
        context: e.context,
        prevHash: e.prevHash?.toString('base64') ?? null,
        hash: e.hash.toString('base64'),
      })),
    };
  });

  app.get('/audit/chain', { preHandler: auth }, async (req) => {
    const verification = await deps.audit.verifyChain(req.auth!.accountId);
    return {
      verified: verification.verified,
      count: verification.count,
      tipHash: verification.tipHash?.toString('base64') ?? null,
      brokenAt: verification.brokenAt ?? null,
    };
  });

  app.get('/audit/anchors', { preHandler: auth }, async (req) => {
    const anchors = await deps.transparency.listAnchors(req.auth!.accountId);
    return {
      anchors: anchors.map((a) => ({
        id: a.id,
        tipHash: a.tipHash.toString('base64'),
        entryCount: a.entryCount,
        verified: a.verified,
        brokenAt: a.brokenAt,
        proof: a.proof?.toString('base64') ?? null,
        source: a.source,
        createdAt: a.createdAt.toISOString(),
      })),
    };
  });

  app.post('/audit/anchors/run', { preHandler: auth }, async (req) => {
    // Per-account anchor: an authenticated user can always refresh their
    // own transparency receipt. The ops-wide anchor job runs on a cron.
    const anchor = await deps.transparency.anchorAccount(req.auth!.accountId);
    if (!anchor) return { anchored: false };
    return {
      anchored: true,
      tipHash: anchor.tipHash.toString('base64'),
      entryCount: anchor.entryCount,
      verified: anchor.verified,
      proof: anchor.proof?.toString('base64') ?? null,
      source: anchor.source,
    };
  });

  // ---- FX ----
  app.get('/fx/rates', async (req) => {
    const query = z
      .object({
        currencies: z.string().optional(),
        asOf: z.string().date().optional(),
      })
      .parse(req.query);
    const currencies = query.currencies ? query.currencies.split(',').map((c) => c.trim()) : undefined;
    const asOf = query.asOf ? new Date(query.asOf) : undefined;
    const rates = await deps.fx.getRates({ currencies, asOf });
    return { rates };
  });

  // ---- Recovery ----
  app.post('/recovery/enroll', { preHandler: auth }, async (req) => {
    return deps.recovery.enroll(req.auth!.accountId);
  });

  app.post('/recovery/redeem', { preHandler: auth }, async (req, reply) => {
    const body = z.object({ printableShare: z.string().min(16) }).parse(req.body);
    try {
      return await deps.recovery.redeem({
        accountId: req.auth!.accountId,
        printableShare: body.printableShare,
      });
    } catch (err) {
      return reply.code(400).send({ error: 'bad_share', message: (err as Error).message });
    }
  });

  // ---- Aggregation ----
  app.get('/bank/providers', async () => {
    return { providers: deps.aggregation.listRegistered() };
  });

  app.post('/bank/connections', { preHandler: auth }, async (req, reply) => {
    const body = z
      .object({
        provider: z.string().min(1),
        providerAccountId: z.string().min(1),
        providerToken: z.string().min(1).optional(),
        scopes: z.array(z.string()).default([]),
        displayLabel: z.string().min(1).max(120).optional(),
      })
      .parse(req.body);
    try {
      return await deps.aggregation.registerLink({
        accountId: req.auth!.accountId,
        provider: body.provider,
        providerAccountId: body.providerAccountId,
        providerToken: body.providerToken,
        scopes: body.scopes,
        displayLabel: body.displayLabel,
      });
    } catch (err) {
      return reply.code(400).send({ error: 'bad_provider', message: (err as Error).message });
    }
  });

  app.delete('/bank/connections/:id', { preHandler: auth }, async (req, reply) => {
    const params = z.object({ id: z.string().uuid() }).parse(req.params);
    await deps.aggregation.revokeLink(req.auth!.accountId, params.id);
    return reply.code(204).send();
  });

  app.post('/bank/connections/:id/sync', { preHandler: auth }, async (req, reply) => {
    const params = z.object({ id: z.string().uuid() }).parse(req.params);
    try {
      return await deps.aggregation.sync(req.auth!.accountId, params.id);
    } catch (err) {
      return reply.code(400).send({ error: 'sync_failed', message: (err as Error).message });
    }
  });

  app.get('/bank/pending-imports', { preHandler: auth }, async (req) => {
    const rows = await deps.aggregation.listPendingImports(req.auth!.accountId);
    return { imports: rows };
  });

  // ---- Payments ----
  app.get('/billing/subscription', { preHandler: auth }, async (req) => {
    return deps.payments.getSubscription(req.auth!.accountId);
  });

  app.post('/webhooks/flutterwave', async (req, reply) => {
    const header = req.headers['verif-hash'];
    const signature = Array.isArray(header) ? header[0] : header;
    if (!deps.payments.verifyFlutterwaveSignature(signature)) {
      return reply.code(401).send({ error: 'bad_signature' });
    }
    const event = deps.payments.parseFlutterwavePayload(req.body);
    if (!event) return reply.code(202).send({ status: 'ignored' });
    await deps.payments.record(event);
    return reply.code(204).send();
  });

  app.post('/webhooks/stripe', async (req, reply) => {
    const header = req.headers['stripe-signature'];
    const signature = Array.isArray(header) ? header[0] : header;
    const raw = (req as unknown as { rawBody?: string }).rawBody ?? '';
    if (!deps.payments.verifyStripeSignature(raw, signature)) {
      return reply.code(401).send({ error: 'bad_signature' });
    }
    const event = deps.payments.parseStripePayload(req.body);
    if (!event) return reply.code(202).send({ status: 'ignored' });
    await deps.payments.record(event);
    return reply.code(204).send();
  });

  // ---- Push ----
  // ---- Ops push send ----
  app.post('/ops/push/send', async (req, reply) => {
    const expected = (req.server as unknown as { opsSecret?: string }).opsSecret;
    const presented = req.headers['x-ops-token'];
    if (!expected) return reply.code(503).send({ error: 'ops_disabled' });
    if (presented !== expected) return reply.code(401).send({ error: 'unauthorized' });
    const body = z
      .object({
        accountId: z.string().uuid(),
        title: z.string().min(1).max(120),
        body: z.string().min(1).max(500),
        alertId: z.string().min(1).max(128),
      })
      .parse(req.body);
    const result = await deps.push.send(body);
    return result;
  });

  app.post('/push/tokens', { preHandler: auth }, async (req, reply) => {
    const body = z
      .object({
        deviceId: z.string().uuid(),
        platform: z.enum(['fcm', 'apns']),
        token: z.string().min(16).max(2048),
      })
      .parse(req.body);
    await deps.push.registerToken({ ...body, accountId: req.auth!.accountId });
    return reply.code(204).send();
  });

  app.delete('/push/tokens/:deviceId/:platform', { preHandler: auth }, async (req, reply) => {
    const params = z
      .object({ deviceId: z.string().uuid(), platform: z.enum(['fcm', 'apns']) })
      .parse(req.params);
    await deps.push.removeToken(params.deviceId, params.platform);
    return reply.code(204).send();
  });
}
