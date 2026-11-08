import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { startHarness, type Harness } from './support/harness.js';
import { RecoveryService } from '../src/services/recovery.js';
import { createHmac } from 'node:crypto';

let harness: Harness;

beforeAll(async () => {
  harness = await startHarness();
}, 120_000);

afterAll(async () => {
  await harness.teardown();
});

async function authedAccount(email: string) {
  const signup = await harness.app.inject({
    method: 'POST',
    url: '/identity/accounts',
    payload: { email, password: 'correct-horse-battery-staple', phone: '+256700123456' },
  });
  const { accountId } = signup.json<{ accountId: string }>();
  await harness.app.inject({
    method: 'POST',
    url: '/identity/accounts/verify',
    payload: {
      accountId,
      channel: 'email',
      code: harness.otp.latestCode(accountId, 'email'),
    },
  });
  await harness.app.inject({
    method: 'POST',
    url: '/identity/accounts/verify',
    payload: {
      accountId,
      channel: 'phone',
      code: harness.otp.latestCode(accountId, 'phone'),
    },
  });
  const signIn = await harness.app.inject({
    method: 'POST',
    url: '/identity/sessions',
    payload: {
      email,
      password: 'correct-horse-battery-staple',
      deviceId: '00000000-0000-0000-0000-000000000020',
    },
  });
  const { accessToken } = signIn.json<{ accessToken: string }>();
  return { accountId, accessToken };
}

describe('FX service', () => {
  it('serves mock rates for the supported currencies', async () => {
    const res = await harness.app.inject({ method: 'GET', url: '/fx/rates' });
    expect(res.statusCode).toBe(200);
    const { rates } = res.json<{ rates: { currency: string; ugxPerUnit: number }[] }>();
    const usd = rates.find((r) => r.currency === 'USD');
    expect(usd?.ugxPerUnit).toBe(3850);
  });

  it('returns empty when a request comes in for a currency we do not cover', async () => {
    const res = await harness.app.inject({ method: 'GET', url: '/fx/rates?currencies=ZZZ' });
    const { rates } = res.json<{ rates: unknown[] }>();
    expect(rates).toHaveLength(0);
  });
});

describe('Recovery service', () => {
  it('splits a wrap key and reconstructs it from two of three shares', async () => {
    const { accessToken } = await authedAccount('recovery@example.com');
    const enrol = await harness.app.inject({
      method: 'POST',
      url: '/recovery/enroll',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    const { wrapKey, deviceShare, printableShare } = enrol.json<{
      wrapKey: string;
      deviceShare: string;
      printableShare: string;
    }>();
    const redeem = await harness.app.inject({
      method: 'POST',
      url: '/recovery/redeem',
      payload: { printableShare },
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(redeem.statusCode).toBe(200);
    const { serverShare } = redeem.json<{ serverShare: string }>();
    const reconstructed = RecoveryService.combine([deviceShare, serverShare]);
    expect(reconstructed.equals(Buffer.from(wrapKey, 'base64'))).toBe(true);
  });

  it('rejects a mismatched printable share and audits the failure', async () => {
    const { accessToken } = await authedAccount('recovery-bad@example.com');
    await harness.app.inject({
      method: 'POST',
      url: '/recovery/enroll',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    const redeem = await harness.app.inject({
      method: 'POST',
      url: '/recovery/redeem',
      payload: { printableShare: Buffer.alloc(33).toString('base64') },
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(redeem.statusCode).toBe(400);
    const audit = await harness.app.inject({
      method: 'GET',
      url: '/audit/entries',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    const actions = audit
      .json<{ entries: { action: string }[] }>()
      .entries.map((e) => e.action);
    expect(actions).toContain('recovery.redeem_failed');
  });
});

describe('Audit chain verification', () => {
  it('reports verified = true for untampered logs', async () => {
    const { accessToken } = await authedAccount('audit@example.com');
    const res = await harness.app.inject({
      method: 'GET',
      url: '/audit/chain',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(res.statusCode).toBe(200);
    const { verified, count } = res.json<{ verified: boolean; count: number }>();
    expect(verified).toBe(true);
    expect(count).toBeGreaterThan(0);
  });
});

describe('Payment webhooks', () => {
  it('upgrades a subscription when a valid Stripe webhook arrives', async () => {
    const { accountId, accessToken } = await authedAccount('billing@example.com');
    const secret = 'whsec_integration_test';
    harness.services.payments['config'].STRIPE_WEBHOOK_SECRET = secret;
    const body = {
      type: 'customer.subscription.updated',
      data: {
        object: {
          id: 'sub_123',
          metadata: { account_id: accountId, tier: 'heritage' },
          current_period_end: Math.floor(Date.now() / 1000) + 2_592_000,
        },
      },
    };
    const raw = JSON.stringify(body);
    const timestamp = Math.floor(Date.now() / 1000);
    const signature = createHmac('sha256', secret).update(`${timestamp}.${raw}`).digest('hex');
    const header = `t=${timestamp},v1=${signature}`;
    const res = await harness.app.inject({
      method: 'POST',
      url: '/webhooks/stripe',
      payload: body,
      headers: { 'stripe-signature': header, 'content-type': 'application/json' },
    });
    expect(res.statusCode).toBe(204);
    const subscription = await harness.app.inject({
      method: 'GET',
      url: '/billing/subscription',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    const body2 = subscription.json<{ tier: string; status: string }>();
    expect(body2.tier).toBe('heritage');
    expect(body2.status).toBe('active');
  });

  it('rejects Stripe webhooks with a bad signature', async () => {
    harness.services.payments['config'].STRIPE_WEBHOOK_SECRET = 'whsec_other';
    const res = await harness.app.inject({
      method: 'POST',
      url: '/webhooks/stripe',
      payload: { type: 'ignored' },
      headers: { 'stripe-signature': 't=1,v1=deadbeef' },
    });
    expect(res.statusCode).toBe(401);
  });

  it('matches a Stripe signature computed over the raw body, not the parsed object', async () => {
    const { accountId, accessToken } = await authedAccount('billing-raw@example.com');
    const secret = 'whsec_raw_body';
    harness.services.payments['config'].STRIPE_WEBHOOK_SECRET = secret;
    // Deliberately-weird key order + extra whitespace → proves the server no
    // longer re-stringifies the body before hashing.
    const raw =
      `{  "type":"customer.subscription.updated",   "data": {"object":{"id":"sub_raw","metadata":{"account_id":"${accountId}","tier":"family"},"current_period_end":9999999999}}  }`;
    const timestamp = Math.floor(Date.now() / 1000);
    const signature = createHmac('sha256', secret).update(`${timestamp}.${raw}`).digest('hex');
    const res = await harness.app.inject({
      method: 'POST',
      url: '/webhooks/stripe',
      payload: raw,
      headers: {
        'stripe-signature': `t=${timestamp},v1=${signature}`,
        'content-type': 'application/json',
      },
    });
    expect(res.statusCode).toBe(204);
    const subscription = await harness.app.inject({
      method: 'GET',
      url: '/billing/subscription',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(subscription.json<{ tier: string }>().tier).toBe('family');
  });
});
