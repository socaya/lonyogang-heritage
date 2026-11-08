import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { startHarness, type Harness } from './support/harness.js';

let harness: Harness;

beforeAll(async () => {
  harness = await startHarness();
}, 120_000);

afterAll(async () => {
  await harness.teardown();
});

/**
 * Providers (Stripe + Flutterwave) retry webhooks on 5xx. The server must
 * accept the retry at the HTTP layer and short-circuit before touching
 * subscription state a second time — otherwise a tier change could be
 * applied twice.
 */
describe('payment webhook idempotency', () => {
  it('records once, ignores a duplicate external_ref', async () => {
    // Seed an account so the event has an owner.
    const signup = await harness.app.inject({
      method: 'POST',
      url: '/identity/accounts',
      payload: {
        email: `paid-${Date.now()}@example.com`,
        password: 'long-enough-passphrase-9',
        displayName: 'Paid user',
      },
    });
    expect(signup.statusCode).toBe(201);
    const accountId = (signup.json() as { accountId: string }).accountId;

    const event = {
      provider: 'stripe' as const,
      externalRef: `evt_${Math.random().toString(16).slice(2, 10)}`,
      accountId,
      tier: 'heritage' as const,
      status: 'active' as const,
      currentPeriodEnd: new Date(Date.now() + 30 * 24 * 3600 * 1000),
      raw: { seeded: true },
    };
    const first = await harness.services.payments.record(event);
    const second = await harness.services.payments.record(event);
    expect(first).toBe(true);
    expect(second).toBe(false);

    const rows = await harness.pool.query(
      `select count(*)::int as c from payment_events where external_ref = $1`,
      [event.externalRef],
    );
    expect(rows.rows[0].c).toBe(1);
  });
});
