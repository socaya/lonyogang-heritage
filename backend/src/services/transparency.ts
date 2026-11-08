import { request } from 'undici';
import type { Db } from '../db.js';
import { queryMany } from '../db.js';
import type { AuditService } from './audit.js';

export interface TransparencyAnchor {
  id: string;
  accountId: string | null;
  scope: 'account' | 'global';
  tipHash: Buffer;
  entryCount: number;
  verified: boolean;
  brokenAt: string | null;
  proof: Buffer | null;
  source: string | null;
  createdAt: Date;
}

export interface TransparencyNotary {
  readonly name: string;
  /** Submits a hash, returns an opaque proof blob the notary issues. */
  anchor(tipHash: Buffer): Promise<Buffer>;
}

/**
 * Walks every account's audit chain on a schedule (nominally weekly),
 * verifies integrity, persists the tip hash and — when a notary is
 * configured — submits it to an external transparency log so an adversary
 * cannot silently rewrite history after the fact.
 */
export class TransparencyService {
  constructor(
    private readonly db: Db,
    private readonly audit: AuditService,
    private readonly notary: TransparencyNotary,
  ) {}

  async anchorAllAccounts(): Promise<{ anchored: number; verified: number }> {
    const accounts = await queryMany<{ id: string }>(
      this.db,
      `select distinct account_id as id from audit_entries where account_id is not null`,
    );
    let anchored = 0;
    let verified = 0;
    for (const { id } of accounts) {
      const result = await this.anchorAccount(id);
      if (!result) continue;
      anchored += 1;
      if (result.verified) verified += 1;
    }
    return { anchored, verified };
  }

  async anchorAccount(accountId: string): Promise<TransparencyAnchor | null> {
    const chain = await this.audit.verifyChain(accountId);
    if (!chain.tipHash) return null;
    const proof = chain.verified ? await safeNotarise(this.notary, chain.tipHash) : null;
    const row = await this.db.query<{
      id: string;
      tip_hash: Buffer;
      entry_count: string;
      verified: boolean;
      broken_at: string | null;
      anchor_proof: Buffer | null;
      anchor_source: string | null;
      created_at: Date;
    }>(
      `insert into transparency_anchors
         (account_id, anchor_scope, tip_hash, entry_count, verified, broken_at, anchor_proof, anchor_source)
       values ($1, 'account', $2, $3, $4, $5, $6, $7)
       returning id, tip_hash, entry_count, verified, broken_at, anchor_proof, anchor_source, created_at`,
      [
        accountId,
        chain.tipHash,
        chain.count,
        chain.verified,
        chain.brokenAt ?? null,
        proof,
        proof ? this.notary.name : null,
      ],
    );
    await this.audit.record({
      accountId,
      actor: { kind: 'system' },
      action: 'audit.anchored',
      resource: `account:${accountId}`,
      context: {
        verified: chain.verified,
        entryCount: chain.count,
        tipHash: chain.tipHash.toString('base64'),
        brokenAt: chain.brokenAt ?? null,
      },
    });
    const inserted = row.rows[0]!;
    return {
      id: inserted.id,
      accountId,
      scope: 'account',
      tipHash: inserted.tip_hash,
      entryCount: Number(inserted.entry_count),
      verified: inserted.verified,
      brokenAt: inserted.broken_at,
      proof: inserted.anchor_proof,
      source: inserted.anchor_source,
      createdAt: inserted.created_at,
    };
  }

  async listAnchors(accountId: string): Promise<TransparencyAnchor[]> {
    const rows = await queryMany<{
      id: string;
      account_id: string;
      tip_hash: Buffer;
      entry_count: string;
      verified: boolean;
      broken_at: string | null;
      anchor_proof: Buffer | null;
      anchor_source: string | null;
      created_at: Date;
    }>(
      this.db,
      `select id, account_id, tip_hash, entry_count, verified, broken_at, anchor_proof, anchor_source, created_at
         from transparency_anchors
         where account_id = $1
         order by created_at desc`,
      [accountId],
    );
    return rows.map((r) => ({
      id: r.id,
      accountId: r.account_id,
      scope: 'account',
      tipHash: r.tip_hash,
      entryCount: Number(r.entry_count),
      verified: r.verified,
      brokenAt: r.broken_at,
      proof: r.anchor_proof,
      source: r.anchor_source,
      createdAt: r.created_at,
    }));
  }
}

async function safeNotarise(
  notary: TransparencyNotary,
  tipHash: Buffer,
): Promise<Buffer | null> {
  try {
    return await notary.anchor(tipHash);
  } catch {
    // Anchor failures are tolerated: we still persist the hash locally so a
    // later job can retry. We refuse to fail the chain verification over a
    // transient notary outage.
    return null;
  }
}

/** Deterministic in-memory notary used by tests. */
export class InMemoryNotary implements TransparencyNotary {
  readonly name = 'in-memory';
  readonly anchors: Array<{ tipHash: Buffer; proof: Buffer }> = [];
  async anchor(tipHash: Buffer): Promise<Buffer> {
    const proof = Buffer.concat([Buffer.from('proof:'), tipHash]);
    this.anchors.push({ tipHash, proof });
    return proof;
  }
}

/** Submits a SHA-256 hash to the public OpenTimestamps calendar network and
 *  returns the resulting OTS binary proof. Suitable for weekly batches. */
export class OpenTimestampsNotary implements TransparencyNotary {
  readonly name = 'opentimestamps';
  constructor(
    private readonly calendars: string[] = [
      'https://alice.btc.calendar.opentimestamps.org',
      'https://bob.btc.calendar.opentimestamps.org',
      'https://finney.calendar.eternitywall.com',
    ],
  ) {}

  async anchor(tipHash: Buffer): Promise<Buffer> {
    if (tipHash.length !== 32) throw new Error('OpenTimestamps expects a SHA-256 digest');
    const responses = await Promise.all(
      this.calendars.map(async (calendar) => {
        const { statusCode, body } = await request(`${calendar}/digest`, {
          method: 'POST',
          headers: {
            accept: 'application/vnd.opentimestamps.v1',
            'content-type': 'application/vnd.opentimestamps.v1',
          },
          body: tipHash,
        });
        if (statusCode < 200 || statusCode >= 300) {
          throw new Error(`OpenTimestamps ${calendar} returned HTTP ${statusCode}`);
        }
        const chunks: Uint8Array[] = [];
        for await (const chunk of body) {
          chunks.push(chunk as Uint8Array);
        }
        return Buffer.concat(chunks.map((c) => Buffer.from(c)));
      }),
    );
    // Concatenate every calendar's commitment into a single proof blob. The
    // consuming side can split on the calendar count header we prepend.
    const header = Buffer.alloc(1);
    header.writeUInt8(responses.length, 0);
    return Buffer.concat([header, ...responses]);
  }
}
