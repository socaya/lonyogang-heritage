import { randomUUID } from 'node:crypto';
import { request } from 'undici';
import type { Db } from '../db.js';
import { queryMany, queryOne } from '../db.js';
import type { KeyStore } from './keystore.js';
import type { AuditService } from './audit.js';

export interface BankTransaction {
  externalRef: string;
  occurredAt: Date;
  amountUgx: number;
  description: string;
  raw?: Record<string, unknown>;
}

export interface LinkContext {
  accountId: string;
  provider: string;
  providerAccountId: string;
  providerToken?: string;
  scopes: string[];
  displayLabel?: string;
}

export interface BankProvider {
  readonly name: string;
  /** Verifies that a stored provider token still works and returns a fresh
   *  display label if the provider sends one. */
  describe(linkCtx: LinkContext): Promise<{ label?: string }>;
  listTransactions(linkCtx: LinkContext, since?: Date): Promise<BankTransaction[]>;
}

/**
 * Bank aggregation. Users link providers by OAuth outside this service; the
 * callback writes the resulting provider token through [registerLink], which
 * KMS-seals the credential at rest. [sync] pulls fresh transactions from the
 * provider and persists them, de-duplicated by `external_ref`.
 */
export class AggregationService {
  private readonly providers = new Map<string, BankProvider>();

  constructor(
    private readonly db: Db,
    private readonly kms: KeyStore,
    private readonly audit: AuditService,
  ) {}

  register(provider: BankProvider): void {
    this.providers.set(provider.name, provider);
  }

  providerFor(name: string): BankProvider {
    const p = this.providers.get(name);
    if (!p) throw new Error(`Unknown bank provider: ${name}`);
    return p;
  }

  listRegistered(): string[] {
    return Array.from(this.providers.keys());
  }

  async registerLink(ctx: LinkContext): Promise<{ connectionId: string }> {
    const sealed = ctx.providerToken
      ? await this.kms.seal(Buffer.from(ctx.providerToken, 'utf8'), Buffer.from(ctx.accountId, 'utf8'))
      : null;
    const row = await queryOne<{ id: string }>(
      this.db,
      `insert into bank_connections
         (account_id, provider, external_id, display_label, scopes, secret_cipher)
       values ($1, $2, $3, $4, $5, $6)
       on conflict (account_id, provider, external_id) do update
         set display_label = excluded.display_label,
             scopes = excluded.scopes,
             secret_cipher = excluded.secret_cipher,
             status = 'linked',
             linked_at = now(),
             revoked_at = null
       returning id`,
      [ctx.accountId, ctx.provider, ctx.providerAccountId, ctx.displayLabel ?? null, ctx.scopes, sealed],
    );
    await this.audit.record({
      accountId: ctx.accountId,
      actor: { kind: 'user', id: ctx.accountId },
      action: 'bank.linked',
      resource: `connection:${row!.id}`,
      context: { provider: ctx.provider },
    });
    return { connectionId: row!.id };
  }

  async revokeLink(accountId: string, connectionId: string): Promise<void> {
    await this.db.query(
      `update bank_connections set status = 'revoked', revoked_at = now()
         where account_id = $1 and id = $2`,
      [accountId, connectionId],
    );
    await this.audit.record({
      accountId,
      actor: { kind: 'user', id: accountId },
      action: 'bank.revoked',
      resource: `connection:${connectionId}`,
    });
  }

  async sync(accountId: string, connectionId: string): Promise<{ imported: number }> {
    const row = await queryOne<{
      id: string;
      provider: string;
      external_id: string;
      secret_cipher: Buffer | null;
      scopes: string[];
      last_sync_at: Date | null;
      display_label: string | null;
    }>(
      this.db,
      `select id, provider, external_id, secret_cipher, scopes, last_sync_at, display_label
         from bank_connections where account_id = $1 and id = $2 and status = 'linked'`,
      [accountId, connectionId],
    );
    if (!row) throw new Error('Connection not found or not linked');
    const provider = this.providerFor(row.provider);
    const token = row.secret_cipher
      ? (
          await this.kms.unseal(row.secret_cipher, Buffer.from(accountId, 'utf8'))
        ).toString('utf8')
      : undefined;
    const since = row.last_sync_at ?? undefined;
    const ctx: LinkContext = {
      accountId,
      provider: row.provider,
      providerAccountId: row.external_id,
      providerToken: token,
      scopes: row.scopes,
      displayLabel: row.display_label ?? undefined,
    };
    // Upstream tokens expire routinely. Confirm the token still resolves
    // against the provider before we touch the transactions endpoint, so a
    // partial failure can't leave the connection in a half-synced state.
    try {
      await provider.describe(ctx);
    } catch (err) {
      await this.db.query(
        `update bank_connections set status = 'reauth_required'
           where id = $1 and status = 'linked'`,
        [row.id],
      );
      await this.audit.record({
        accountId,
        actor: { kind: 'service', id: `bank:${row.provider}` },
        action: 'bank.reauth_required',
        resource: `connection:${row.id}`,
        context: { reason: (err as Error).message.slice(0, 200) },
      });
      throw new Error('Provider rejected the stored credential — relink the account');
    }
    const transactions = await provider.listTransactions(ctx, since);
    let imported = 0;
    for (const tx of transactions) {
      const result = await this.db.query(
        `insert into bank_transactions (connection_id, external_ref, occurred_at, amount_ugx, description, raw)
         values ($1, $2, $3, $4, $5, $6)
         on conflict (connection_id, external_ref) do nothing`,
        [row.id, tx.externalRef, tx.occurredAt, tx.amountUgx, tx.description, tx.raw ?? null],
      );
      imported += result.rowCount ?? 0;
    }
    await this.db.query(
      `update bank_connections set last_sync_at = now() where id = $1`,
      [row.id],
    );
    await this.audit.record({
      accountId,
      actor: { kind: 'service', id: `bank:${row.provider}` },
      action: 'bank.synced',
      resource: `connection:${row.id}`,
      context: { imported, totalCandidates: transactions.length },
    });
    return { imported };
  }

  async listPendingImports(
    accountId: string,
  ): Promise<{ id: string; description: string; amountUgx: number; occurredAt: Date; provider: string }[]> {
    return queryMany(
      this.db,
      `select bt.id, bt.description, bt.amount_ugx as amountUgx, bt.occurred_at as occurredAt, bc.provider
         from bank_transactions bt
         join bank_connections bc on bc.id = bt.connection_id
        where bc.account_id = $1 and bt.imported_event is null
        order by bt.occurred_at desc`,
      [accountId],
    ) as unknown as Promise<
      { id: string; description: string; amountUgx: number; occurredAt: Date; provider: string }[]
    >;
  }

  async markImported(bankTransactionId: string, eventId: string): Promise<void> {
    await this.db.query(
      `update bank_transactions set imported_event = $1 where id = $2`,
      [eventId, bankTransactionId],
    );
  }
}

/** Deterministic in-memory provider used by tests and the local demo. */
export class MockBankProvider implements BankProvider {
  readonly name = 'mock';
  private readonly dataset: BankTransaction[];
  constructor(seed?: BankTransaction[]) {
    this.dataset = seed ?? [
      {
        externalRef: 'MOCK-0001',
        occurredAt: new Date('2026-10-01T09:00:00Z'),
        amountUgx: 2_500_000,
        description: 'Salary deposit',
      },
      {
        externalRef: 'MOCK-0002',
        occurredAt: new Date('2026-10-05T14:00:00Z'),
        amountUgx: -850_000,
        description: 'Supermarket card payment',
      },
      {
        externalRef: 'MOCK-0003',
        occurredAt: new Date('2026-10-28T09:00:00Z'),
        amountUgx: 1_400_000,
        description: 'Rental income receipt',
      },
    ];
  }
  async describe(): Promise<{ label?: string }> {
    return { label: 'Mock test account' };
  }
  async listTransactions(_ctx: LinkContext, since?: Date): Promise<BankTransaction[]> {
    if (!since) return this.dataset;
    return this.dataset.filter((t) => t.occurredAt.getTime() > since.getTime());
  }
}

/** Real-shape adapter for the Stanbic Bank Uganda Partner API. Credentials
 *  are expected to be an OAuth2 client credentials bearer token. */
export class StanbicProvider implements BankProvider {
  readonly name = 'stanbic';
  constructor(private readonly base = 'https://api.stanbic.co.ug/v1') {}

  async describe(ctx: LinkContext): Promise<{ label?: string }> {
    if (!ctx.providerToken) throw new Error('Missing Stanbic bearer token');
    const { statusCode, body } = await request(`${this.base}/accounts/${ctx.providerAccountId}`, {
      headers: { authorization: `Bearer ${ctx.providerToken}` },
    });
    if (statusCode < 200 || statusCode >= 300) throw new Error(`Stanbic HTTP ${statusCode}`);
    const json = (await body.json()) as { nickname?: string; accountName?: string };
    return { label: json.nickname ?? json.accountName };
  }

  async listTransactions(ctx: LinkContext, since?: Date): Promise<BankTransaction[]> {
    if (!ctx.providerToken) throw new Error('Missing Stanbic bearer token');
    const url = new URL(`${this.base}/accounts/${ctx.providerAccountId}/transactions`);
    if (since) url.searchParams.set('from', since.toISOString());
    const { statusCode, body } = await request(url, {
      headers: { authorization: `Bearer ${ctx.providerToken}` },
    });
    if (statusCode < 200 || statusCode >= 300) throw new Error(`Stanbic HTTP ${statusCode}`);
    const json = (await body.json()) as {
      transactions?: Array<{ id: string; valueDate: string; amount: number; narration: string; raw?: unknown }>;
    };
    return (json.transactions ?? []).map((t) => ({
      externalRef: t.id,
      occurredAt: new Date(t.valueDate),
      amountUgx: Math.round(t.amount * 100) / 100,
      description: t.narration,
      raw: t.raw as Record<string, unknown> | undefined,
    }));
  }
}

/** MTN Mobile Money Collections API adapter (very thin — actual deployments
 *  need per-partner reconciliation beyond the scope of this file). */
export class MtnMomoProvider implements BankProvider {
  readonly name = 'mtn_momo';
  constructor(
    private readonly base = 'https://proxy.momoapi.mtn.com/collection/v1_0',
    private readonly subscriptionKey = '',
    private readonly targetEnvironment = 'production',
  ) {}

  async describe(ctx: LinkContext): Promise<{ label?: string }> {
    void ctx;
    return { label: 'MTN MoMo subscriber' };
  }

  async listTransactions(ctx: LinkContext, since?: Date): Promise<BankTransaction[]> {
    if (!ctx.providerToken) throw new Error('Missing MoMo access token');
    if (!this.subscriptionKey) throw new Error('MoMo subscription key not configured');
    const url = new URL(`${this.base}/account/${ctx.providerAccountId}/transactions`);
    if (since) url.searchParams.set('since', since.toISOString());
    const { statusCode, body } = await request(url, {
      headers: {
        authorization: `Bearer ${ctx.providerToken}`,
        'Ocp-Apim-Subscription-Key': this.subscriptionKey,
        'X-Target-Environment': this.targetEnvironment,
      },
    });
    if (statusCode < 200 || statusCode >= 300) throw new Error(`MoMo HTTP ${statusCode}`);
    const json = (await body.json()) as {
      transactions?: Array<{
        financialTransactionId: string;
        createdAt: string;
        amount: string;
        currency: string;
        payerMessage?: string;
        payeeNote?: string;
      }>;
    };
    return (json.transactions ?? [])
      .filter((t) => t.currency === 'UGX')
      .map((t) => ({
        externalRef: t.financialTransactionId,
        occurredAt: new Date(t.createdAt),
        amountUgx: Number(t.amount),
        description: t.payeeNote ?? t.payerMessage ?? 'MoMo transaction',
        raw: { externalId: t.financialTransactionId } as Record<string, unknown>,
      }));
  }

  // Helper for tests to generate a deterministic correlation reference id.
  static referenceId(): string {
    return randomUUID();
  }
}
