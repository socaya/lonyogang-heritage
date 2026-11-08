import type { Db } from '../db.js';
import { queryMany, queryOne } from '../db.js';
import type { AuditService } from './audit.js';

export type ResourceKind =
  | 'asset'
  | 'liability'
  | 'ledger_event'
  | 'goal'
  | 'beneficiary_batch'
  | 'document_record'
  | 'reminder'
  | 'trusted_contact'
  | 'valuation'
  | 'schedule'
  | 'fx_rate'
  | 'alert_dismissal'
  | 'target_weights';

export const RESOURCE_KINDS: ResourceKind[] = [
  'asset',
  'liability',
  'ledger_event',
  'goal',
  'beneficiary_batch',
  'document_record',
  'reminder',
  'trusted_contact',
  'valuation',
  'schedule',
  'fx_rate',
  'alert_dismissal',
  'target_weights',
];

export interface ResourceRow {
  accountId: string;
  kind: ResourceKind;
  id: string;
  ciphertext: Buffer;
  integrity: Record<string, unknown> | null;
  prevHash: Buffer | null;
  deviceId: string;
  version: number;
  createdAt: Date;
  updatedAt: Date;
  deletedAt: Date | null;
}

/**
 * CRUD surface for the per-entity resource layer that lives alongside
 * the append-only /sync/events stream.
 *
 * - `putResource` upserts the latest ciphertext for an (account, kind, id)
 *   tuple and increments `version` so a concurrent writer can be detected.
 * - `listResources` yields the current (non-deleted) state for one kind,
 *   optionally filtered by a server-side cursor so a web client can poll
 *   incrementally.
 * - `deleteResource` tombstones the row. The ciphertext stays until a
 *   compaction job runs so the audit trail can still cross-reference it.
 *
 * The server never decrypts `ciphertext`; it is handed back to the client
 * verbatim. The only plaintext the server inspects is `integrity`, which
 * carries the same shape the /sync/events pipeline already validates.
 */
export class ResourcesService {
  constructor(
    private readonly db: Db,
    private readonly audit: AuditService,
  ) {}

  async listByKind(
    accountId: string,
    kind: ResourceKind,
    options: { since?: Date; limit?: number; includeDeleted?: boolean } = {},
  ): Promise<ResourceRow[]> {
    const limit = Math.min(Math.max(options.limit ?? 500, 1), 2000);
    const params: unknown[] = [accountId, kind];
    const clauses = ['account_id = $1', 'kind = $2'];
    if (!options.includeDeleted) clauses.push('deleted_at is null');
    if (options.since) {
      params.push(options.since);
      clauses.push(`updated_at > $${params.length}`);
    }
    return queryMany<ResourceRow>(
      this.db,
      `select account_id as "accountId", kind, id, ciphertext, integrity,
              prev_hash as "prevHash", device_id as "deviceId", version,
              created_at as "createdAt", updated_at as "updatedAt",
              deleted_at as "deletedAt"
         from resources
        where ${clauses.join(' and ')}
        order by updated_at asc
        limit ${limit}`,
      params,
    );
  }

  async getOne(
    accountId: string,
    kind: ResourceKind,
    id: string,
  ): Promise<ResourceRow | null> {
    return queryOne<ResourceRow>(
      this.db,
      `select account_id as "accountId", kind, id, ciphertext, integrity,
              prev_hash as "prevHash", device_id as "deviceId", version,
              created_at as "createdAt", updated_at as "updatedAt",
              deleted_at as "deletedAt"
         from resources
        where account_id = $1 and kind = $2 and id = $3`,
      [accountId, kind, id],
    );
  }

  async putResource(input: {
    accountId: string;
    kind: ResourceKind;
    id: string;
    ciphertext: Buffer;
    integrity: Record<string, unknown> | null;
    prevHash: Buffer | null;
    deviceId: string;
    expectedVersion?: number;
  }): Promise<ResourceRow> {
    // Optimistic-concurrency: when expectedVersion is supplied, the UPDATE
    // clause rejects the write if the stored row has moved on. The web
    // client uses this to avoid clobbering a mobile edit.
    if (input.expectedVersion !== undefined) {
      const existing = await this.getOne(input.accountId, input.kind, input.id);
      if (existing && existing.version !== input.expectedVersion) {
        throw new Error(
          `version_conflict: stored=${existing.version} expected=${input.expectedVersion}`,
        );
      }
    }
    const row = await queryOne<ResourceRow>(
      this.db,
      `insert into resources
         (account_id, kind, id, ciphertext, integrity, prev_hash, device_id, version)
       values ($1, $2, $3, $4, $5, $6, $7, 1)
       on conflict (account_id, kind, id) do update
         set ciphertext = excluded.ciphertext,
             integrity  = excluded.integrity,
             prev_hash  = excluded.prev_hash,
             device_id  = excluded.device_id,
             version    = resources.version + 1,
             updated_at = now(),
             deleted_at = null
       returning account_id as "accountId", kind, id, ciphertext, integrity,
                 prev_hash as "prevHash", device_id as "deviceId", version,
                 created_at as "createdAt", updated_at as "updatedAt",
                 deleted_at as "deletedAt"`,
      [
        input.accountId,
        input.kind,
        input.id,
        input.ciphertext,
        input.integrity,
        input.prevHash,
        input.deviceId,
      ],
    );
    if (!row) throw new Error('Upsert returned no row');
    await this.audit.record({
      accountId: input.accountId,
      actor: { kind: 'user', id: input.accountId },
      action: 'resource.upserted',
      resource: `${input.kind}:${input.id}`,
      context: { version: row.version, kind: input.kind },
    });
    return row;
  }

  async deleteResource(
    accountId: string,
    kind: ResourceKind,
    id: string,
    deviceId: string,
  ): Promise<void> {
    const result = await this.db.query(
      `update resources
          set deleted_at = now(),
              device_id = $4,
              version = version + 1,
              updated_at = now()
        where account_id = $1 and kind = $2 and id = $3 and deleted_at is null`,
      [accountId, kind, id, deviceId],
    );
    if (result.rowCount === 0) return;
    await this.audit.record({
      accountId,
      actor: { kind: 'user', id: accountId },
      action: 'resource.deleted',
      resource: `${kind}:${id}`,
    });
  }

  /// Tombstones every live row of one kind for one account. Used by
  /// bulk operations like "clear all dismissed alerts" where the client
  /// does not want to walk every id. Returns the count tombstoned.
  async clearKind(
    accountId: string,
    kind: ResourceKind,
    deviceId: string,
  ): Promise<number> {
    const result = await this.db.query(
      `update resources
          set deleted_at = now(),
              device_id = $3,
              version = version + 1,
              updated_at = now()
        where account_id = $1 and kind = $2 and deleted_at is null`,
      [accountId, kind, deviceId],
    );
    const cleared = result.rowCount ?? 0;
    if (cleared > 0) {
      await this.audit.record({
        accountId,
        actor: { kind: 'user', id: accountId },
        action: 'resource.kind_cleared',
        resource: `kind:${kind}`,
        context: { cleared },
      });
    }
    return cleared;
  }

  /** For tests + health probes: counts live resources per kind. */
  async countByKind(accountId: string): Promise<Record<string, number>> {
    const rows = await queryMany<{ kind: string; c: number }>(
      this.db,
      `select kind, count(*)::int as c
         from resources
        where account_id = $1 and deleted_at is null
        group by kind`,
      [accountId],
    );
    return Object.fromEntries(rows.map((r) => [r.kind, r.c]));
  }
}
