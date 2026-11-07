import { createHash } from 'node:crypto';
import type { Db } from '../db.js';
import { queryMany, queryOne, withTx } from '../db.js';
import type { AuditService } from './audit.js';

/**
 * Event-sourced zero-knowledge sync. All `payload` bytes are opaque to the
 * server. The only plaintext metadata we accept is `payloadType` (needed for
 * quota accounting and future policy routing) and `integrity` — a small JSON
 * object the client uses to assert plaintext invariants it wants us to help
 * enforce (e.g. combined beneficiary basis points must be ≤ 10,000).
 */
export interface SyncEventInput {
  id: string;
  deviceId: string;
  payloadType: string;
  payload: Uint8Array | Buffer;
  prevHash: Uint8Array | Buffer | null;
  integrity?: Record<string, unknown>;
  createdAt?: Date;
}

export interface SyncEventRow {
  id: string;
  deviceId: string;
  payloadType: string;
  payload: Buffer;
  prevHash: Buffer | null;
  hash: Buffer;
  integrity: Record<string, unknown> | null;
  receivedAt: Date;
  createdAt: Date;
}

export class SyncService {
  constructor(
    private readonly db: Db,
    private readonly audit: AuditService,
  ) {}

  /** Ingests a batch of events. Idempotent on `id` so retries from a shaky
   *  connection never duplicate. */
  async ingest(accountId: string, events: SyncEventInput[]): Promise<number> {
    if (events.length === 0) return 0;
    let inserted = 0;
    await withTx(this.db, async (client) => {
      for (const event of events) {
        this.validateIntegrity(event);
        const payload = Buffer.from(event.payload);
        const prevHash = event.prevHash ? Buffer.from(event.prevHash) : null;
        const hash = createHash('sha256')
          .update(prevHash ?? Buffer.alloc(0))
          .update(event.id)
          .update(event.payloadType)
          .update(payload)
          .digest();
        const createdAt = event.createdAt ?? new Date();
        const result = await client.query(
          `insert into events (id, account_id, device_id, payload_type, payload, prev_hash, hash, integrity, created_at)
           values ($1,$2,$3,$4,$5,$6,$7,$8,$9)
           on conflict (id) do nothing`,
          [
            event.id,
            accountId,
            event.deviceId,
            event.payloadType,
            payload,
            prevHash,
            hash,
            event.integrity ? JSON.stringify(event.integrity) : null,
            createdAt,
          ],
        );
        inserted += result.rowCount ?? 0;
      }
    });
    if (inserted > 0) {
      await this.audit.record({
        accountId,
        actor: { kind: 'user', id: accountId },
        action: 'sync.events.ingested',
        resource: `account:${accountId}`,
        context: { inserted, batch: events.length },
      });
    }
    return inserted;
  }

  /** Returns events strictly after `sinceReceivedAt` for the account. The
   *  cursor is the `received_at` timestamp of the last event the client has.
   *  A null cursor fetches from the beginning. */
  async pull(accountId: string, sinceReceivedAt: Date | null, limit = 500): Promise<SyncEventRow[]> {
    const capped = Math.min(Math.max(limit, 1), 2000);
    const rows = await queryMany<{
      id: string;
      device_id: string;
      payload_type: string;
      payload: Buffer;
      prev_hash: Buffer | null;
      hash: Buffer;
      integrity: Record<string, unknown> | null;
      received_at: Date;
      created_at: Date;
    }>(
      this.db,
      `select id, device_id, payload_type, payload, prev_hash, hash, integrity,
              received_at, created_at
         from events
        where account_id = $1 and received_at > coalesce($2, '-infinity'::timestamptz)
        order by received_at asc, id asc
        limit ${capped}`,
      [accountId, sinceReceivedAt],
    );
    return rows.map((r) => ({
      id: r.id,
      deviceId: r.device_id,
      payloadType: r.payload_type,
      payload: r.payload,
      prevHash: r.prev_hash,
      hash: r.hash,
      integrity: r.integrity,
      receivedAt: r.received_at,
      createdAt: r.created_at,
    }));
  }

  /** The content-key envelope is per account. We overwrite on rotation. */
  async upsertEnvelope(
    accountId: string,
    wrappedContentKey: Buffer,
    version: number,
  ): Promise<void> {
    await this.db.query(
      `insert into vault_envelopes (account_id, wrapped_content_key, version, rotated_at)
       values ($1, $2, $3, now())
       on conflict (account_id) do update
         set wrapped_content_key = excluded.wrapped_content_key,
             version = excluded.version,
             rotated_at = now()`,
      [accountId, wrappedContentKey, version],
    );
    await this.audit.record({
      accountId,
      actor: { kind: 'user', id: accountId },
      action: 'sync.envelope.rotated',
      resource: `account:${accountId}`,
      context: { version },
    });
  }

  async getEnvelope(
    accountId: string,
  ): Promise<{ wrappedContentKey: Buffer; version: number; rotatedAt: Date } | null> {
    const row = await queryOne<{ wrapped_content_key: Buffer; version: number; rotated_at: Date }>(
      this.db,
      `select wrapped_content_key, version, rotated_at
         from vault_envelopes where account_id = $1`,
      [accountId],
    );
    if (!row) return null;
    return {
      wrappedContentKey: row.wrapped_content_key,
      version: row.version,
      rotatedAt: row.rotated_at,
    };
  }

  /** Validates the `integrity` object for payload types where the server
   *  helps enforce plaintext invariants. */
  private validateIntegrity(event: SyncEventInput): void {
    if (event.payloadType === 'beneficiary_batch') {
      const total = Number(event.integrity?.['combined_bps'] ?? NaN);
      if (!Number.isFinite(total) || total < 0 || total > 10_000) {
        throw new Error('beneficiary_batch.combined_bps must be between 0 and 10000');
      }
    }
    if (event.payloadType === 'asset') {
      const bps = Number(event.integrity?.['ownership_bps'] ?? NaN);
      if (!Number.isFinite(bps) || bps < 0 || bps > 10_000) {
        throw new Error('asset.ownership_bps must be between 0 and 10000');
      }
    }
    if (event.payloadType === 'ledger_event') {
      const amount = Number(event.integrity?.['amount_ugx'] ?? NaN);
      if (!Number.isFinite(amount) || amount < 0) {
        throw new Error('ledger_event.amount_ugx must be a non-negative integer');
      }
    }
  }
}
