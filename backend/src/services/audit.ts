import { createHash } from 'node:crypto';
import { ulid } from 'ulid';
import type { Db } from '../db.js';
import { queryMany, queryOne, withTx } from '../db.js';

/**
 * Deterministic JSON.stringify — sorts object keys so a semantically-equal
 * payload serialises to the same bytes regardless of insertion order. The
 * audit Merkle chain depends on this: a verifier recomputing the hash from
 * row data must land on the same bytes the writer saw.
 */
function canonicalJson(value: unknown): string {
  if (value === null || value === undefined) return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  if (typeof value === 'object') {
    const keys = Object.keys(value as Record<string, unknown>).sort();
    const body = keys
      .map((k) => `${JSON.stringify(k)}:${canonicalJson((value as Record<string, unknown>)[k])}`)
      .join(',');
    return `{${body}}`;
  }
  return JSON.stringify(value);
}

export interface AuditActor {
  kind: 'user' | 'service' | 'admin' | 'system';
  id?: string;
}

export interface AuditRecordInput {
  accountId?: string | null;
  actor: AuditActor;
  action: string;
  resource?: string;
  context?: Record<string, unknown>;
}

export interface AuditEntry {
  id: string;
  accountId: string | null;
  actorKind: AuditActor['kind'];
  actorId: string | null;
  action: string;
  resource: string | null;
  context: Record<string, unknown> | null;
  prevHash: Buffer | null;
  hash: Buffer;
  createdAt: Date;
}

/**
 * Append-only audit log with a per-account Merkle chain. Each new entry
 * hashes `(prevHash || canonicalPayload)` so verification can walk the chain
 * and detect any insertion, deletion or reordering.
 */
export class AuditService {
  constructor(private readonly db: Db) {}

  async record(input: AuditRecordInput): Promise<AuditEntry> {
    return withTx(this.db, async (client) => {
      const prev = await client.query<{ hash: Buffer }>(
        `select hash from audit_entries
          where account_id ${input.accountId ? '= $1' : 'is null'}
          order by created_at desc, id desc
          limit 1`,
        input.accountId ? [input.accountId] : [],
      );
      const prevHash = prev.rows[0]?.hash ?? null;
      const id = ulid();
      const canonical = canonicalJson({
        id,
        account_id: input.accountId ?? null,
        actor_kind: input.actor.kind,
        actor_id: input.actor.id ?? null,
        action: input.action,
        resource: input.resource ?? null,
        context: input.context ?? null,
      });
      const hash = createHash('sha256')
        .update(prevHash ?? Buffer.alloc(0))
        .update(canonical)
        .digest();
      await client.query(
        `insert into audit_entries (id, account_id, actor_kind, actor_id, action, resource, context, prev_hash, hash)
         values ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
        [
          id,
          input.accountId ?? null,
          input.actor.kind,
          input.actor.id ?? null,
          input.action,
          input.resource ?? null,
          input.context ? canonicalJson(input.context) : null,
          prevHash,
          hash,
        ],
      );
      return {
        id,
        accountId: input.accountId ?? null,
        actorKind: input.actor.kind,
        actorId: input.actor.id ?? null,
        action: input.action,
        resource: input.resource ?? null,
        context: input.context ?? null,
        prevHash,
        hash,
        createdAt: new Date(),
      };
    });
  }

  /** Returns the last N entries for an account, newest first. */
  async listRecent(accountId: string | null, limit = 50): Promise<AuditEntry[]> {
    const rows = await queryMany<{
      id: string;
      account_id: string | null;
      actor_kind: AuditActor['kind'];
      actor_id: string | null;
      action: string;
      resource: string | null;
      context: Record<string, unknown> | null;
      prev_hash: Buffer | null;
      hash: Buffer;
      created_at: Date;
    }>(
      this.db,
      `select id, account_id, actor_kind, actor_id, action, resource, context, prev_hash, hash, created_at
         from audit_entries
         where account_id ${accountId ? '= $1' : 'is null'}
         order by created_at desc, id desc
         limit ${Math.min(Math.max(limit, 1), 500)}`,
      accountId ? [accountId] : [],
    );
    return rows.map((r) => ({
      id: r.id,
      accountId: r.account_id,
      actorKind: r.actor_kind,
      actorId: r.actor_id,
      action: r.action,
      resource: r.resource,
      context: r.context,
      prevHash: r.prev_hash,
      hash: r.hash,
      createdAt: r.created_at,
    }));
  }

  /** Walks the per-account chain and returns the tip hash plus a verified
   *  flag. Used by the weekly transparency anchor job. */
  async verifyChain(
    accountId: string | null,
  ): Promise<{ verified: boolean; tipHash: Buffer | null; count: number; brokenAt?: string }> {
    const rows = await queryMany<{ id: string; context: Record<string, unknown> | null; prev_hash: Buffer | null; hash: Buffer; account_id: string | null; actor_kind: AuditActor['kind']; actor_id: string | null; action: string; resource: string | null }>(
      this.db,
      `select id, account_id, actor_kind, actor_id, action, resource, context, prev_hash, hash
         from audit_entries
         where account_id ${accountId ? '= $1' : 'is null'}
         order by created_at asc, id asc`,
      accountId ? [accountId] : [],
    );
    let last: Buffer | null = null;
    for (const r of rows) {
      const canonical = canonicalJson({
        id: r.id,
        account_id: r.account_id,
        actor_kind: r.actor_kind,
        actor_id: r.actor_id,
        action: r.action,
        resource: r.resource,
        context: r.context,
      });
      const expected: Buffer = createHash('sha256')
        .update(last ?? Buffer.alloc(0))
        .update(canonical)
        .digest();
      if (!expected.equals(r.hash)) {
        return { verified: false, tipHash: last, count: rows.length, brokenAt: r.id };
      }
      last = r.hash;
    }
    return { verified: true, tipHash: last, count: rows.length };
  }

  /** Looks up a single entry by id (used by the `/audit/entries/:id` route). */
  async findById(id: string): Promise<AuditEntry | null> {
    const row = await queryOne<{
      id: string;
      account_id: string | null;
      actor_kind: AuditActor['kind'];
      actor_id: string | null;
      action: string;
      resource: string | null;
      context: Record<string, unknown> | null;
      prev_hash: Buffer | null;
      hash: Buffer;
      created_at: Date;
    }>(
      this.db,
      `select id, account_id, actor_kind, actor_id, action, resource, context, prev_hash, hash, created_at
         from audit_entries where id = $1`,
      [id],
    );
    if (!row) return null;
    return {
      id: row.id,
      accountId: row.account_id,
      actorKind: row.actor_kind,
      actorId: row.actor_id,
      action: row.action,
      resource: row.resource,
      context: row.context,
      prevHash: row.prev_hash,
      hash: row.hash,
      createdAt: row.created_at,
    };
  }
}
