import { createHmac, timingSafeEqual } from 'node:crypto';
import type { Db } from '../db.js';
import { queryOne, withTx } from '../db.js';
import type { AppConfig } from '../config.js';
import type { AuditService } from './audit.js';

export type SubscriptionTier = 'free' | 'heritage' | 'family';
export type SubscriptionStatus = 'active' | 'trialing' | 'past_due' | 'canceled';

/** Normalised view of a subscription event coming from any processor. */
export interface NormalizedPaymentEvent {
  provider: 'flutterwave' | 'stripe';
  externalRef: string;
  accountId: string;
  tier: SubscriptionTier;
  status: SubscriptionStatus;
  currentPeriodEnd: Date | null;
  raw: Record<string, unknown>;
}

export class PaymentsService {
  constructor(
    private readonly db: Db,
    private readonly config: AppConfig,
    private readonly audit: AuditService,
  ) {}

  async getSubscription(accountId: string): Promise<{
    tier: SubscriptionTier;
    status: SubscriptionStatus;
    currentPeriodEnd: Date | null;
    provider: string | null;
  }> {
    const row = await queryOne<{
      tier: SubscriptionTier;
      status: SubscriptionStatus;
      current_period_end: Date | null;
      provider: string | null;
    }>(
      this.db,
      `select tier, status, current_period_end, provider
         from subscriptions where account_id = $1`,
      [accountId],
    );
    if (!row) {
      return { tier: 'free', status: 'active', currentPeriodEnd: null, provider: null };
    }
    return {
      tier: row.tier,
      status: row.status,
      currentPeriodEnd: row.current_period_end,
      provider: row.provider,
    };
  }

  /**
   * Applies a provider webhook exactly once.
   *
   * Providers routinely retry a webhook (network blip, 5xx from us, dashboard
   * resend) and we must not double-apply. We take a provider-scoped lock on
   * webhook_idempotency(provider, external_ref); a conflict means the event
   * has already been applied and we return silently. The payment_events row
   * doubles as an audit trail, and the subscriptions row is the current
   * state we hand back to GET /billing/subscription.
   *
   * Returns true on first application and false when the event was a
   * duplicate retry.
   */
  async record(event: NormalizedPaymentEvent): Promise<boolean> {
    return withTx(this.db, async (client) => {
      const claim = await client.query(
        `insert into webhook_idempotency (provider, external_ref)
         values ($1, $2)
         on conflict do nothing`,
        [event.provider, event.externalRef],
      );
      if (claim.rowCount === 0) {
        // Duplicate retry — the first delivery already moved state.
        return false;
      }
      await client.query(
        `insert into payment_events (account_id, provider, external_ref, kind, payload)
         values ($1, $2, $3, $4, $5)`,
        [event.accountId, event.provider, event.externalRef, `${event.tier}:${event.status}`, event.raw],
      );
      await client.query(
        `insert into subscriptions (account_id, tier, provider, external_ref, status, current_period_end, updated_at)
         values ($1, $2, $3, $4, $5, $6, now())
         on conflict (account_id) do update
           set tier = excluded.tier,
               provider = excluded.provider,
               external_ref = excluded.external_ref,
               status = excluded.status,
               current_period_end = excluded.current_period_end,
               updated_at = now()`,
        [event.accountId, event.tier, event.provider, event.externalRef, event.status, event.currentPeriodEnd],
      );
      await this.audit.record({
        accountId: event.accountId,
        actor: { kind: 'service', id: event.provider },
        action: 'subscription.updated',
        resource: `subscription:${event.accountId}`,
        context: { tier: event.tier, status: event.status },
      });
      return true;
    });
  }

  /** Verifies a Flutterwave webhook per their documented secret-hash header. */
  verifyFlutterwaveSignature(headerValue: string | undefined): boolean {
    if (!this.config.FLUTTERWAVE_SECRET_HASH || !headerValue) return false;
    const expected = Buffer.from(this.config.FLUTTERWAVE_SECRET_HASH, 'utf8');
    const supplied = Buffer.from(headerValue, 'utf8');
    if (expected.length !== supplied.length) return false;
    return timingSafeEqual(expected, supplied);
  }

  /** Parses a Flutterwave webhook payload into our normalised shape. */
  parseFlutterwavePayload(body: unknown): NormalizedPaymentEvent | null {
    if (!body || typeof body !== 'object') return null;
    const b = body as Record<string, unknown>;
    const event = (b['event'] ?? b['type']) as string | undefined;
    const data = (b['data'] ?? {}) as Record<string, unknown>;
    const customer = (data['customer'] ?? {}) as Record<string, unknown>;
    const meta = (data['meta'] ?? {}) as Record<string, unknown>;
    const accountId = typeof meta['account_id'] === 'string' ? (meta['account_id'] as string) : undefined;
    if (!accountId) return null;
    const externalRef = String(data['tx_ref'] ?? data['id'] ?? '');
    const tier = normaliseTier(String(meta['tier'] ?? 'heritage'));
    const status = event === 'subscription.cancelled' ? 'canceled' : 'active';
    const currentPeriodEndRaw = data['next_payment_date'] ?? data['current_period_end'];
    const currentPeriodEnd = currentPeriodEndRaw
      ? new Date(String(currentPeriodEndRaw))
      : null;
    return {
      provider: 'flutterwave',
      externalRef,
      accountId,
      tier,
      status,
      currentPeriodEnd,
      raw: { event, data, customer },
    };
  }

  /** Verifies a Stripe webhook signature header. The header format is
   *  `t=…,v1=…`; we recompute the HMAC-SHA256 of `${t}.${rawBody}` using the
   *  configured whsec and compare in constant time. */
  verifyStripeSignature(rawBody: string, headerValue: string | undefined): boolean {
    if (!this.config.STRIPE_WEBHOOK_SECRET || !headerValue) return false;
    const parts = headerValue.split(',').map((p) => p.trim().split('='));
    const timestamp = parts.find(([k]) => k === 't')?.[1];
    const signatures = parts.filter(([k]) => k === 'v1').map(([, v]) => v);
    if (!timestamp || signatures.length === 0) return false;
    const expected = createHmac('sha256', this.config.STRIPE_WEBHOOK_SECRET)
      .update(`${timestamp}.${rawBody}`)
      .digest('hex');
    return signatures.some((sig) => {
      if (!sig || sig.length !== expected.length) return false;
      return timingSafeEqual(Buffer.from(expected), Buffer.from(sig));
    });
  }

  parseStripePayload(body: unknown): NormalizedPaymentEvent | null {
    if (!body || typeof body !== 'object') return null;
    const b = body as Record<string, unknown>;
    const type = b['type'] as string | undefined;
    const dataObject = ((b['data'] as Record<string, unknown>)?.['object'] ?? {}) as Record<string, unknown>;
    const metadata = (dataObject['metadata'] ?? {}) as Record<string, unknown>;
    const accountId = typeof metadata['account_id'] === 'string' ? (metadata['account_id'] as string) : undefined;
    if (!accountId) return null;
    const externalRef = String(dataObject['id'] ?? '');
    const tier = normaliseTier(String(metadata['tier'] ?? 'heritage'));
    const status: SubscriptionStatus =
      type === 'customer.subscription.deleted'
        ? 'canceled'
        : type === 'customer.subscription.trialing'
          ? 'trialing'
          : type === 'invoice.payment_failed'
            ? 'past_due'
            : 'active';
    const periodEndRaw = dataObject['current_period_end'];
    const currentPeriodEnd =
      typeof periodEndRaw === 'number' ? new Date(periodEndRaw * 1000) : null;
    return {
      provider: 'stripe',
      externalRef,
      accountId,
      tier,
      status,
      currentPeriodEnd,
      raw: { type, dataObject },
    };
  }
}

function normaliseTier(value: string): SubscriptionTier {
  switch (value.toLowerCase()) {
    case 'heritage':
      return 'heritage';
    case 'family':
      return 'family';
    default:
      return 'free';
  }
}
