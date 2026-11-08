import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { IdentityService } from '../../services/identity.js';
import {
  RESOURCE_KINDS,
  type ResourceKind,
  type ResourcesService,
} from '../../services/resources.js';
import { requireAuth } from '../auth.js';

const kindSchema = z.enum(RESOURCE_KINDS as [ResourceKind, ...ResourceKind[]]);
const idSchema = z.string().min(1).max(200);

// Resources carry AES-GCM payloads. A real entity (asset, goal, document
// record) rounds to a few KB of JSON before encryption; a legitimate
// payload will not exceed 256 KB post-encode. Reject anything larger up
// front so a malicious client cannot burn disk + CPU on garbage writes.
const MAX_CIPHERTEXT_B64 = 350 * 1024;

// Writes + mutations get a per-account bucket so a chatty client can't
// outrun the global 180/min cap. Reads are cheaper and cap at 600/min
// because the hydrator legitimately fires 12 GETs in quick succession.
const writeLimit = { rateLimit: { max: 120, timeWindow: '1 minute' } };
const readLimit = { rateLimit: { max: 600, timeWindow: '1 minute' } };

function toWire(row: {
  kind: string;
  id: string;
  ciphertext: Buffer;
  integrity: Record<string, unknown> | null;
  prevHash: Buffer | null;
  deviceId: string;
  version: number;
  createdAt: Date;
  updatedAt: Date;
  deletedAt: Date | null;
}) {
  return {
    kind: row.kind,
    id: row.id,
    ciphertext: row.ciphertext.toString('base64'),
    integrity: row.integrity,
    prevHash: row.prevHash ? row.prevHash.toString('base64') : null,
    deviceId: row.deviceId,
    version: row.version,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
    deletedAt: row.deletedAt?.toISOString() ?? null,
  };
}

/**
 * REST layer that sits alongside /sync/events. Every supported entity
 * (asset, liability, event, goal, beneficiary batch, document, reminder,
 * trusted contact, valuation, schedule, fx rate, alert dismissal) is
 * exposed as:
 *
 *   GET    /resources/:kind                  → list current state
 *   GET    /resources/:kind/:id              → fetch one
 *   PUT    /resources/:kind/:id              → upsert ciphertext
 *   DELETE /resources/:kind/:id              → tombstone
 *   GET    /resources                        → counts per kind
 *
 * The REST layer never decrypts `ciphertext`. It is handed back to the
 * client verbatim, same as /sync/events — the only plaintext the server
 * ever inspects is the small `integrity` map used for cross-field
 * invariants and the cross-device prev_hash chain.
 */
export async function registerResourceRoutes(
  app: FastifyInstance,
  deps: { identity: IdentityService; resources: ResourcesService },
): Promise<void> {
  const auth = requireAuth(deps.identity.tokens);

  app.get('/resources', { preHandler: auth, config: readLimit }, async (req) => {
    const counts = await deps.resources.countByKind(req.auth!.accountId);
    return { counts };
  });

  app.get('/resources/:kind', { preHandler: auth, config: readLimit }, async (req, reply) => {
    const parsedParams = z.object({ kind: kindSchema }).safeParse(req.params);
    if (!parsedParams.success) {
      return reply.code(400).send({ error: 'bad_kind' });
    }
    const query = z
      .object({
        since: z.string().datetime().optional(),
        limit: z.coerce.number().int().positive().max(2000).optional(),
        includeDeleted: z.coerce.boolean().optional(),
      })
      .safeParse(req.query);
    if (!query.success) {
      return reply.code(400).send({ error: 'bad_query' });
    }
    const limit = query.data.limit ?? 500;
    // Ask for one extra row so we can tell the caller whether another
    // page is available without a count query.
    const rows = await deps.resources.listByKind(
      req.auth!.accountId,
      parsedParams.data.kind,
      {
        since: query.data.since ? new Date(query.data.since) : undefined,
        limit: limit + 1,
        includeDeleted: query.data.includeDeleted,
      },
    );
    const hasMore = rows.length > limit;
    const page = hasMore ? rows.slice(0, limit) : rows;
    return {
      resources: page.map(toWire),
      hasMore,
      // Clients loop by passing `nextSince = resources[last].updatedAt`.
      nextSince: page.length > 0
        ? page[page.length - 1]!.updatedAt.toISOString()
        : null,
    };
  });

  app.get('/resources/:kind/:id', { preHandler: auth, config: readLimit }, async (req, reply) => {
    const parsed = z
      .object({ kind: kindSchema, id: idSchema })
      .safeParse(req.params);
    if (!parsed.success) {
      return reply.code(400).send({ error: 'bad_params' });
    }
    const row = await deps.resources.getOne(
      req.auth!.accountId,
      parsed.data.kind,
      parsed.data.id,
    );
    if (!row || row.deletedAt) {
      return reply.code(404).send({ error: 'not_found' });
    }
    return toWire(row);
  });

  app.put('/resources/:kind/:id', { preHandler: auth, config: writeLimit }, async (req, reply) => {
    const parsedParams = z
      .object({ kind: kindSchema, id: idSchema })
      .safeParse(req.params);
    if (!parsedParams.success) {
      return reply.code(400).send({ error: 'bad_params' });
    }
    const body = z
      .object({
        ciphertext: z.string().min(1).max(MAX_CIPHERTEXT_B64),
        integrity: z.record(z.string(), z.unknown()).nullable().optional(),
        prevHash: z.string().nullable().optional(),
        deviceId: z.string().uuid(),
        expectedVersion: z.number().int().positive().optional(),
      })
      .safeParse(req.body);
    if (!body.success) {
      return reply.code(400).send({ error: 'bad_body' });
    }
    try {
      const row = await deps.resources.putResource({
        accountId: req.auth!.accountId,
        kind: parsedParams.data.kind,
        id: parsedParams.data.id,
        ciphertext: Buffer.from(body.data.ciphertext, 'base64'),
        integrity: body.data.integrity ?? null,
        prevHash: body.data.prevHash
          ? Buffer.from(body.data.prevHash, 'base64')
          : null,
        deviceId: body.data.deviceId,
        expectedVersion: body.data.expectedVersion,
      });
      return reply.code(200).send(toWire(row));
    } catch (err) {
      if ((err as Error).message.startsWith('version_conflict')) {
        return reply.code(409).send({
          error: 'version_conflict',
          message: (err as Error).message,
        });
      }
      return reply.code(500).send({ error: 'internal', message: (err as Error).message });
    }
  });

  app.delete(
    '/resources/:kind/:id',
    { preHandler: auth, config: writeLimit },
    async (req, reply) => {
      const parsedParams = z
        .object({ kind: kindSchema, id: idSchema })
        .safeParse(req.params);
      if (!parsedParams.success) {
        return reply.code(400).send({ error: 'bad_params' });
      }
      const body = z
        .object({ deviceId: z.string().uuid() })
        .safeParse(req.body ?? {});
      if (!body.success) {
        return reply.code(400).send({ error: 'bad_body' });
      }
      await deps.resources.deleteResource(
        req.auth!.accountId,
        parsedParams.data.kind,
        parsedParams.data.id,
        body.data.deviceId,
      );
      return reply.code(204).send();
    },
  );
}
