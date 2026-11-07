import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { startHarness, type Harness } from './support/harness.js';
import { InMemoryNotary, TransparencyService } from '../src/services/transparency.js';

let harness: Harness;

beforeAll(async () => {
  harness = await startHarness();
}, 120_000);

afterAll(async () => {
  await harness.teardown();
});

async function authed(email: string) {
  const signup = await harness.app.inject({
    method: 'POST',
    url: '/identity/accounts',
    payload: { email, password: 'correct-horse-battery-staple' },
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
  const signIn = await harness.app.inject({
    method: 'POST',
    url: '/identity/sessions',
    payload: {
      email,
      password: 'correct-horse-battery-staple',
      deviceId: '00000000-0000-0000-0000-000000000030',
    },
  });
  const { accessToken } = signIn.json<{ accessToken: string }>();
  return { accountId, accessToken };
}

describe('TransparencyService', () => {
  it('anchors the current audit tip and persists the proof', async () => {
    const { accountId, accessToken } = await authed('anchor@example.com');
    const notary = new InMemoryNotary();
    const service = new TransparencyService(harness.pool, harness.services.audit, notary);
    const anchor = await service.anchorAccount(accountId);
    expect(anchor).not.toBeNull();
    expect(anchor!.verified).toBe(true);
    expect(anchor!.entryCount).toBeGreaterThan(0);
    expect(anchor!.proof).not.toBeNull();
    expect(anchor!.proof!.toString('utf8')).toContain('proof:');

    const chain = await harness.services.audit.verifyChain(accountId);
    expect(anchor!.tipHash.equals(chain.tipHash!)).toBe(true);

    const list = await harness.app.inject({
      method: 'GET',
      url: '/audit/anchors',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    const body = list.json<{ anchors: Array<{ verified: boolean; source: string | null }> }>();
    expect(body.anchors.length).toBeGreaterThan(0);
    expect(body.anchors[0]!.verified).toBe(true);
  });

  it('exposes an authenticated anchor endpoint that rolls a fresh receipt', async () => {
    const { accessToken } = await authed('anchor-run@example.com');
    const run = await harness.app.inject({
      method: 'POST',
      url: '/audit/anchors/run',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(run.statusCode).toBe(200);
    const body = run.json<{ anchored: boolean; verified: boolean; tipHash: string }>();
    expect(body.anchored).toBe(true);
    expect(body.verified).toBe(true);
    expect(body.tipHash).toBeTruthy();
  });

  it('refuses to notarise a tampered chain but still records the broken state', async () => {
    const { accountId } = await authed('broken@example.com');
    await harness.pool.query(
      `update audit_entries set resource = 'tampered' where account_id = $1 and prev_hash is null`,
      [accountId],
    );
    const notary = new InMemoryNotary();
    const service = new TransparencyService(harness.pool, harness.services.audit, notary);
    const anchor = await service.anchorAccount(accountId);
    expect(anchor).not.toBeNull();
    expect(anchor!.verified).toBe(false);
    expect(anchor!.brokenAt).toBeTruthy();
    expect(anchor!.proof).toBeNull(); // Not notarised.
    expect(notary.anchors).toHaveLength(0);
  });
});
