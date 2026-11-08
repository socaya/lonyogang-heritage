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
 * The global rate limit (180/min) is deliberately generous because it has
 * to cover sync pulls, FX refreshes and background heartbeats. Sensitive
 * credential endpoints must throttle much earlier so a credential-stuffing
 * attacker hitting /identity/sessions is capped at the tighter per-route
 * window.
 */
describe('sign-in rate limit', () => {
  it('responds with 429 after the per-route limit is exceeded', async () => {
    // The route limit is 10/min — issue a burst of eleven and expect the
    // final one to be rejected with 429 before even reaching the handler.
    const email = 'ratelimit@example.com';
    // Use an un-provisioned email so we always get a 401; any status in
    // 2xx/4xx is fine — we are asserting the 429 shape, not auth success.
    let sawRateLimit = false;
    for (let i = 0; i < 15; i += 1) {
      const res = await harness.app.inject({
        method: 'POST',
        url: '/identity/sessions',
        payload: {
          email,
          password: 'anything-long-enough',
          deviceId: '00000000-0000-0000-0000-000000000070',
        },
        remoteAddress: '203.0.113.42',
      });
      if (res.statusCode === 429) {
        sawRateLimit = true;
        expect(res.headers['retry-after']).toBeDefined();
        break;
      }
    }
    expect(sawRateLimit, 'expected the route-scoped 429 cap to engage').toBe(true);
  });
});

describe('resource write rate limit', () => {
  it('caps PUT /resources/:kind/:id at 120/min per authenticated account', async () => {
    const email = `resrate-${Date.now()}@example.com`;
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
        deviceId: '00000000-0000-0000-0000-000000000086',
      },
    });
    const { accessToken } = signIn.json<{ accessToken: string }>();
    const h = { authorization: `Bearer ${accessToken}` };

    let sawRateLimit = false;
    for (let i = 0; i < 150; i += 1) {
      const res = await harness.app.inject({
        method: 'PUT',
        url: `/resources/asset/id-${i}`,
        headers: h,
        payload: {
          ciphertext: Buffer.from(`c-${i}`).toString('base64'),
          deviceId: '00000000-0000-0000-0000-000000000086',
        },
      });
      if (res.statusCode === 429) {
        sawRateLimit = true;
        expect(res.headers['retry-after']).toBeDefined();
        break;
      }
    }
    expect(sawRateLimit, 'expected /resources writes to return 429').toBe(true);
  });
});

describe('session-refresh rate limit', () => {
  it('caps /identity/sessions/refresh so a stolen refresh token cannot churn', async () => {
    let sawRateLimit = false;
    for (let i = 0; i < 50; i += 1) {
      const res = await harness.app.inject({
        method: 'POST',
        url: '/identity/sessions/refresh',
        payload: { refreshToken: 'x'.repeat(40) },
        remoteAddress: '203.0.113.60',
      });
      if (res.statusCode === 429) {
        sawRateLimit = true;
        expect(res.headers['retry-after']).toBeDefined();
        break;
      }
    }
    expect(sawRateLimit, 'expected refresh endpoint to return 429 under spam').toBe(true);
  });
});
