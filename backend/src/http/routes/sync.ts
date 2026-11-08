import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { SyncService } from '../../services/sync.js';
import type { AttachmentService } from '../../services/attachments.js';
import type { IdentityService } from '../../services/identity.js';
import { requireAuth } from '../auth.js';

const base64Bytes = z
  .string()
  .min(1)
  .transform((s) => Buffer.from(s, 'base64'));

export async function registerSyncRoutes(
  app: FastifyInstance,
  deps: { sync: SyncService; attachments: AttachmentService; identity: IdentityService },
): Promise<void> {
  const auth = requireAuth(deps.identity.tokens);

  app.post('/sync/events', { preHandler: auth }, async (req, reply) => {
    const body = z
      .object({
        events: z
          .array(
            z.object({
              id: z.string().min(16).max(40),
              deviceId: z.string().uuid(),
              payloadType: z.string().min(1).max(64),
              payload: base64Bytes,
              prevHash: base64Bytes.nullable().optional(),
              integrity: z.record(z.any()).optional(),
              createdAt: z.string().datetime().optional(),
            }),
          )
          .max(500),
      })
      .parse(req.body);
    try {
      const inserted = await deps.sync.ingest(
        req.auth!.accountId,
        body.events.map((e) => ({
          id: e.id,
          deviceId: e.deviceId,
          payloadType: e.payloadType,
          payload: e.payload,
          prevHash: e.prevHash ?? null,
          integrity: e.integrity,
          createdAt: e.createdAt ? new Date(e.createdAt) : undefined,
        })),
      );
      return reply.send({ inserted });
    } catch (err) {
      return reply.code(422).send({ error: 'bad_event', message: (err as Error).message });
    }
  });

  app.get('/sync/events', { preHandler: auth }, async (req) => {
    const query = z
      .object({
        since: z.string().datetime().optional(),
        limit: z.coerce.number().int().positive().max(2000).optional(),
      })
      .parse(req.query);
    const events = await deps.sync.pull(
      req.auth!.accountId,
      query.since ? new Date(query.since) : null,
      query.limit,
    );
    return {
      events: events.map((e) => ({
        id: e.id,
        deviceId: e.deviceId,
        payloadType: e.payloadType,
        payload: e.payload.toString('base64'),
        prevHash: e.prevHash ? e.prevHash.toString('base64') : null,
        hash: e.hash.toString('base64'),
        integrity: e.integrity,
        receivedAt: e.receivedAt.toISOString(),
        createdAt: e.createdAt.toISOString(),
      })),
    };
  });

  app.put('/sync/envelope', { preHandler: auth }, async (req, reply) => {
    const body = z
      .object({ wrappedContentKey: base64Bytes, version: z.number().int().positive() })
      .parse(req.body);
    await deps.sync.upsertEnvelope(req.auth!.accountId, body.wrappedContentKey, body.version);
    return reply.code(204).send();
  });

  app.get('/sync/envelope', { preHandler: auth }, async (req, reply) => {
    const envelope = await deps.sync.getEnvelope(req.auth!.accountId);
    if (!envelope) return reply.code(404).send({ error: 'not_found' });
    return {
      wrappedContentKey: envelope.wrappedContentKey.toString('base64'),
      version: envelope.version,
      rotatedAt: envelope.rotatedAt.toISOString(),
    };
  });

  // ---- Attachments ----
  app.post('/sync/attachments', { preHandler: auth }, async (req, reply) => {
    const body = z
      .object({
        sizeBytes: z.number().int().positive(),
        sha256: base64Bytes,
        mimeType: z.string().min(1).max(128).optional(),
      })
      .parse(req.body);
    try {
      const result = await deps.attachments.presignUpload({
        accountId: req.auth!.accountId,
        sizeBytes: body.sizeBytes,
        sha256: body.sha256,
        mimeType: body.mimeType,
      });
      return reply.code(201).send(result);
    } catch (err) {
      return reply.code(422).send({ error: 'bad_attachment', message: (err as Error).message });
    }
  });

  app.post('/sync/attachments/:id/commit', { preHandler: auth }, async (req, reply) => {
    const params = z.object({ id: z.string().uuid() }).parse(req.params);
    try {
      await deps.attachments.commit(req.auth!.accountId, params.id);
      return reply.code(204).send();
    } catch (err) {
      return reply.code(404).send({ error: 'not_found', message: (err as Error).message });
    }
  });

  app.get('/sync/attachments/:id', { preHandler: auth }, async (req, reply) => {
    const params = z.object({ id: z.string().uuid() }).parse(req.params);
    try {
      return await deps.attachments.presignDownload(req.auth!.accountId, params.id);
    } catch (err) {
      return reply.code(404).send({ error: 'not_found', message: (err as Error).message });
    }
  });

  app.delete('/sync/attachments/:id', { preHandler: auth }, async (req, reply) => {
    const params = z.object({ id: z.string().uuid() }).parse(req.params);
    await deps.attachments.delete(req.auth!.accountId, params.id);
    return reply.code(204).send();
  });
}
